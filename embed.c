/* Embed Forth Virtual Machine, Richard James Howe, 2017-2018, MIT License */
#include "embed.h"
#include <assert.h>
#include <stdint.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define SHADOW    (7)     /**< start location of shadow registers */
#define CORE_SIZE (32768) /**< core size in cells */
#define MIN(X, Y) ((X) > (Y) ? (Y) : (X))

typedef cell_t        m_t; /**< The VM is 16-bit, 'uintptr_t' would be more useful */
typedef signed_cell_t s_t; /**< used for signed calculation and casting */
typedef double_cell_t d_t; /**< should be double the size of 'm_t' and unsigned */
struct embed_t { embed_opt_t o; m_t m[CORE_SIZE]; }; /**< Embed Forth VM structure */

m_t  embed_mmu_read_cb(m_t const * const m, m_t addr)       { return m[addr]; }
void embed_mmu_write_cb(m_t * const m, m_t addr, m_t value) { m[addr] = value; }

int embed_fputc_cb(int ch, void *file)             { assert(file); return fputc(ch, file); }
int embed_fgetc_cb(void *file, int *no_data)       { assert(file && no_data); *no_data = 0; return fgetc(file); }
m_t *embed_core_get(embed_t *h)                    { assert(h); return h->m; }
static size_t embed_cells(embed_t const * const h) { assert(h); return MIN(h->o.read(h->m, 5), CORE_SIZE); } /* count in cells, not bytes */
m_t embed_swap(m_t s)                              { return (s >> 8) | (s << 8); }
void embed_buffer_swap(m_t *b, size_t l)           { assert(b); for(size_t i = 0; i < l; i++) b[i] = embed_swap(b[i]); }
static inline int is_big_endian(void)              { return (*(uint16_t *)"\0\xff" < 0x100); }
static void embed_normalize(embed_t *h)            { assert(h); if(is_big_endian()) embed_buffer_swap(h->m, sizeof(h->m)/2); }
embed_opt_t embed_opt_get(embed_t *h)              { assert(h); return h->o; }
void embed_opt_set(embed_t *h, embed_opt_t opt)    { assert(h); h->o = opt; }

int embed_load_buffer(embed_t *h, const uint8_t *buf, size_t length) {
	assert(h && buf);
	memcpy(h->m, buf, MIN(sizeof(h->m), length));
	embed_normalize(h);
	return length < 128 ? -70 /* read-file IOR */ : 0; /* minimum size checks, 128 bytes */
}

int embed_load_file(embed_t *h, FILE *input) {
	assert(h && input);
	size_t r = fread(h->m, 1, sizeof(h->m), input);
	embed_normalize(h);
	return r < 128 ? -70 /* read-file IOR */ : 0; /* minimum size checks, 128 bytes */
}

int embed_save_cb(const embed_t *h, const void *name, const size_t start, const size_t length) {
	assert(h);
	m_t const * const m = embed_core_get((embed_t*)h);
	const embed_mmu_read_t  mr = h->o.read;
	if(!name || !(((length - start) <= length) && ((start + length) <= embed_cells(h))))
		return -69; /* open-file IOR */
	FILE *out = fopen(name, "wb");
	if(!out)
		return -69; /* open-file IOR */
	int r = 0;
	for(size_t i = start; i < length; i++)
		if(fputc(mr(m, i)&255, out) < 0 || fputc(mr(m, i)>>8, out) < 0)
			r = -76; /* write-file IOR */
	return fclose(out) < 0 ? -62 /* close-file IOR */ : r;
}

embed_t *embed_new(void) { 
	embed_t *h = calloc(sizeof(struct embed_t), 1); 
	if(!h) 
		return NULL; 
	if(embed_load_buffer(h, embed_default_block, embed_default_block_size) < 0) {
		embed_free(h);
		return NULL;
	}
	h->o = embed_opt_default();
	return h; 
}

void     embed_free(embed_t *h)                   { assert(h); memset(h, 0, sizeof(*h)); free(h); }
embed_t *embed_copy(embed_t const * const h)      { assert(h); embed_t *r = embed_new(); if(!r) return NULL; return memcpy(r, h, sizeof(*h)); }
int      embed_save(const embed_t *h, const char *name) { assert(name); return embed_save_cb(h, name, 0, embed_cells(h)); }
size_t   embed_length(embed_t const * const h)    { return embed_cells(h) * sizeof(h->m[0]); }
int      embed_load(embed_t *h, const char *name) { FILE *f = fopen(name, "rb"); if(!f) return -69; int r = embed_load_file(h, f); fclose(f); return r; }

int embed_sgetc_cb(void *string_ptr, int *no_data) {
	assert(string_ptr);
	char **sp = (char**)string_ptr;
	char ch = **sp;
	if(!ch)
		return EOF;
	(*sp)++;
	*no_data = 0;
	return ch;
}

