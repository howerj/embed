#include "embed.h"
#include <assert.h>
#include <stdio.h>

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
	embed_opt_t o = embed_options_default();
	o.get = eval_sgetc;
	o.in = &str;
	o.options = EMBED_VM_QUITE_ON;
	int r = embed_vm(h, &o);
	embed_reset(h);
	return r;
}

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

static void dpush(embed_t *h, int32_t value)
{
	uint32_t v = value;
	push(h, v);
	push(h, v >> 16);
}

static int32_t dpop(embed_t *h)
{
	uint32_t hi = pop(h);
	uint32_t lo = pop(h);
	uint32_t d  = (hi << 16) | lo;
	return d;
}

static int cb_range(embed_t *h, void *param) /* push range from 1 to n */
{
	UNUSED(param);
	for(uint16_t n = pop(h), i = 1; i <= n; i++)
		push(h, i);
	return 0;
}

static int cb_vadd(embed_t *h, void *param) /* reduce vector with addition */
{       
	UNUSED(param);
	uint16_t r = 0;
	for(uint16_t n = pop(h), i = 0;  i < n; i++)
		r += pop(h);
	push(h, r);
	return 0;
}

static int cb_vmul(embed_t *h, void *param) /* reduce vector with multiplication */
{       
	UNUSED(param);
	uint16_t r = 1;
	for(uint16_t n = pop(h), i = 0;  i < n; i++)
		r *= pop(h);
	push(h, r);
	return 0;
}

static int callback(embed_t *h, void *param)
{
	assert(h);
	switch(pop(h)) {
	case 0: return cb_range(h, param); break;
	case 1: return cb_vadd(h, param); break;
	case 2: return cb_vmul(h, param); break;
	case 3: /* drop and print stack */
		fputs("\nCB>\n\t", stdout);
		for(uint16_t v = 0, i = 1; embed_pop(h, &v) == 0; fprintf(stdout, "%04x%s", v, (i%16) ? " " : "\n\t"), i++);
		fputs("\n", stdout);
		break;
	case 4:
		fprintf(stdout, "param(%p)\n", param);
		break;
	case 5:
	{
		int32_t d1 = dpop(h);
		int32_t d2 = dpop(h);
		dpush(h, d1+d2);
		break;
	}
	case 6:
	{
		int32_t d1 = dpop(h);
		int32_t d2 = dpop(h);
		dpush(h, d1*d2);
		break;
	}
	case 7:
		fprintf(stdout, "%lu", (long)dpop(h));
	default:
		break;
	}
	return 0;
}

int main(void)
{
	embed_t *h    = embed_new_default();
	embed_opt_t o = embed_options_default();
	if(!h)
		embed_fatal("embed: load failed");

	embed_eval(h, " :  1..n  0 vm ;\n");
	embed_eval(h, " :  v+    1 vm ;\n");
	embed_eval(h, " :  v*    2 vm ;\n");
	embed_eval(h, " : .sdrop 3 vm ;\n");
	embed_eval(h, " : .param 4 vm ;\n");
	embed_eval(h, " : d+     5 vm ;\n");
	embed_eval(h, " : d-     6 vm ;\n");
	embed_eval(h, " : d.     7 vm ;\n");

	o.callback = callback;
	int r = embed_vm(h, &o);
	embed_free(h);
	return r;
}

