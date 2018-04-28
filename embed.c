/* Embed Forth Virtual Machine, Richard James Howe, 2017-2018, MIT License */
#include "embed.h"
#include <assert.h>
#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>

#define MAX(X, Y) ((X) < (Y) ? (Y) : (X))
typedef struct forth_t { uint16_t m[32768]; } forth_t;

void embed_die(const char *fmt, ...)
{
	va_list arg;
	va_start(arg, fmt);
	vfprintf(stderr, fmt, arg);
	va_end(arg);
	fputc('\n', stderr);
	exit(EXIT_FAILURE);
}

FILE *embed_fopen_or_die(const char *file, const char *mode)
{
	FILE *h = NULL;
	errno = 0;
	assert(file && mode);
	if(!(h = fopen(file, mode)))
		embed_die("file open %s (mode %s) failed: %s", file, mode, strerror(errno));
	return h;
}

forth_t *embed_new(void)
{
	forth_t *h = calloc(1, sizeof(*h));
	if(!h)
		embed_die("allocation (of %u) failed", (unsigned)sizeof(*h));
	return h;
}

void embed_free(forth_t *h)
{
	free(h);
}

forth_t *embed_copy(forth_t const * const h)
{
	assert(h);
	forth_t *r = embed_new();
	return memcpy(r, h, sizeof(*r));
}

int embed_load(forth_t *h, const char *name)
{
	assert(h && name);
	FILE *input = embed_fopen_or_die(name, "rb");
	long r = 0, c1 = 0, c2 = 0;
	for(size_t i = 0; i < MAX(64, h->m[5]); i++) {
		if((c1 = fgetc(input)) < 0 || (c2 = fgetc(input)) < 0) {
			r = i;
			break;;
		}
		h->m[i] = ((c1 & 0xffu))|((c2 & 0xffu) << 8u);
	}
	fclose(input);
	return r < 64 ? -1 : 0; /* minimum size checks, 128 bytes */
}

static int save(forth_t *h, const char *name, const size_t start, const size_t length)
{
	assert(h && ((length - start) <= length));
	if(!name)
		return -1;
	FILE *out = embed_fopen_or_die(name, "wb");
	int r = 0;
	for(size_t i = start; i < length; i++)
		if(fputc(h->m[i] & 255, out) < 0 || fputc(h->m[i] >> 8, out) < 0)
			r = -1;
	fclose(out);
	return r;
}

int embed_save(forth_t *h, const char *name)
{
	return save(h, name, 0, h->m[5]);
}

int embed_forth(forth_t *h, FILE *in, FILE *out, const char *block)
{
	assert(h && in && out);
	static const uint16_t delta[] = { 0, 1, -2, -1 };
	const uint16_t l = h->m[5]; 
	uint16_t * const m = h->m;
	uint16_t pc = m[0], t = m[1], rp = m[2], sp = m[3];
	for(uint32_t d;;) {
		const uint16_t instruction = m[pc++];
		assert(sp < l && rp < l && pc < l);

		if(0x8000 & instruction) { /* literal */
			m[++sp] = t;
			t       = instruction & 0x7FFF;
		} else if ((0xE000 & instruction) == 0x6000) { /* ALU */
			uint16_t n = m[sp], T = t;
			pc = instruction & 0x10 ? m[rp] >> 1 : pc;

			switch((instruction >> 8u) & 0x1f) {
			case  1: T = n;                    break;
			case  2: T = m[rp];                break;
			case  3: T = m[(t>>1)%l];          break;
			case  4: m[(t>>1)%l] = n; T = m[--sp]; break;
			case  5: d = (uint32_t)t + n; T = d >> 16; m[sp] = d; n = d; break;
			case  6: d = (uint32_t)t * n; T = d >> 16; m[sp] = d; n = d; break;
			case  7: T &= n;                   break;
			case  8: T |= n;                   break;
			case  9: T ^= n;                   break;
			case 10: T = ~t;                   break;
			case 11: T--;                      break;
			case 12: T = -(t == 0);            break;
			case 13: T = -(t == n);            break;
			case 14: T = -(n < t);             break;
			case 15: T = -((int16_t)n < (int16_t)t); break;
			case 16: T = n >> t;               break;
			case 17: T = n << t;               break;
			case 18: T = sp << 1;              break;
			case 19: T = rp << 1;              break;
			case 20: sp = t >> 1;              break;
			case 21: rp = t >> 1; T = n;       break;
			case 22: T = save(h, block, n>>1, ((uint32_t)T+1)>>1); break;
			case 23: T = fputc(t, out);        break;
			case 24: T = fgetc(in);            break;
			case 25: if(t) { T=n/t; t=n%t; n=t; } else { pc=4; T=10; } break;
			case 26: if(t) { T=(int16_t)n/t; t=(int16_t)n%t; n=t; } else { pc=4; T=10; } break;
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
			m[--rp] = pc << 1;
			pc      = instruction & 0x1FFF;
		} else if (0x2000 & instruction) { /* 0branch */
			pc = !t ? instruction & 0x1FFF : pc;
			t  = m[sp--];
		} else { /* branch */
			pc = instruction & 0x1FFF;
		}
	}
finished: m[0] = pc, m[1] = t, m[2] = rp, m[3] = sp;
	return (int16_t)t;
}

#ifdef USE_EMBED_MAIN
int main(int argc, char **argv)
{
	forth_t *h = embed_new();
	if(argc != 3 && argc != 4)
		embed_die("usage: %s in.blk out.blk [file.fth]", argv[0]);
	if(embed_load(h, argv[1]) < 0)
		embed_die("embed: load failed");;
	FILE *in = argc == 3 ? stdin : embed_fopen_or_die(argv[3], "rb");
	if(embed_forth(h, in, stdout, argv[2]))
		embed_die("embed: run failed");
	return 0; /* exiting takes care of closing files, freeing memory */
}
#endif