void embed_reset(embed_t *h) {
	assert(h);
	embed_mmu_read_t  mr = h->o.read;
	embed_mmu_write_t mw = h->o.write;
	assert(mr && mw);
	m_t * const m = h->m;
	mw(m, 0, mr(m, 0+SHADOW)), mw(m, 1, mr(m, 1+SHADOW)), mw(m, 2, mr(m, 2+SHADOW)), mw(m, 3, mr(m, 3+SHADOW));
}

int embed_eval(embed_t *h, const char *str) {
	assert(h && str);
	embed_opt_t o_old = embed_opt_get(h);
	embed_opt_t o_new = o_old;
	o_new.get = embed_sgetc_cb;
	o_new.in = &str;
	o_new.options = EMBED_VM_QUITE_ON;
	embed_opt_set(h, o_new);
	const int r = embed_vm(h);
	embed_reset(h);
	embed_opt_set(h, o_old);
	return r;
}

int embed_puts(embed_t *h, const char *s) {
	assert(h && s);
	embed_opt_t *o = &(h->o);
	int r = 0;
	if(!(o->put))
		return -21;
	for(int ch = 0; (ch = *s++); r++)
		if(ch != o->put(ch, o->out))
			return -1;
	return r;
}

int embed_push(embed_t *h, m_t value) {
	assert(h);
	m_t * const m = h->m;
	const embed_mmu_read_t  mr = h->o.read;
	const embed_mmu_write_t mw = h->o.write;
	assert(mr && mw);
	m_t rp = mr(m, 2), sp = mr(m, 3), sp0 = mr(m, 3+SHADOW);
	if(sp < 32 || sp < sp0)
		return -4; /* stack underflow */
	if(sp > (CORE_SIZE-2) || (sp+1) > rp)
		return -3; /* stack overflow */
	mw(m, ++sp, mr(m, 1));
	mw(m, 1, value);
	mw(m, 3, sp);
	return 0;
}

int embed_pop(embed_t *h, m_t *value) {
	assert(h && value);
	m_t * const m = h->m;
	const embed_mmu_read_t  mr = h->o.read;
	const embed_mmu_write_t mw = h->o.write;
	assert(mr && mw);
	m_t rp = mr(m, 2), sp = mr(m, 3), sp0 = mr(m, 3+SHADOW);
	*value = 0;
	if(sp < 32 || (sp-1) < sp0)
		return -4; /* stack underflow */
	if(sp > (CORE_SIZE-1) || sp > rp)
		return -3; /* stack overflow */
	*value = mr(m, 1);
	mw(m, 1, mr(m, sp--));
	mw(m, 3, sp);
	return 0;
}

embed_opt_t embed_opt_default(void) {
	embed_opt_t o = {
		.get      = embed_fgetc_cb, .put   = embed_fputc_cb, .save = embed_save_cb,
		.in       = stdin,          .out   = stdout,         .name = NULL, 
		.callback = NULL,           .param = NULL,
		.write    = embed_mmu_write_cb,    
		.read     = embed_mmu_read_cb,
		.options  = 0
	};
	return o;
}

#ifdef NDEBUG
#define trace(OPT,M,PC,INSTRUCTION,T,RP,SP)
#else
static int extend(uint16_t dd) { return dd & 2 ? (s_t)(dd | 0xFFFE) : dd; }

static int disassemble(m_t instruction, char *output, size_t length)
{
	if(0x8000 & instruction) {
		return snprintf(output, length, "literal %04x", (unsigned)(0x1FFF & instruction));
	} else if ((0xE000 & instruction) == 0x6000) {
		const char *ttn    =  instruction & 0x80 ? "t->n  " : "      ";
		const char *ttr    =  instruction & 0x40 ? "t->r  " : "      ";
		const char *ntt    =  instruction & 0x20 ? "n->t  " : "      ";
		const char *rtp    =  instruction & 0x10 ? "r->pc " : "      ";
		const unsigned alu = (instruction >> 8) & 0x1F;
		const int rd       = extend((instruction >> 2) & 0x3);
		const int dd       = extend((instruction     ) & 0x3);
		return snprintf(output, length, "alu     %02x    %s%s%s%s rd(%2d) dd(%2d)", alu, ttn, ttr, ntt, rtp, rd, dd);
	} else if (0x4000 & instruction) {
		return snprintf(output, length, "call    %04x", (unsigned)((0x1FFF & instruction)*2));
	} else if (0x2000 & instruction) {
		return snprintf(output, length, "0branch %04x", (unsigned)((0x1FFF & instruction)*2));
	} else {
		return snprintf(output, length, "branch  %04x", (unsigned)(instruction*2));
	}
}

static inline void trace(embed_t *h, m_t pc, m_t instruction, m_t t, m_t rp, m_t sp) {
	embed_opt_t *o = &(h->o);
	if(!(o->options & EMBED_VM_TRACE_ON) || !(o->put))
		return;
	const embed_mmu_read_t  mr = o->read;
	m_t * const m = h->m;
	assert(mr);
	char buf[64] = { 0 };
	snprintf(buf, sizeof buf, "[ %4x %4x %4x %2x %2x : ", pc-1, instruction, t, (m_t)(mr(m, 2+SHADOW)-rp), (m_t)(sp-mr(m, 3+SHADOW)));
	embed_puts(h, buf);
	disassemble(instruction, buf, sizeof buf);
	embed_puts(h, buf);
	embed_puts(h, " ]\n");
}
#endif

