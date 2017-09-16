/** @file      forth.c
 *  @brief     Forth Virtual Machine
 *  @copyright Richard James Howe (2017)
 *  @license   MIT */

#include <assert.h>
#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define CORE        (65536u)
#define SP0         (8192u)
#define RP0         (32767u)

typedef uint16_t uw_t;
typedef int16_t  sw_t;
typedef uint32_t ud_t;

typedef struct { uw_t core[CORE/sizeof(uw_t)]; } forth_t;

static FILE *fopen_or_die(const char *file, const char *mode)
{
	FILE *f = NULL;
	errno = 0;
	if(!(f = fopen(file, mode))) {
		fprintf(stderr, "failed to open file '%s' (mode %s): %s\n", file, mode, strerror(errno));
		exit(EXIT_FAILURE);
	}
	return f;
}

static int binary_memory_load(FILE *input, uw_t *p, size_t length)
{
	for(size_t i = 0; i < length; i++) {
		errno = 0;
		const int r1 = fgetc(input);
		const int r2 = fgetc(input);
		if(r1 < 0 || r2 < 0)
			return -1;
		p[i] = (((unsigned)r1 & 0xffu)) | (((unsigned)r2 & 0xffu) << 8u);
	}
	return 0;
}

static int binary_memory_save(FILE *output, uw_t *p, size_t length)
{
	for(size_t i = 0; i < length; i++) {
		errno = 0;
		const int r1 = fputc((p[i])       & 0xff, output);
		const int r2 = fputc((p[i] >> 8u) & 0xff, output);
		if(r1 < 0 || r2 < 0) {
			fprintf(stderr, "memory write failed: %s\n", strerror(errno));
			return -1;
		}
	}
	return 0;
}

static int load(forth_t *h, const char *name)
{
	assert(h && name);
	FILE *input = fopen_or_die(name, "rb");
	const int r = binary_memory_load(input, h->core, CORE/sizeof(uw_t));
	fclose(input);
	return r;
}

static int save(forth_t *h, const char *name, size_t length)
{
	assert(h);
	if(!name)
		return -1;
	FILE *output = fopen_or_die(name, "wb");
	const int r = binary_memory_save(output, h->core, length);
	fclose(output);
	return r;
}

static int forth(forth_t *h, FILE *in, FILE *out, const char *block)
{
	static const uw_t delta[] = { 0x0000, 0x0001, 0xFFFE, 0xFFFF };
	register uw_t pc = 0, tos = 0, rp = RP0, sp = SP0;
	assert(h && in && out);
	uw_t *core = h->core;
	for(;;) {
		uw_t instruction = core[pc];

		assert(!(sp & 0x8000) && !(rp & 0x8000));

		if(0x8000 & instruction) { /* literal */
			core[++sp] = tos;
			tos        = instruction & 0x7FFF;
			pc++;
		} else if ((0xE000 & instruction) == 0x6000) { /* ALU */
			int  c;
			ud_t d;
			uw_t nos  = core[sp];
			uw_t _tos = tos;

			pc = instruction & 0x10 ? core[rp] >> 1 : pc + 1;

			switch((instruction >> 8u) & 0x1f) {
			case  0: /*_tos = tos;*/                                break;
			case  1: _tos = nos;                                    break;
			case  2: _tos = core[rp];                               break;
			case  3: _tos = core[tos >> 1];                         break;
			case  4: core[tos >> 1] = nos; _tos = core[sp-- - 1];   break;
			case  5: d = (ud_t)tos + (ud_t)nos; _tos = d >> 16; core[sp] = d; nos = d; break;
			case  6: d = (ud_t)tos * (ud_t)nos; _tos = d >> 16; core[sp] = d; nos = d; break;
			case  7: _tos &= nos;                                   break;
			case  8: _tos |= nos;                                   break;
			case  9: _tos ^= nos;                                   break;
			case 10: _tos = ~tos;                                   break;
			case 11: _tos--;                                        break;
			case 12: _tos = -(tos == 0);                            break;
			case 13: _tos = -(tos == nos);                          break;
			case 14: _tos = -(nos < tos);                           break;
			case 15: _tos = -((sw_t)nos < (sw_t)tos);               break;
			case 16: _tos = nos >> tos;                             break;
			case 17: _tos = nos << tos;                             break;
			case 18: _tos = sp << 1;                                break;
			case 19: _tos = rp << 1;                                break;
			case 20: sp   = tos >> 1;                               break;
			case 21: rp   = tos >> 1; _tos = nos;                   break;
			case 22: _tos = save(h, block, ((ud_t)_tos + 1u) >> 1); break;
			case 23: _tos = fputc(tos, out);                        break;
			case 24: if((c = fgetc(in)) == EOF) return 0; _tos = c; break;
			case 25: return _tos;
			}

			sp += delta[ instruction       & 0x3];
			rp -= delta[(instruction >> 2) & 0x3];

			if(instruction & 0x20)
				_tos = nos;
			if(instruction & 0x40)
				core[rp] = tos;
			if(instruction & 0x80)
				core[sp] = tos;

			tos = _tos;
		} else if (0x4000 & instruction) { /* call */
			core[--rp] = (pc + 1 ) << 1;
			pc = instruction & 0x1FFF;
		} else if (0x2000 & instruction) { /* 0branch */
			pc = !tos ? instruction & 0x1FFF : pc + 1;
			tos = core[sp--];
		} else { /* branch */
			pc = instruction & 0x1FFF;
		}
	}
	return 0;
}

int main(int argc, char **argv)
{
	static forth_t h;
	memset(h.core, 0, CORE);
	if(argc < 2) {
		fprintf(stderr, "usage: %s forth.blk file.fth*\n", argv[0]);
		return -1;
	}
	load(&h, argv[1]);
	if(argc == 2)
		return forth(&h, stdin, stdout, argv[1]);
	for(int i = 2; i < argc; i++) {
		FILE *in = fopen_or_die(argv[i], "rb");
		int r = forth(&h, in, stdout, argv[1]);
		fclose(in);
		if(r != 0) {
			fprintf(stderr, "run failed: %d\n", r);
			return r;
		}
	}
	return 0;
}

