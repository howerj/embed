/* Embed Forth Virtual Machine, Richard James Howe, 2017-2018, MIT License */
#include "embed.h"
#include <assert.h>
#include <errno.h>
#include <stdint.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>

typedef uint16_t m_t; /**< The VM is a 16-bit one, 'uintptr_t' would be more useful */
typedef  int16_t s_t; /**< used for signed calculation and casting */
typedef uint32_t d_t; /**< should be double the size of 'm_t' and unsigned */

struct embed_t { m_t m[32768]; }; /**< Embed Forth VM structure */

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

void *embed_alloc_or_die(size_t sz)
{
	errno = 0;
	void *r = calloc(sz, 1);
	if(!r)
		embed_die("allocation of size %u bytes failed: %s", (unsigned)sz, strerror(errno));
	return r;
}

int embed_fputc_cb(int ch, void *file)             { assert(file); return fputc(ch, file); }
int embed_fgetc_cb(void *file)                     { assert(file); return fgetc(file); }
static size_t embed_cells(embed_t const * const h) { assert(h); return h->m[5]; } /* count in cells, not bytes */
static size_t embed_min_size_t(size_t a, size_t b) { return a > b ? b : a; }
uint16_t embed_swap16(uint16_t s)                  { return (s >> 8) | (s << 8); }
void embed_buffer_swap16(uint16_t *b, size_t l)    { assert(b); for(size_t i = 0; i < l; i++) b[i] = embed_swap16(b[i]); }
static inline int is_big_endian(void)              { return (*(uint16_t *)"\0\xff" < 0x100); }
static void embed_normalize(embed_t *h)            { assert(h); if(is_big_endian()) embed_buffer_swap16(h->m, sizeof(h->m)/2); }

int embed_load_buffer(embed_t *h, const uint8_t *buf, size_t length)
{
	assert(h && buf);
	memcpy(h->m, buf, embed_min_size_t(sizeof(h->m), length));
	embed_normalize(h);
	return length < 128 ? -70 /* read-file IOR */ : 0; /* minimum size checks, 128 bytes */
}

int embed_load_file(embed_t *h, FILE *input)
{
	assert(h && input);
	size_t r = fread(h->m, 1, sizeof(h->m), input);
	embed_normalize(h);
	return r < 128 ? -70 /* read-file IOR */ : 0; /* minimum size checks, 128 bytes */
}

int embed_save_cb(const m_t m[static 32768], const void *name, const size_t start, const size_t length)
{
	assert(m);
	if(!name || !(((length - start) <= length) && ((start + length) <= m[5] /*embed_cells(h)*/)))
		return -69; /* open-file IOR */
	FILE *out = fopen(name, "wb");
	if(!out)
		return -69; /* open-file IOR */
	int r = 0;
	for(size_t i = start; i < length; i++)
		if(fputc(m[i]&255, out) < 0 || fputc(m[i]>>8, out) < 0)
			r = -76; /* write-file IOR */
	return fclose(out) < 0 ? -62 /* close-file IOR */ : r;
}

embed_t *embed_new(void)                          { return embed_alloc_or_die(sizeof(struct embed_t)); }
embed_t *embed_copy(embed_t const * const h)      { assert(h); return memcpy(embed_new(), h, sizeof(*h)); }
int      embed_save(const embed_t *h, const char *name) { assert(name); return embed_save_cb(h->m, name, 0, embed_cells(h)); }
size_t   embed_length(embed_t const * const h)    { return embed_cells(h) * sizeof(h->m[0]); }
void     embed_free(embed_t *h)                   { assert(h); memset(h, 0, sizeof(*h)); free(h); }
char    *embed_core(embed_t *h)                   { assert(h); return (char*)h->m; }
int      embed_load(embed_t *h, const char *name) { FILE *f = embed_fopen_or_die(name, "rb"); int r = embed_load_file(h, f); fclose(f); return r; }

