/** @file      embed.c
 *  @brief     Embed Forth Virtual Machine
 *  @copyright Richard James Howe (2017,2018)
 *  @license   MIT */
#include "embed.h"
#include <assert.h>
#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>

#define CORE (65536u)  /* core size in BYTES */
#define SP0  (8704u)   /* Variable Stack Start in WORDS: 8192 + 512 */
#define RP0  (32767u)  /* Return Stack Start: end of CORE in WORDS */

typedef uint16_t uw_t;
typedef int16_t  sw_t;
typedef uint32_t ud_t; 

typedef struct forth_t { uw_t pc, t, rp, sp, core[CORE]; /**< @note CORE instead of CORE/sizeof(uw_t) for memory safety */ } forth_t;

void embed_die(const char *fmt, ...)
{
	va_list arg;
	va_start(arg, fmt);
	vfprintf(stderr, fmt, arg);
	va_end(arg);
	fputc('\n', stderr);
	fflush(stderr);	
	exit(EXIT_FAILURE);	
}

FILE *embed_fopen_or_die(const char *file, const char *mode)
{
	FILE *f = NULL;
	errno = 0;
	assert(file && mode);
	if(!(f = fopen(file, mode)))
		embed_die("failed to open file '%s' (mode %s): %s", file, mode, strerror(errno));
	return f;
}

forth_t *embed_new(void)
{
	errno = 0;
	forth_t *f = calloc(1, sizeof(*f));
	if(!f)
		embed_die("allocation of size %u failed: %s", (unsigned)sizeof(*f), strerror(errno));
	return f;
}

forth_t *embed_copy(forth_t *f)
{
	assert(f);
	forth_t *r = embed_new();
	return memcpy(r, f, sizeof(*r));
}

void embed_free(forth_t *f)
{
	assert(f);
	memset(f, 0, sizeof(*f));
	free(f);
}

static int binary_memory_load(FILE *input, uw_t *p, const size_t length)
{
	assert(input && p && length <= 0x8000);

	for(size_t i = 0; i < length; i++) {
		const int r1 = fgetc(input);
		const int r2 = fgetc(input);
		if(r1 < 0 || r2 < 0)
			return -1;		
		p[i] = (((unsigned)r1 & 0xffu))|(((unsigned)r2 & 0xffu) << 8u);
	}
	return 0;
}

static int binary_memory_save(FILE *output, uw_t *p, const size_t length)
{
	assert(output && p);
	for(size_t i = 0; i < length; i++) {
		errno = 0;
		const int r1 = fputc((p[i])       & 0xff, output);
		const int r2 = fputc((p[i] >> 8u) & 0xff, output);
		if(r1 < 0 || r2 < 0) {
			fprintf(stderr, "write failed: %s\n", strerror(errno));
			return -1;
		}
	}
	return 0;
}

int embed_load(forth_t *h, const char *name)
{
	assert(h && name);
	FILE *input = embed_fopen_or_die(name, "rb");
	const int r = binary_memory_load(input, h->core, CORE/sizeof(uw_t));
	fclose(input);
	h->pc = 0; h->t = 0; h->rp = RP0; h->sp = SP0;
	return r;
}

static int save(forth_t *h, const char *name, size_t start, size_t length)
{
	assert(h && ((length - start) <= length));
	if(!name)
		return -1;
	FILE *output = embed_fopen_or_die(name, "wb");
	const int r = binary_memory_save(output, h->core+start, length-start);
	fclose(output);
	return r;
}

int embed_save(forth_t *h, const char *name)
{
	return save(h, name, 0, CORE/sizeof(uw_t));
}

int embed_eval(forth_t *h, const char *in, const size_t in_size, char *out, const size_t out_size) 
{
	size_t in_pos = 0;
	size_t out_pos = 0;

	if(!h || !in || !out)
		return -1;

	static const uw_t delta[] = { 0, 1, -2, -1 };

	uw_t pc = h->pc, t = h->t, rp = h->rp, sp = h->sp, *m = h->core;
	ud_t d;
	for(;;) {
		const uw_t instruction = m[pc];

		if(0x8000 & instruction) { /* literal */
			m[++sp] = t;
			t       = instruction & 0x7FFF;
			pc++;
		} else if ((0xE000 & instruction) == 0x6000) { /* ALU */
			uw_t n = m[sp], T = t;
			uw_t opc = pc;
			pc = instruction & 0x10 ? m[rp] >> 1 : pc + 1;

			switch((instruction >> 8u) & 0x1f) {
			case  0: /*T = t;*/                break;
			case  1: T = n;                    break;
			case  2: T = m[rp];                break;
			case  3: T = m[t>>1];              break;
			case  4: m[t>>1] = n; T = m[--sp]; break;
			case  5: d = (ud_t)t + (ud_t)n; T = d >> 16; m[sp] = d; n = d; break;
			case  6: d = (ud_t)t * (ud_t)n; T = d >> 16; m[sp] = d; n = d; break;
			case  7: T &= n;                   break;
			case  8: T |= n;                   break;
			case  9: T ^= n;                   break;
			case 10: T = ~t;                   break;
			case 11: T--;                      break;
			case 12: T = -(t == 0);            break;
			case 13: T = -(t == n);            break;
			case 14: T = -(n < t);             break;
			case 15: T = -((sw_t)n < (sw_t)t); break;
			case 16: T = n >> t;               break;
			case 17: T = n << t;               break;
			case 18: T = sp << 1;              break;
			case 19: T = rp << 1;              break;
			case 20: sp = t >> 1;              break;
			case 21: rp = t >> 1; T = n;       break;
			case 22: T = 0; /**@note not used in this version */ break;
			case 23:
				if(out_pos >= (out_size - 1)) {
					pc = opc;
					goto finished;
				}
				T = t;
				out[out_pos++] = t;
				break;
			case 24: 
				if(in_pos < in_size) {
					T = in[in_pos]; 
					in_pos++;
				} else {
					pc = opc;
					goto finished;
				}
				break;
			case 25: if(t) { T=n/t; t=n%t; n=t; } else { pc=1; T=10; } break;
			case 26: if(t) { T=(sw_t)n/(sw_t)t; t=(sw_t)n%(sw_t)t; n=t; } else { pc=1; T=10; } break;
			case 27: goto finished;
			}
			sp += delta[ instruction       & 0x3];
			rp -= delta[(instruction >> 2) & 0x3];
			if(instruction & 0x20)
				T = n;
			if(instruction & 0x40)
				m[rp] = t;
			if(instruction & 0x80)
				m[sp] = t;
			t = T;
		} else if (0x4000 & instruction) { /* call */
			m[--rp] = (pc + 1) << 1;
			pc      = instruction & 0x1FFF;
		} else if (0x2000 & instruction) { /* 0branch */
			pc = !t ? instruction & 0x1FFF : pc + 1;
			t  = m[sp--];
		} else { /* branch */
			pc = instruction & 0x1FFF;
		}
	}
finished: h->pc = pc; h->sp = sp; h->rp = rp; h->t = t;
	out[out_pos] = '\0';
	return (int16_t)t;
}

