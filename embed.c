/* Embed Forth Virtual Machine, Richard James Howe, 2017-2018, MIT License */
#include "embed.h"
#include <assert.h>
#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>

typedef struct forth_t { uint16_t m[32768]; } forth_t;

void embed_die(const char *fmt, ...)
{
	assert(fmt);
	va_list arg;
	va_start(arg, fmt);
	vfprintf(stderr, fmt, arg);
	va_end(arg);
	fputc('\n', stderr);
	exit(EXIT_FAILURE);
}

FILE *embed_fopen_or_die(const char *file, const char *mode)
{
	assert(file && mode);
	FILE *h = NULL;
	errno = 0;
	if(!(h = fopen(file, mode)))
		embed_die("file open %s (mode %s) failed: %s", file, mode, strerror(errno));
	return h;
}

forth_t *embed_new(void)
{
	forth_t *h = NULL;
	if(!(h = calloc(1, sizeof(*h))))
		embed_die("allocation (of %u) failed", (unsigned)sizeof(*h));
	return h;
}

static size_t embed_cells(forth_t const * const h) { assert(h); return h->m[5]; } /* count in cells, not bytes */

static int save(forth_t *h, const char *name, const size_t start, const size_t length)
{
	assert(h && ((length - start) <= length) && ((start + length) <= embed_cells(h)));
	if(!name)
		return -1;
	FILE *out = embed_fopen_or_die(name, "wb");
	int r = 0;
	for(size_t i = start; i < length; i++)
		if(fputc(h->m[i]&255, out) < 0 || fputc(h->m[i]>>8, out) < 0)
			r = -1;
	fclose(out);
	return r;
}

forth_t *embed_copy(forth_t const * const h)      { assert(h); return memcpy(embed_new(), h, sizeof(*h)); }
int      embed_save(forth_t *h, const char *name) { return save(h, name, 0, embed_cells(h)); }
size_t   embed_length(forth_t const * const h)    { return embed_cells(h) * sizeof(h->m[0]); }
void     embed_free(forth_t *h)                   { assert(h); memset(h, 0, sizeof(*h)); free(h); }
char    *embed_get_core(forth_t *h)               { assert(h); return (char*)h->m; }
static size_t max_size_t(size_t a, size_t b)      { return a > b ? a : b; }

int embed_load(forth_t *h, const char *name)
{
	assert(h && name);
	FILE *input = embed_fopen_or_die(name, "rb");
	long r = 0, c1 = 0, c2 = 0;
	for(size_t i = 0; i < max_size_t(64, embed_cells(h)); i++, r = i) {
		assert(embed_cells(h) <= 0x8000);
		if((c1 = fgetc(input)) < 0 || (c2 = fgetc(input)) < 0)
			break;
		h->m[i] = ((c1 & 0xffu)) | ((c2 & 0xffu) << 8u);
	}
	fclose(input);
	return r < 64 ? -1 : 0; /* minimum size checks, 128 bytes */
}

int embed_forth(forth_t *h, FILE *in, FILE *out, const char *block)
{
	assert(h && in && out);
	static const uint16_t delta[] = { 0, 1, -2, -1 };
	const uint16_t l = embed_cells(h);
	uint16_t * const m = h->m;
	uint16_t pc = m[0], t = m[1], rp = m[2], sp = m[3], r = 0;
	for(uint32_t d;;) {
		const uint16_t instruction = m[pc++];

		if(m[6] & 1) /* trace on */
			fprintf(m[6] & 2 ? out : stderr, "[ %4x %4x %4x %2x %2x ]\n", pc-1, instruction, t, m[2]-rp, sp-m[3]);
		if((r = -!(sp < l && rp < l && pc < l))) /* critical error */
			goto finished;

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
			case 24: T = fgetc(in); n = -1;    break; /* n = blocking status */
			case 25: if(t) { d = m[--sp]|((uint32_t)n<<16); T=d/t; t=d%t; n=t; } else { pc=4; T=10; } break;
			case 26: if(t) { T=(int16_t)n/t; t=(int16_t)n%t; n=t; } else { pc=4; T=10; } break;
			case 27: if(n) { m[sp] = 0; r = t; goto finished; } break;
			}
			sp += delta[ instruction       & 0x3];
			rp -= delta[(instruction >> 2) & 0x3];
			if(instruction & 0x80)
				m[sp] = t;
			if(instruction & 0x40)
				m[rp] = t;
			t = instruction & 0x20 ? n : T;
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
	return (int16_t)r;
}

#ifdef USE_EMBED_MAIN
int main(int argc, char **argv)
{
	forth_t *h = embed_new();
	if(argc > 4)
		embed_die("usage: %s [in.blk] [out.blk] [file.fth]", argv[0]);
	if(embed_load(h, argc < 2 ? "eforth.blk" : argv[1]) < 0)
		embed_die("embed: load failed");
	FILE *in = argc <= 3 ? stdin : embed_fopen_or_die(argv[3], "rb");
	if(embed_forth(h, in, stdout, argc < 3 ? NULL : argv[2]))
		embed_die("embed: run failed");
	return 0; /* exiting takes care of closing files, freeing memory */
}
#endif