#ifdef NDEBUG
#define trace(OPT,M,PC,INSTRUCTION,T,RP,SP)
#else
static void efputs(embed_opt_t *o, const char *s)
{
	assert(o && s);
	if(!(o->put))
		return;
	for(int ch = 0;(ch = *s++); o->put(ch, o->out));
}

static inline void trace(embed_opt_t *o, m_t *m, m_t pc, m_t instruction, m_t t, m_t rp, m_t sp)
{
	if(!(o->options & 1) || !(o->put))
		return;
	char buf[32] = { 0 };
	snprintf(buf, sizeof buf, "[ %4x %4x %4x %2x %2x ]\n", pc-1, instruction, t, (uint16_t)(m[2]-rp), (uint16_t)(sp-m[3]));
	efputs(o, buf);
}
#endif

int embed_vm(embed_t *h, embed_opt_t *o)
{
	assert(h && o);
	static const m_t delta[] = { 0, 1, -2, -1 };
	const m_t l = embed_cells(h);
	m_t * const m = h->m;
	m_t pc = m[0], t = m[1], rp = m[2], sp = m[3], r = 0;
	for(d_t d;;) {
		const m_t instruction = m[pc++];
		trace(o, m, pc, instruction, t, rp, sp);
		if((r = -!(sp < l && rp < l && pc < l))) /* critical error */
			goto finished;
		if(0x8000 & instruction) { /* literal */
			m[++sp] = t;
			t       = instruction & 0x7FFF;
		} else if ((0xE000 & instruction) == 0x6000) { /* ALU */
			m_t n = m[sp], T = t;
			pc = instruction & 0x10 ? m[rp] >> 1 : pc;

			switch((instruction >> 8u) & 0x1f) {
			case  0: T = t;                    break;
			case  1: T = n;                    break;
			case  2: T = m[rp];                break;
			case  3: T = m[(t>>1)%l];          break;
			case  4: m[(t>>1)%l] = n; T = m[--sp]; break;
			case  5: d = (d_t)t + n; T = d >> 16; m[sp] = d; n = d; break;
			case  6: d = (d_t)t * n; T = d >> 16; m[sp] = d; n = d; break;
			case  7: T = t&n;                  break;
			case  8: T = t|n;                  break;
			case  9: T = t^n;                  break;
			case 10: T = ~t;                   break;
			case 11: T = t-1;                  break;
			case 12: T = -(t == 0);            break;
			case 13: T = -(t == n);            break;
			case 14: T = -(n < t);             break;
			case 15: T = -((s_t)n < (s_t)t);   break;
			case 16: T = n >> t;               break;
			case 17: T = n << t;               break;
			case 18: T = sp << 1;              break;
			case 19: T = rp << 1;              break;
			case 20: sp = t >> 1;              break;
			case 21: rp = t >> 1; T = n;       break;
			case 22: if(o->save) { T = o->save(h->m, o->name, n>>1, ((d_t)t+1)>>1); } else { pc=4; T=21; } break;
			case 23: if(o->put)  { T = o->put(t, o->out); }                 else { pc=4; T=21; } break; 
			case 24: if(o->get)  { T = o->get(o->in); }                     else { pc=4; T=21; } break;
			case 25: if(t) { d = m[--sp]|((d_t)n<<16); T=d/t; t=d%t; n=t; } else { pc=4; T=10; } break;
			case 26: if(t) { T=(s_t)n/t; t=(s_t)n%t; n=t; }                 else { pc=4; T=10; } break;
			case 27: if(n) { m[sp] = 0; r = t; goto finished; } break;
			case 28: if(o->callback) { sp = o->callback(o->param, &m[sp], sp >> 1); } else { pc=4; T=21; } break;
			case 29: T = o->options; o->options = t; break;
			default: pc = 4; T=21;             break;
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
	return (s_t)r;
}

int embed_forth(embed_t *h, FILE *in, FILE *out, const char *block)
{
	embed_opt_t o = {
		.get      = embed_fgetc_cb, .put   = embed_fputc_cb, .save = embed_save_cb,
		.in       = in,             .out   = out,            .name = block, 
		.callback = NULL,           .param = NULL,
	};
	return embed_vm(h, &o);
}

