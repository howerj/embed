#include <assert.h>
#include <errno.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define FORTH_BLOCK ("forth.blk")
#define CORE  (65536u)
#define PRG   (8192u)
#define SP0   (8192u)
#define RP0   (8256u)

typedef struct {
	uint16_t core[CORE/sizeof(uint16_t)];
} forth_t;

#ifdef __unix__
#include <unistd.h>
#include <termios.h>
static int getch(void)
{
	struct termios oldattr, newattr;
	int ch;
	tcgetattr(STDIN_FILENO, &oldattr);
	newattr = oldattr;
	newattr.c_iflag &= ~(ICRNL);
	newattr.c_lflag &= ~(ICANON | ECHO);

	tcsetattr(STDIN_FILENO, TCSANOW, &newattr);
	ch = getchar();

	tcsetattr(STDIN_FILENO, TCSANOW, &oldattr);

	return ch;
}

static int putch(int c)
{
	int res = putchar(c);
	fflush(stdout);
	return res;
}
#else
#ifdef _WIN32

extern int getch(void);
extern int putch(int c);

#else
static int getch(void)
{
	return getchar();
}

static int putch(int c)
{
	return putchar(c);
}
#endif
#endif /** __unix__ **/

static int wrap_getch()
{
	int ch = getch();
	if(ch == EOF || ch == 27 /*escape*/)
		exit(EXIT_SUCCESS);
	return ch;
}

static FILE *fopen_or_die(const char *file, const char *mode)
{
	FILE *f = NULL;
	assert(file);
	assert(mode);
	errno = 0;
	f = fopen(file, mode);
	if(!f) {
		fprintf(stderr, "failed to open file '%s' (mode %s): %s\n", file, mode, strerror(errno));
		exit(EXIT_FAILURE);
	}
	return f;
}

static int binary_memory_load(FILE *input, uint16_t *p, size_t length)
{
	assert(input);
	assert(p);
	for(size_t i = 0; i < length; i++) {
		errno = 0;
		int r1 = fgetc(input);
		int r2 = fgetc(input);
		if(r1 < 0 || r2 < 0)
			return -1;
		p[i] = (((unsigned)r1 & 0xffu)) | (((unsigned)r2 & 0xffu) << 8u);
	}
	return 0;
}

static int binary_memory_save(FILE *output, uint16_t *p, size_t length)
{
	assert(output);
	assert(p);
	for(size_t i = 0; i < length; i++) {
		errno = 0;
		int r1 = fputc((p[i])     & 0xff,output);
		int r2 = fputc((p[i]>>8u) & 0xff, output);
		if(r1 < 0 || r2 < 0) {
			fprintf(stderr, "memory write failed: %s\n", strerror(errno));
			return -1;
		}
	}
	return 0;
}

static int load(forth_t *h, const char *name)
{
	assert(h);
	assert(name);
	FILE *input = fopen_or_die(name, "rb");
	int r = 0;
	errno = 0;
	r = binary_memory_load(input, h->core, CORE/2);
	fclose(input);
	return r;
}

static int save(forth_t *h, const char *name, size_t length)
{
	FILE *output = NULL;
	int r = 0;
	assert(h);
	assert(name);
	errno = 0;
	if((output = fopen(name, "wb"))) {
		r = binary_memory_save(output, h->core, length);
		fclose(output);
	} else {
		fprintf(stderr, "block write (to %s) failed: %s\n", name, strerror(errno));
		r = -1;
	}
	return r;
}

int forth(forth_t *h)
{
	static const uint16_t delta[4] = { 0x0000, 0x0001, 0xFFFE, 0xFFFF };
	register uint16_t pc = 0, tos = 0, rp = RP0, sp = SP0;
	uint16_t *core = h->core;
	for(;;) {
		uint16_t instruction = core[pc];
		uint16_t literal     = instruction & 0x7FFF;
		uint16_t address     = instruction & 0x1FFF;
		uint16_t pc_plus_one = pc + 1;

		//fprintf(stderr, "%04x\n", (unsigned)pc);
		if(0x8000 & instruction) { /* literal */
			core[++sp] = tos;
			tos        = literal;
			pc         = pc_plus_one;
		} else if ((0xE000 & instruction) == 0x6000) { /* ALU */
			uint16_t rd   = delta[(instruction >> 2) & 0x3];
			uint16_t dd   = delta[ instruction       & 0x3];
			uint16_t nos  = core[sp];
			uint16_t _tos = tos;
			uint16_t npc  = pc_plus_one;

			if(instruction & 0x10)
				npc = core[rp] >> 1;

			switch((instruction >> 8u) & 0x1f) {
			case  0: _tos = tos;                            break;
			case  1: _tos = nos;                            break;
			case  2: _tos += nos;                           break;
			case  3: _tos &= nos;                           break;
			case  4: _tos |= nos;                           break;
			case  5: _tos ^= nos;                           break;
			case  6: _tos = ~tos;                           break;
			case  7: _tos = -(tos == nos);                  break;
			case  8: _tos = -((int16_t)nos < (int16_t)tos); break;
			case  9: _tos = nos >> tos;                     break;
			case 10: _tos--;                                break;
			case 11: _tos = core[rp];                       break;
			case 12: _tos = core[(tos >> 1)];               break;
			case 13: _tos = nos << tos;                     break;
			case 14: _tos = sp - SP0;                       break;
			case 15: _tos = -(nos < tos);                   break;
			case 16: _tos = wrap_getch();                   break;
			case 17: putch(tos); _tos = nos;                break;
			case 18: save(h, FORTH_BLOCK, CORE/2);          break;
			case 19: return _tos; /* @todo move this, make it the last instruction */
			case 20: _tos = rp - RP0;                       break;
			case 21: _tos = -(tos == 0);                    break;
			}

			sp += dd;
			rp += rd;

			if(instruction & 0x40)
				core[rp] = tos;

			if(instruction & 0x80)
				core[sp] = tos;

			if(instruction & 0x20)
				core[(tos >> 1)] = nos;

			tos = _tos;
			pc  = npc;
		} else if (0x4000 & instruction) { /* call */
			core[++rp] = pc_plus_one << 1;
			pc = address;
		} else if (0x2000 & instruction) { /* 0branch */
			pc = !tos ? address : pc_plus_one;
			tos = core[sp--];
		} else { /* branch */
			pc = address;
		}
	}
	return 0;
}

int main(void)
{
	static forth_t h;
	memset(h.core, 0, CORE);
	load(&h, FORTH_BLOCK);
	return forth(&h);
}

