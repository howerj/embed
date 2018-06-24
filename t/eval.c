#include "embed.h"
#include <assert.h>
#include <stdio.h>
#include <string.h>

/**@todo pass a parameter into the callback mechanism that contains a floating
 * point stack, and write floating point numbers to the same output stream
 * using sprintf the VMs output methods. Also extracting strings and putting
 * strings into the interpreter need to be managed.
 * @todo Return throwable numbers instead of dieing */

static embed_t *embed_new_default(void)
{
	embed_t *h = embed_new();
	if(!h)
		return NULL;
	if(embed_load_buffer(h, embed_default_block, embed_default_block_size) < 0) {
		embed_free(h);
		return NULL;
	}
	return h;
}

static int eval_sgetc(void *string_ptr)
{
	assert(string_ptr);
	char **sp = (char**)string_ptr;
	char ch = **sp;
	if(!ch)
		return EOF;
	(*sp)++;
	return ch;
}

static int embed_eval(embed_t *h, const char *str)
{
	assert(h && str);
	/*size_t length = strlen(str);
	if(length > 79 || length < 1)
		return -1;
	if(str[length-1] != '\n')
		return -1;*/
	embed_opt_t o = embed_options_default();
	o.get = eval_sgetc;
	o.in = &str;
	o.options = EMBED_VM_QUITE_ON;
	int r = embed_vm(h, &o);
	embed_reset(h);
	return r;
}


struct vm_extension_t;
typedef struct vm_extension_t vm_extension_t;

typedef int (*embed_callback_extended_t)(embed_t *h, vm_extension_t *v);
typedef struct { 
	embed_callback_extended_t cb; 
	const char *name; 
} callbacks_t;

struct vm_extension_t {
	float f[128];
	size_t fsp;
	embed_opt_t o;
};

#define CALLBACK_XMACRO\
	X("d+",      cb_dplus)\
	X("d*",      cb_dmul)\
	X("d.",      cb_dprint)\
	X("d-",      cb_dsub)\
	X("d/",      cb_ddiv)\
	X("d<",      cb_dless)\
	X("d>",      cb_dmore)\
	X("d=",      cb_dequal)\
	X("dnegate", cb_dnegate)\
	X("f.",      cb_flt_print)\
	X("f+",      cb_fadd)\
	X("f-",      cb_fsub)\
	X("f*",      cb_fmul)\
	X("f/",      cb_fdiv)\
	X("d>f",     cb_d2f)\
	X("f>d",     cb_f2d)\
	X("f<",      cb_fless)\
	X("f>",      cb_fmore)

#define X(NAME, FUNCTION) static int FUNCTION ( embed_t *h, vm_extension_t *v );
	CALLBACK_XMACRO
#undef X

static callbacks_t callbacks[] = {
#define X(NAME, FUNCTION) { .name = NAME, .cb = FUNCTION },
	CALLBACK_XMACRO
#undef X
};

static inline size_t number_of_callbacks(void) { return sizeof(callbacks) / sizeof(callbacks[0]); }

static uint16_t pop(embed_t *h)
{
	assert(h);
	uint16_t rv = 0;
	if(embed_pop(h, &rv) < 0)
		embed_fatal("embed: underflow");
	return rv;
}

static void push(embed_t *h, uint16_t value)
{
	assert(h);
	if(embed_push(h, value) < 0)
		embed_fatal("embed: overflow");
}

/*static void ipush(embed_t *h, int16_t value) { push(h, value); }
static int16_t ipop(embed_t *h)              { return pop(h); }*/

static void udpush(embed_t *h, uint32_t value)
{
	push(h, value);
	push(h, value >> 16);
}

static uint32_t udpop(embed_t *h)
{
	uint32_t hi = pop(h);
	uint32_t lo = pop(h);
	uint32_t d  = (hi << 16) | lo;
	return d;
}

static int32_t dpop(embed_t *h) { return udpop(h); }
static void    dpush(embed_t *h, int32_t value) { udpush(h, value); }

typedef union { float f; uint32_t d; } fd_u;

/**@todo convert to use vm_extension_t */
static float fpop(embed_t *h)
{
	fd_u fd;
	fd.d = udpop(h);
	return fd.f;
}

static void fpush(embed_t *h, float f)
{
	fd_u fd;
	fd.f = f;
	udpush(h, fd.d);
}

static int cb_dplus(embed_t *h, vm_extension_t *v)
{
	UNUSED(v);
	int32_t d1 = dpop(h);
	int32_t d2 = dpop(h);
	dpush(h, d1+d2);
	return 0;
}

