#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define FORTH_BLOCK ("forth.blk")
#define CORE        (65536u)
#define PRG         (8192u)
#define SP0         (8192u)
#define RP0         (8256u)

typedef struct { uint16_t core[CORE/sizeof(uint16_t)]; } forth_t;

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

static int binary_memory_load(FILE *input, uint16_t *p, size_t length)
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

static int binary_memory_save(FILE *output, uint16_t *p, size_t length)
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
	FILE *input = fopen_or_die(name, "rb");
	const int r = binary_memory_load(input, h->core, CORE/sizeof(uint16_t));
	fclose(input);
	return r;
}

static int save(forth_t *h, const char *name, size_t length)
{
	FILE *output = fopen_or_die(name, "wb");
	const int r = binary_memory_save(output, h->core, length);
	fclose(output);
	return r;
}

static int forth(forth_t *h, FILE *in, FILE *out, const char *block)
{
	static const uint16_t delta[] = { 0x0000, 0x0001, 0xFFFE, 0xFFFF };
	register uint16_t pc = 0, tos = 0, rp = RP0, sp = SP0;
	uint16_t *core = h->core;
	for(;;) {
		uint16_t instruction = core[pc];

		if(0x8000 & instruction) { /* literal */
			core[++sp] = tos;
			tos        = instruction & 0x7FFF;
			pc++;
		} else if ((0xE000 & instruction) == 0x6000) { /* ALU */
			uint16_t nos  = core[sp];
			uint16_t _tos = tos;
			uint16_t npc  = pc + 1;
			int      c    = 0;

			if(instruction & 0x10)
				npc = core[rp] >> 1;

			switch((instruction >> 8u) & 0x1f) {
			case  0: _tos = tos;                                    break;
			case  1: _tos = nos;                                    break;
			case  2: _tos = core[rp];                               break;
			case  3: _tos = core[(tos >> 1)];                       break;
			case  4: _tos += nos;                                   break;
			case  5: _tos &= nos;                                   break;
			case  6: _tos |= nos;                                   break;
			case  7: _tos ^= nos;                                   break;
			case  8: _tos = ~tos;                                   break;
			case  9: _tos--;                                        break;
			case 10: _tos = -(tos == 0);                            break;
			case 11: _tos = -(tos == nos);                          break;
			case 12: _tos = -(nos < tos);                           break;
			case 13: _tos = -((int16_t)nos < (int16_t)tos);         break;
			case 14: _tos = nos >> tos;                             break;
			case 15: _tos = nos << tos;                             break;
			case 16: _tos = sp - SP0;                               break;
			case 17: _tos = rp - RP0;                               break;
			case 18: save(h, block, CORE/sizeof(uint16_t));         break;
			case 19: fputc(tos, out); _tos = nos;                   break;
			case 20: if((c = fgetc(in)) == EOF) return 0; _tos = c; break;
			case 21: return _tos; 
			}

			sp += delta[ instruction       & 0x3];
			rp += delta[(instruction >> 2) & 0x3];

			if(instruction & 0x20)
				core[(tos >> 1)] = nos;

			if(instruction & 0x40)
				core[rp] = tos;

			if(instruction & 0x80)
				core[sp] = tos;

			tos = _tos;
			pc  = npc;
		} else if (0x4000 & instruction) { /* call */
			core[++rp] = (pc + 1 ) << 1;
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

int main(void)
{
	static forth_t h;
	memset(h.core, 0, CORE);
	load(&h, FORTH_BLOCK);
	return forth(&h, stdin, stdout, FORTH_BLOCK);
}

