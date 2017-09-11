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
	uint16_t core[CORE/2];
	uint16_t pc;
	uint16_t tos;
	uint16_t rp;
	uint16_t sp;
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

static inline void dpush(forth_t *h, const uint16_t v)
{
	h->sp++;
	h->core[h->sp] = h->tos;
	h->tos = v;
}

static inline uint16_t dpop(forth_t *h)
{
	uint16_t r = h->tos;
	h->tos = h->core[h->sp--];
	return r;
}

static inline void rpush(forth_t *h, const uint16_t r)
{
	h->rp++;
	h->core[h->rp] = r;
}

int forth(forth_t *h)
{
	static const uint16_t delta[4] = { 0x0000, 0x0001, 0xFFFE, 0xFFFF };

	for(;;) {
		uint16_t instruction = h->core[h->pc];
		uint16_t literal     = instruction & 0x7FFF;
		uint16_t address     = instruction & 0x1FFF;
		uint16_t pc_plus_one = h->pc + 1;

		if(0x8000 & instruction) { /* literal */
			dpush(h, literal);
			h->pc = pc_plus_one;
		} else if ((0xE000 & instruction) == 0x6000) { /* ALU */
			uint16_t rd  = delta[(instruction >> 2) & 0x3];
			uint16_t dd  = delta[ instruction       & 0x3];
			uint16_t nos = h->core[h->sp];
			uint16_t tos = h->tos;
			uint16_t npc = pc_plus_one;

			if(instruction & 0x10)
				npc = h->core[h->rp] >> 1;

			switch((instruction >> 8u) & 0x1f) {
			case  0: /* tos = tos; */                      break;
			case  1: tos = nos;                            break;
			case  2: tos += nos;                           break;
			case  3: tos &= nos;                           break;
			case  4: tos |= nos;                           break;
			case  5: tos ^= nos;                           break;
			case  6: tos = ~tos;                           break;
			case  7: tos = -(tos == nos);                  break;
			case  8: tos = -((int16_t)nos < (int16_t)tos); break;
			case  9: tos = nos >> tos;                     break;
			case 10: tos--;                                break;
			case 11: tos = h->core[h->rp];                 break;
			case 12: tos = h->core[(h->tos >> 1)];         break;
			case 13: tos = nos << tos;                     break;
			case 14: tos = h->sp - SP0;                    break;
			case 15: tos = -(nos < tos);                   break;
			case 16: tos = wrap_getch();                   break;
			case 17: putch(tos); tos = nos;                break;
			case 18: save(h, FORTH_BLOCK, CORE/2);         break;
			case 19: return tos;
			case 20: tos = h->rp - RP0;                    break;
			case 21: tos = -(tos == 0);                    break;
			}

			h->sp += dd;
			h->rp += rd;

			if(instruction & 0x40)
				h->core[h->rp] = h->tos;

			if(instruction & 0x80)
				h->core[h->sp] = h->tos;

			if(instruction & 0x20)
				h->core[(h->tos >> 1)] = nos;

			h->tos = tos;
			h->pc  = npc;
		} else if (0x4000 & instruction) { /* call */
			rpush(h, pc_plus_one << 1);
			h->pc = address;
		} else if (0x2000 & instruction) { /* 0branch */
			h->pc = !dpop(h) ? address : pc_plus_one;
		} else { /* branch */
			h->pc = address;
		}
	}
	return 0;
}

int main(void)
{
	static forth_t h;
	h.pc = 0;
	h.rp = RP0;
	h.sp = SP0;
	memset(h.core, 0, CORE);
	load(&h, FORTH_BLOCK);
	return forth(&h);
}