int embed_vm(embed_t * const h) {
	assert(h);
	BUILD_BUG_ON (sizeof(m_t)    != sizeof(s_t));
	BUILD_BUG_ON((sizeof(m_t)*2) != sizeof(d_t));
	embed_opt_t *o = &(h->o);
	static const m_t delta[] = { 0, 1, -2, -1 }; /* two bit signed value */
	const embed_mmu_read_t  mr = o->read;
	const embed_mmu_write_t mw = o->write;
	assert(mr && mw);
	const m_t l = embed_cells(h); 
	m_t * const m = h->m;
	m_t pc = mr(m, 0), t = mr(m, 1), rp = mr(m, 2), sp = mr(m, 3), r = 0;
	for(d_t d;;) {
		const m_t instruction = mr(m, pc++);
		trace(h, pc, instruction, t, rp, sp);
		if((r = -!(sp < l && rp < l && pc < l))) /* critical error */
			goto finished;
		if(0x8000 & instruction) { /* literal */
			mw(m, ++sp, t);
			t       = instruction & 0x7FFF;
		} else if ((0xE000 & instruction) == 0x6000) { /* ALU */
			m_t n = mr(m, sp), T = t;
			pc = instruction & 0x10 ? mr(m, rp) >> 1 : pc;

			switch((instruction >> 8u) & 0x1f) {
			case  0: T = t;                    break;
			case  1: T = n;                    break;
			case  2: T = mr(m, rp);            break;
			case  3: T = mr(m, (t>>1)%l);      break;
			case  4: mw(m, (t>>1)%l, n); T = mr(m, --sp); break;
			case  5: d = (d_t)t + n; T = d >> 16; mw(m, sp, d); n = d; break;
			case  6: d = (d_t)t * n; T = d >> 16; mw(m, sp, d); n = d; break;
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
			case 22: if(o->save) { T = o->save(h, o->name, n>>1, ((d_t)t+1)>>1); }    else { pc=4; T=21; } break;
			case 23: if(o->put)  { T = o->put(t, o->out); }                           else { pc=4; T=21; } break; 
			case 24: if(o->get)  { int nd = 0; mw(m, ++sp, t); T = o->get(o->in, &nd); t = T; n = nd; } else { pc=4; T=21; } break;
			case 25: if(t)       { d = mr(m, --sp)|((d_t)n<<16); T=d/t; t=d%t; n=t; } else { pc=4; T=10; } break;
			case 26: if(t)       { T=(s_t)n/t; t=(s_t)n%t; n=t; }                     else { pc=4; T=10; } break;
			case 27: if(n)       { mw(m, sp, 0); r = t; goto finished; } break;
			case 28: if(o->callback) { 
					 mw(m, 0, pc), mw(m, 1, t), mw(m, 2, rp), mw(m, 3, sp); 
					 r = o->callback(h, o->param);
					 pc = mr(m, 0), T = mr(m, 1), rp = mr(m, 2), sp = mr(m, 3); 
					 if(r) { pc = 4; T = r; }
				 } else { pc=4; T=21; } break;
			case 29: T = o->options; o->options = t; break;
			default: pc = 4; T=21; /* not implemented */ break;
			}
			sp += delta[ instruction       & 0x3];
			rp -= delta[(instruction >> 2) & 0x3];
			if(instruction & 0x80)
				mw(m, sp, t);
			if(instruction & 0x40)
				mw(m, rp, t);
			t = instruction & 0x20 ? n : T;
		} else if (0x4000 & instruction) { /* call */
			mw(m, --rp, pc << 1);
			pc      = instruction & 0x1FFF;
		} else if (0x2000 & instruction) { /* 0branch */
			pc = !t ? instruction & 0x1FFF : pc;
			t  = mr(m, sp--);
		} else { /* branch */
			pc = instruction & 0x1FFF;
		}
	}
finished: mw(m, 0, pc), mw(m, 1, t), mw(m, 2, rp), mw(m, 3, sp); /* NB. Shadow registers not modified */
	return (s_t)r;
}

int embed_forth_opt(embed_t *h, embed_vm_option_e opt, FILE *in, FILE *out, const char *block) {
	embed_opt_t o_old = embed_opt_default();
	embed_opt_t o_new = o_old;
	o_new.in = in, o_new.out = out, o_new.options = opt, o_new.name = block;
	embed_opt_set(h, o_new);
	const int r = embed_vm(h);
	embed_opt_set(h, o_old);
	return r;
}

int embed_forth(embed_t *h, FILE *in, FILE *out, const char *block) { return embed_forth_opt(h, 0, in, out, block); }

