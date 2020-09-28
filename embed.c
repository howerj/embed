/* Embed Forth Virtual Machine, Richard James Howe, 2017-2018, MIT License */
#include "embed.h"
#include <assert.h>
#include <stdint.h>
#include <stddef.h>
#include <stdio.h>
#include <string.h>

#define SHADOW    (7)     /**< start location of shadow registers */
#define MIN(X, Y) ((X) > (Y) ? (Y) : (X))

typedef cell_t        m_t; /**< The VM is 16-bit, 'uintptr_t' would be more useful */
typedef signed_cell_t s_t; /**< used for signed calculation and casting */
typedef double_cell_t d_t; /**< should be double the size of 'm_t' and unsigned */

/* NB. MMU operations could be improved by allowing exceptions to be thrown */
m_t  embed_mmu_read_cb(embed_t const * const h, m_t addr)       { return ((m_t*)h->m)[addr]; }
void embed_mmu_write_cb(embed_t * const h, m_t addr, m_t value) { ((m_t*)h->m)[addr] = value; }

static inline int is_big_endian(void)              { return (*(uint16_t *)"\0\xff" < 0x100); }
static void embed_normalize(embed_t *h, size_t l)  { assert(h); if (is_big_endian()) embed_buffer_swap(h->m, l); }
int embed_nputc_cb(int ch, void *file)             { (void)file; return ch; }
int embed_ngetc_cb(void *file, int *no_data)       { (void)file; assert(no_data); *no_data = 0; return -1; }
m_t *embed_core_get(embed_t *h)                    { assert(h); return h->m; }
size_t embed_cells(embed_t const * const h)        { assert(h); return MIN(h->o.read(h, 5), EMBED_CORE_SIZE); } /* count in cells, not bytes */
static inline m_t embed_swap(m_t s)                { return (s >> 8) | (s << 8); }
void embed_buffer_swap(m_t *b, size_t l)           { assert(b); for (size_t i = 0; i < l; i++) b[i] = embed_swap(b[i]); }
embed_opt_t *embed_opt_get(embed_t *h)             { assert(h); return &h->o; }
void embed_opt_set(embed_t *h, embed_opt_t *opt)   { assert(h && opt); memcpy(&h->o, opt, sizeof(*opt)); }
int embed_yield_cb(void *param)                    { (void)(param); return 0; }
size_t embed_length(embed_t const * const h)       { return embed_cells(h) * sizeof(m_t); }

int embed_load_buffer(embed_t *h, const uint8_t *buf, size_t length) {
	assert(h && buf);
	memcpy(h->m, buf, MIN(EMBED_CORE_SIZE*2, length));
	embed_normalize(h, length/2);
	return length < 128 ? -70 /* read-file IOR */ : 0; /* minimum size checks, 128 bytes */
}

int embed_default(embed_t *h) {
	assert(h && h->m);
	h->o = embed_opt_default();
	return embed_load_buffer(h, embed_default_block, embed_default_block_size);
}

int embed_sgetc_cb(void *string_ptr, int *no_data) {
	assert(string_ptr && no_data);
	char **sp = (char**)string_ptr;
	const char ch = **sp;
	if (!ch)
		return -1;
	(*sp)++;
	*no_data = 0;
	return ch;
}

void embed_reset(embed_t *h) {
	assert(h && h->m);
	embed_mmu_read_t  mr = h->o.read;
	embed_mmu_write_t mw = h->o.write;
	assert(mr && mw);
	mw(h, 0, mr(h, 0+SHADOW)), mw(h, 1, mr(h, 1+SHADOW)), mw(h, 2, mr(h, 2+SHADOW)), mw(h, 3, mr(h, 3+SHADOW));
}

int embed_eval(embed_t *h, const char *str) {
	assert(h && str);
	embed_opt_t o_old = *embed_opt_get(h);
	embed_opt_t o_new = o_old;
	o_new.get = embed_sgetc_cb;
	o_new.in = &str;
	o_new.options = EMBED_VM_QUITE_ON;
	embed_opt_set(h, &o_new);
	const int r = embed_vm(h);
	embed_opt_set(h, &o_old);
	return r;
}

