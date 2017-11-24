#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct { uint16_t pc, t, rp, sp, core[65536/sizeof(uint16_t)]; } forth_t;

FILE *file(char *file, char *mode)
{
	FILE *f = NULL;
	if(!(f = fopen(file, mode)))
		exit(EXIT_FAILURE);
	return f;
}

int load(forth_t *h, char *name)
{
	FILE *input = file(name, "rb");
	int r = fread(h->core,sizeof(uint16_t), 65536/sizeof(uint16_t),input); 
	fclose(input);
	h->pc = 0; h->t = 0; h->rp = 32767u; h->sp = 8704u;
	return r > 0 ? 0 : -1;
}

int save(forth_t *h, char *name, size_t start, size_t length)
{
	if(!name)
		return -1;
	FILE *output = file(name, "wb");
	int r = fwrite(h->core + start, sizeof(uint16_t), length, output);
	fclose(output);
	return r == (int)length ? 0 : -1;
}

int forth(forth_t *h, FILE *in, FILE *out, char *block)
{
	uint16_t delta[] = { 0, 1, 0xFFFE, 0xFFFF };
	uint16_t pc = h->pc, t = h->t, rp = h->rp, sp = h->sp, *m = h->core;
	uint32_t d;
	for(;;) {
		uint16_t i = m[pc];
		if(0x8000 & i) {
			m[++sp] = t;
			t       = i & 0x7FFF;
			pc++;
		} else if ((0xE000 & i) == 0x6000) {
			uint16_t n = m[sp], T = t;
			pc = i & 0x10 ? m[rp] >> 1 : pc + 1;
			switch((i >> 8u) & 0x1f) {
			case  1: T = n; break;
			case  2: T = m[rp]; break;
			case  3: T = m[t >> 1]; break;
			case  4: m[t >> 1] = n; T = m[--sp]; break;
			case  5: d = (uint32_t)t + (uint32_t)n; T = d >> 16; m[sp] = d; n = d; break;
			case  6: d = (uint32_t)t * (uint32_t)n; T = d >> 16; m[sp] = d; n = d; break;
			case  7: T &= n; break;
			case  8: T |= n; break;
			case  9: T ^= n; break;
			case 10: T = ~t; break;
			case 11: T--; break;
			case 12: T = -(t == 0); break;
			case 13: T = -(t == n); break;
			case 14: T = -(n < t); break;
			case 15: T = -((int16_t)n < (int16_t)t); break;
			case 16: T = n >> t; break;
			case 17: T = n << t; break;
			case 18: T = sp << 1; break;
			case 19: T = rp << 1; break;
			case 20: sp = t >> 1; break;
			case 21: rp = t >> 1; T = n; break;
			case 22: T = save(h, block, n >> 1, ((uint32_t)T + 1u) >> 1); break;
			case 23: T = fputc(t, out); break;
			case 24: T = fgetc(in); break;
			case 25: if(t) { T=n/t; t=n%t; n=t; } else { pc=1; T=10; n=T; t=n; } break;
			case 26: if(t) { T=(int16_t)n/(int16_t)t; t=(int16_t)n%(int16_t)t; n=t; } else { pc=1; T=10; n=T; t=n; } break;
			case 27: goto finished;
			}
			sp += delta[ i       & 0x3];
			rp -= delta[(i >> 2) & 0x3];
			if(i & 0x20)
				T = n;
			if(i & 0x40)
				m[rp] = t;
			if(i & 0x80)
				m[sp] = t;
			t = T;
		} else if (0x4000 & i) {
			m[--rp] = (pc + 1) << 1;
			pc = i & 0x1FFF;
		} else if (0x2000 & i) {
			pc = !t ? i & 0x1FFF : pc + 1;
			t = m[sp--];
		} else {
			pc = i & 0x1FFF;
		}
	}
finished:
	h->pc = pc; h->sp = sp; h->rp = rp; h->t = t;
	return (int16_t)t;
}

int main(int argc, char **argv)
{
	static forth_t h;
	if(argc < 2)
		return -1;
	load(&h, argv[1]);
	return forth(&h, stdin, stdout, argv[1]);
}