static int cb_dmul(embed_t *h, vm_extension_t *v)
{
	UNUSED(v);
	int32_t d1 = dpop(h);
	int32_t d2 = dpop(h);
	dpush(h, d1*d2);
	return 0;
}

static int cb_dsub(embed_t *h, vm_extension_t *v)
{
	UNUSED(v);
	int32_t d1 = dpop(h);
	int32_t d2 = dpop(h);
	dpush(h, d1-d2);
	return 0;
}

static int cb_ddiv(embed_t *h, vm_extension_t *v)
{
	UNUSED(v);
	int32_t d1 = dpop(h);
	int32_t d2 = dpop(h);
	if(!d2)
		return 10; /* throw division by zero */
	dpush(h, d1/d2);
	return 0;
}

static int cb_dnegate(embed_t *h, vm_extension_t *v)
{
	UNUSED(v);
	dpush(h, -dpop(h));
	return 0;
}

static int cb_dless(embed_t *h, vm_extension_t *v)
{
	UNUSED(v);
	int32_t d1 = dpop(h);
	int32_t d2 = dpop(h);
	push(h, -(d1<d2));
	return 0;
}

static int cb_dmore(embed_t *h, vm_extension_t *v)
{
	UNUSED(v);
	int32_t d1 = dpop(h);
	int32_t d2 = dpop(h);
	push(h, -(d1>d2));
	return 0;
}

static int cb_dequal(embed_t *h, vm_extension_t *v)
{
	UNUSED(v);
	int32_t d1 = dpop(h);
	int32_t d2 = dpop(h);
	push(h, -(d1==d2));
	return 0;
}

static int cb_dprint(embed_t *h, vm_extension_t *v)
{
	UNUSED(v);
	fprintf(stdout, "%ld", (long)dpop(h));
	return 0;
}

static int cb_flt_print(embed_t *h, vm_extension_t *v)
{
	UNUSED(v);
	fprintf(stdout, "%f", fpop(h));
	return 0;
}

static int cb_fadd(embed_t *h, vm_extension_t *v)
{
	UNUSED(v);
	fpush(h, fpop(h) + fpop(h));
	return 0;
}

static int cb_fmul(embed_t *h, vm_extension_t *v)
{
	UNUSED(v);
	fpush(h, fpop(h) * fpop(h));
	return 0;
}

static int cb_fsub(embed_t *h, vm_extension_t *v)
{
	UNUSED(v);
	const float f1 = fpop(h);
	const float f2 = fpop(h);
	fpush(h, f1 - f2);
	return 0;
}

static int cb_fdiv(embed_t *h, vm_extension_t *v)
{
	UNUSED(v);
	const float f1 = fpop(h);
	const float f2 = fpop(h);
	if(f2 == 0.0f)
		return 42; /* floating point division by zero */
	fpush(h, f1 / f2);
	return 0;
}

static int cb_d2f(embed_t *h, vm_extension_t *v)
{
	UNUSED(v);
	fpush(h, dpop(h));
	return 0;
}

static int cb_f2d(embed_t *h, vm_extension_t *v)
{
	UNUSED(v);
	dpush(h, fpop(h));
	return 0;
}

static int cb_fless(embed_t *h, vm_extension_t *v)
{
	UNUSED(v);
	const float f1 = fpop(h);
	const float f2 = fpop(h);
	fpush(h, f1 < f2);
	return 0;
}

static int cb_fmore(embed_t *h, vm_extension_t *v)
{
	UNUSED(v);
	const float f1 = fpop(h);
	const float f2 = fpop(h);
	fpush(h, f1 > f2);
	return 0;
}

static int callbacks_add(embed_t *h, callbacks_t *cb, size_t number)
{
	assert(h && cb);
	for(size_t i = 0; i < number; i++) {
		char line[80] = { 0 };
		int r = snprintf(line, sizeof(line) - 1, ": %s %u vm ;\n", cb[i].name, (unsigned)i);
		if(r < 0)
			return -1;
		if((r = embed_eval(h, line)) < 0)
			return r;
	}
	return 0;
}

static int callback_selector(embed_t *h, void *param)
{
	assert(h);
	uint16_t func = pop(h);
	if(func >= number_of_callbacks())
		return -21;
	return callbacks[func].cb(h, param);
}

int main(void)
{
	embed_t *h    = embed_new_default();
	vm_extension_t e = { .f = { 0 } };
	e.o = embed_options_default();
	if(!h)
		embed_fatal("embed: load failed");
	e.o.callback = callback_selector;
	e.o.param    = &e;
	if(callbacks_add(h, callbacks, number_of_callbacks()) < 0)
		embed_fatal("embed: failed to register callbacks");
	int r = embed_vm(h, &e.o);
	embed_free(h);
	return r;
}