int embed_puts(embed_t *h, const char *s) {
	assert(h && s);
	embed_opt_t *o = &(h->o);
	int r = 0;
	if (!(o->put))
		return -21; /* not implemented */
	for (int ch = 0; (ch = *s++); r++)
		if (ch != o->put(ch, o->out))
			return -1;
	return r;
}

int embed_push(embed_t *h, m_t value) {
	assert(h);
	const embed_mmu_read_t  mr = h->o.read;
	const embed_mmu_write_t mw = h->o.write;
	assert(mr && mw);
	m_t rp = mr(h, 2), sp = mr(h, 3), sp0 = mr(h, 3 + SHADOW);
	if (sp < 32 || sp < sp0)
		return -4; /* stack underflow */
	if (sp > (EMBED_CORE_SIZE - 2) || (sp + 1) > rp)
		return -3; /* stack overflow */
	mw(h, ++sp, mr(h, 1));
	mw(h, 1, value);
	mw(h, 3, sp);
	return 0;
}

int embed_pop(embed_t *h, m_t *value) {
	assert(h);
	const embed_mmu_read_t  mr = h->o.read;
	const embed_mmu_write_t mw = h->o.write;
	assert(mr && mw);
	m_t rp = mr(h, 2), sp = mr(h, 3), sp0 = mr(h, 3+SHADOW);
	if (value)
		*value = 0;
	if (sp < 32 || (sp - 1) < sp0)
		return -4; /* stack underflow */
	if (sp > (EMBED_CORE_SIZE - 1) || sp > rp)
		return -3; /* stack overflow */
	if (value)
		*value = mr(h, 1);
	mw(h, 1, mr(h, sp--));
	mw(h, 3, sp);
	return 0;
}

size_t embed_depth(embed_t *h) {
	assert(h);
	const embed_mmu_read_t  mr = h->o.read;
	const m_t sp = mr(h, 3), sp0 = mr(h, 3 + SHADOW);
	return sp - sp0;
}

embed_opt_t embed_opt_default(void) {
	embed_opt_t o = {
		.get      = embed_ngetc_cb, .put   = embed_nputc_cb, .save = NULL,
		.in       = NULL,           .out   = NULL,           .name = NULL,
		.write    = embed_mmu_write_cb,
		.read     = embed_mmu_read_cb,
		.yield    = embed_yield_cb
	};
	return o;
}

#ifdef NDEBUG
#define trace(VM,PC,INSTRUCTION,T,RP,SP)
#else
static int extend(uint16_t dd) { return (dd & 2) ? (s_t)(dd | 0xFFFE) : dd; }

