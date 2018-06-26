/*! This file shows how you can extend the embed virtual machine using its
 * library API to add double and floating point words to that are accessible
 * via the eForth image.
 *
 * @todo Implement separate floating point stack 
 * @todo Implement extracting strings and putting strings into the interpreter
 * @todo Use C++ templates instead?
 */

#include "embed.h"
#include <stdbool.h>
#include <assert.h>
#include <string.h>
#include <stdlib.h>

struct vm_extension_t;
typedef struct vm_extension_t vm_extension_t;

typedef int (*embed_callback_extended_t)(vm_extension_t *v);
typedef struct { 
	embed_callback_extended_t cb; /**< Callback for function */
	const char *name;             /**< Forth function */
} callbacks_t;

struct vm_extension_t {
	embed_t *h;              /**< embed VM instance we are operating with */
	callbacks_t *callbacks;  /**< callbacks to use with this instance */
	size_t callbacks_length; /**< length of 'callbacks' field */
	float f[128];            /**< floating point stack */
	size_t fsp;              /**< floating point stack pointer */
	embed_opt_t o;           /**< embed virtual machine options */
	uint16_t error;          /**< current error condition */
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

#define X(NAME, FUNCTION) static int FUNCTION ( vm_extension_t * const v );
	CALLBACK_XMACRO
#undef X

static callbacks_t callbacks[] = {
#define X(NAME, FUNCTION) { .name = NAME, .cb = FUNCTION },
	CALLBACK_XMACRO
#undef X
};

static inline size_t number_of_callbacks(void) { return sizeof(callbacks) / sizeof(callbacks[0]); }

static int call_puts(embed_opt_t *o, const char *s) 
{
	assert(o && s);
	int r = 0;
	if(!(o->put))
		return -1;
	for(int ch = 0;(ch = *s++); r++)
		if(ch != o->put(ch, o->out))
			return -1;
	return r;
}

static inline void eset(vm_extension_t * const v, const uint16_t error) /**< set error register if not set */
{
	assert(v);
	if(!(v->error))
		v->error = error;
}

static inline uint16_t eget(vm_extension_t const * const v) /**< get current error register */
{
	assert(v);
	return v->error;
}

static inline uint16_t eclr(vm_extension_t * const v) /**< clear error register and return value before clear */
{
	assert(v);
	const uint16_t error = v->error;
	v->error = 0;
	return error;
}

static inline uint16_t pop(vm_extension_t *v)
{
	assert(v);
	if(eget(v))
		return 0;
	uint16_t rv = 0;
	int e = 0;
	if((e = embed_pop(v->h, &rv)) < 0)
		eset(v, e);
	return rv;
}

static inline void push(vm_extension_t * const v, const uint16_t value)
{
	assert(v);
	if(eget(v))
		return;
	int e = 0;
	if((e = embed_push(v->h, value)) < 0)
		eset(v, e);
}

static inline void udpush(vm_extension_t * const v, const uint32_t value)
{
	push(v, value);
	push(v, value >> 16);
}

static inline uint32_t udpop(vm_extension_t * const v)
{
	const uint32_t hi = pop(v);
	const uint32_t lo = pop(v);
	const uint32_t d  = (hi << 16) | lo;
	return d;
}

static inline int32_t dpop(vm_extension_t * const v)                       { return udpop(v); }
static inline void    dpush(vm_extension_t * const v, const int32_t value) { udpush(v, value); }

typedef union { float f; uint32_t d; } fd_u;

static inline float fpop(vm_extension_t * const v)
{
	const fd_u fd = { .d = udpop(v) };
	return fd.f;
}

static inline void fpush(vm_extension_t * const v, const float f)
{
	const fd_u fd = { .f = f };
	udpush(v, fd.d);
}

static int cb_dplus(vm_extension_t * const v)
{
	const int32_t d1 = dpop(v);
	const int32_t d2 = dpop(v);
	dpush(v, d1 + d2);
	return eclr(v);
}

static int cb_dmul(vm_extension_t * const v)
{
	const int32_t d1 = dpop(v);
	const int32_t d2 = dpop(v);
	dpush(v, d1 * d2);
	return eclr(v);
}

static int cb_dsub(vm_extension_t * const v)
{
	const int32_t d1 = dpop(v);
	const int32_t d2 = dpop(v);
	dpush(v, d2 - d1);
	return eclr(v);
}

static int cb_ddiv(vm_extension_t * const v)
{
	const int32_t d1 = dpop(v);
	const int32_t d2 = dpop(v);
	if(!d1) {
		eset(v, 10); /* division by zero */
		return eclr(v); 
	}
	dpush(v, d2 / d1);
	return eclr(v);
}

static int cb_dnegate(vm_extension_t * const v)
{
	dpush(v, -dpop(v));
	return eclr(v);
}

static int cb_dless(vm_extension_t * const v)
{
	const int32_t d1 = dpop(v);
	const int32_t d2 = dpop(v);
	push(v, -(d2 < d1));
	return eclr(v);
}

static int cb_dmore(vm_extension_t * const v)
{
	const int32_t d1 = dpop(v);
	const int32_t d2 = dpop(v);
	push(v, -(d2 > d1));
	return eclr(v);
}

static int cb_dequal(vm_extension_t * const v)
{
	const int32_t d1 = dpop(v);
	const int32_t d2 = dpop(v);
	push(v, -(d1 == d2));
	return eclr(v);
}

static int cb_dprint(vm_extension_t * const v)
{
	const long d = dpop(v);
	if(eget(v))
		return eclr(v);
	char buf[80] = { 0 };
	snprintf(buf, sizeof(buf)-1, "%ld", d); /**@bug does not respect eForth base */
	call_puts(&v->o, buf);
	return eclr(v);
}

static int cb_flt_print(vm_extension_t * const v)
{
	const float flt = fpop(v);
	char buf[512] = { 0 }; /* floats can be quite large */
	if(eget(v))
		return eclr(v);
	snprintf(buf, sizeof(buf)-1, "%e", flt);
	call_puts(&v->o, buf);
	return eclr(v);
}

static int cb_fadd(vm_extension_t * const v)
{
	fpush(v, fpop(v) + fpop(v));
	return eclr(v);
}

static int cb_fmul(vm_extension_t * const v)
{
	fpush(v, fpop(v) * fpop(v));
	return eclr(v);
}

static int cb_fsub(vm_extension_t * const v)
{
	const float f1 = fpop(v);
	const float f2 = fpop(v);
	fpush(v, f2 - f1);
	return eclr(v);
}

static int cb_fdiv(vm_extension_t * const v)
{
	const float f1 = fpop(v);
	const float f2 = fpop(v);
	if(f1 == 0.0f) {
		eset(v, 42); /* floating point division by zero */
		return eclr(v);
	}
	fpush(v, f2 / f1);
	return eclr(v);
}

static int cb_d2f(vm_extension_t * const v)
{
	fpush(v, dpop(v));
	return eclr(v);
}

static int cb_f2d(vm_extension_t * const v)
{
	dpush(v, fpop(v));
	return eclr(v);
}

static int cb_fless(vm_extension_t * const v)
{
	const float f1 = fpop(v);
	const float f2 = fpop(v);
	push(v, -(f2 < f1));
	return eclr(v);
}

static int cb_fmore(vm_extension_t * const v)
{
	const float f1 = fpop(v);
	const float f2 = fpop(v);
	push(v, -(f2 > f1));
	return eclr(v);
}

/*! The virtual machine has only one callback, which we can then use to vector
 * into a table of callbacks provided in 'param', which is a pointer to an
 * instance of 'vm_extension_t' */
static int callback_selector(embed_t *h, void *param)
{
	assert(h);
	assert(param);
	vm_extension_t *e = (vm_extension_t*)param;
	if(e->h != h)
		embed_fatal("embed extensions: instance corruption");
	eclr(e);
	uint16_t func = pop(e);
	if(eget(e))
		return eclr(e);
	if(func >= e->callbacks_length)
		return -21;
	return e->callbacks[func].cb(e);
}

/*! This adds the call backs to an instance of the virtual machine running
 * an eForth image by defining new words in it with 'embed_eval'.
 */
static int callbacks_add(embed_t * const h, const bool optimize,  callbacks_t *cb, const size_t number)
{
	assert(h && cb);
	for(size_t i = 0; i < number; i++) {
		char line[80] = { 0 };
		const char *optimizer = optimize ? "-2 cells allot ' vm chars ," : "";
		int r = snprintf(line, sizeof(line) - 1, ": %s %u vm ; %s\n", cb[i].name, (unsigned)i, optimizer);
		if(r < 0)
			return -1;
		if((r = embed_eval(h, line)) < 0)
			return r;
	}
	return 0;
}

static vm_extension_t *vm_extension_new(void)
{
	vm_extension_t *v = embed_alloc(sizeof(*v));
	if(!v)
		return NULL;
	v->h = embed_new();
	if(!(v->h))
		goto fail;

	v->callbacks_length = number_of_callbacks(), 
	v->callbacks        = callbacks;
	v->o                = embed_options_default();
	v->o.callback       = callback_selector;
	v->o.param          = v;

	if(callbacks_add(v->h, true, v->callbacks, v->callbacks_length) < 0)
		goto fail; /**@todo use embed_debug throughout? */

	return v;
fail:
	if(v->h)
		embed_free(v->h);
	return NULL;
}

static int vm_extension_run(vm_extension_t *v)
{
	assert(v);
	return embed_vm(v->h, &v->o);
}

static void vm_extension_free(vm_extension_t *v)
{
	assert(v);
	embed_free(v->h);
	memset(v, 0, sizeof(*v));
	free(v);
}

int main(void)
{
	vm_extension_t *v = vm_extension_new();
	if(!v)
		embed_fatal("embed extensions: load failed");
	const int r = vm_extension_run(v);
	vm_extension_free(v);
	return r;
}