static int disassemble(m_t instruction, char *output, size_t length) {
	assert(output);
	if ((0x8000 & instruction)) {
		return snprintf(output, length, "literal %04x", (unsigned)(0x1FFF & instruction));
	} else if ((0xE000 & instruction) == 0x6000) {
		const unsigned alu = (instruction >> 8) & 0x1F;
		const char *ttn    = (instruction & 0x80) ? "t->n  " : "      ";
		const char *ttr    = (instruction & 0x40) ? "t->r  " : "      ";
		const char *ntt    = (instruction & 0x20) ? "n->t  " : "      ";
		const char *rtp    = (instruction & 0x10) ? "r->pc " : "      ";
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
	if (!(o->options & EMBED_VM_TRACE_ON) || !(o->put))
		return;
	const embed_mmu_read_t  mr = o->read;
	assert(mr);
	char buf[64] = { 0 };
	snprintf(buf, sizeof buf, "[ %4x %4x %4x %2x %2x : ", pc - 1, instruction, t, (m_t)(mr(h, 2 + SHADOW) - rp), (m_t)(sp - mr(h, 3 + SHADOW)));
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
	const embed_mmu_read_t  mr    = o->read;
	const embed_mmu_write_t mw    = o->write;
	const embed_yield_t     yield = o->yield;
	void  *yields = o->yields;
	assert(mr && mw && yield);
	const m_t l = embed_cells(h);
	m_t pc = mr(h, 0), t = mr(h, 1), rp = mr(h, 2), sp = mr(h, 3), r = 0;
	for (d_t d; !yield(yields); ) {
		const m_t instruction = mr(h, pc++);
		trace(h, pc, instruction, t, rp, sp);
		if ((r = -!(sp < l && rp < l && pc < l))) /* critical error */
			goto finished;
		if (0x8000 & instruction) { /* literal */
			mw(h, ++sp, t);
			t       = instruction & 0x7FFF;
		} else if ((0xE000 & instruction) == 0x6000) { /* ALU */
			m_t n = mr(h, sp), T = t;
			pc = (instruction & 0x10) ? (mr(h, rp) >> 1) : pc;
			switch((instruction >> 8u) & 0x1f) {
			case  0:  T = t;                  break;
			case  1:  T = n;                  break;
			case  2:  T = mr(h, rp);          break;
			case  3:  T = mr(h, (t>>1)%l);    break;
			case  4:  mw(h, (t>>1)%l, n); T = mr(h, --sp); break;
			case  5:  d = (d_t)t + n; T = d >> 16; mw(h, sp, d); n = d; break;
			case  6:  d = (d_t)t * n; T = d >> 16; mw(h, sp, d); n = d; break;
			case  7:  T = t&n;                break;
			case  8:  T = t|n;                break;
			case  9:  T = t^n;                break;
			case 10:  T = ~t;                 break;
			case 11:  T = t-1;                break;
			case 12:  T = -(t == 0);          break;
			case 13:  T = -(t == n);          break;
			case 14:  T = -(n < t);           break;
			case 15:  T = -((s_t)n < (s_t)t); break;
			case 16:  T = n >> t;             break;
			case 17:  T = n << t;             break;
			case 18:  T = sp << 1;            break;
			case 19:  T = rp << 1;            break;
			case 20: sp = t >> 1;             break;
			case 21: rp = t >> 1; T = n;      break;
			case 22: if (o->save) { T = o->save(h, o->name, n >> 1, ((d_t)t + 1) >> 1); } else { pc = 4; T = 21; } break;
			case 23: if (o->put) { T = o->put(t, o->out); } else { pc = 4; T = 21; } break;
			case 24: if (o->get) { int nd = 0; mw(h, ++sp, t); T = o->get(o->in, &nd); t = T; n = nd; } else { pc = 4; T = 21; } break;
			case 25: if (t) { d = mr(h, --sp) | ((d_t)n << 16); T= d / t; t = d % t; n = t; } else { pc = 4; T=10; } break;
			case 26: if (t) { T=(s_t)n / t; t=(s_t)n % t; n = t; } else { pc = 4; T = 10; } break;
			case 27: if (mr(h, rp)) { mw(h, rp, 0); sp--; r = t; t = n; goto finished; }; T = t; break;
			case 28: if (o->callback) {
					 mw(h, 0, pc), mw(h, 1, t), mw(h, 2, rp), mw(h, 3, sp);
					 r = o->callback(h, o->param);
					 pc = mr(h, 0), T = mr(h, 1), rp = mr(h, 2), sp = mr(h, 3);
					 if (r) { pc = 4; T = r; }
				 } else { pc = 4; T = 21; }  break;
			case 29: T = o->options; o->options = t; break;
			default: pc = 4; T = 21; /* not implemented */ break;
			}
			sp += delta[ instruction       & 0x3];
			rp -= delta[(instruction >> 2) & 0x3];
			if (instruction & 0x80)
				mw(h, sp, t);
			if (instruction & 0x40)
				mw(h, rp, t);
			t = (instruction & 0x20) ? n : T;
		} else if (0x4000 & instruction) { /* call */
			mw(h, --rp, pc << 1);
			pc      = instruction & 0x1FFF;
		} else if (0x2000 & instruction) { /* 0branch */
			pc = !t ? instruction & 0x1FFF : pc;
			t  = mr(h, sp--);
		} else { /* branch */
			pc = instruction & 0x1FFF;
		}
	}
finished: mw(h, 0, pc), mw(h, 1, t), mw(h, 2, rp), mw(h, 3, sp);
	return (s_t)r;
}

