#include "embed.h"
#include "unit.h"
#include <assert.h>

static void test_embed_eval(void) {
	unit_test_start();

	embed_t *h = embed_new();
	unit_test_verify(h != NULL);

	uint16_t v = 0;
	unit_test(embed_depth(h)   == 0);
	unit_test(embed_push(h, 5) == 0);
	unit_test(embed_depth(h)   == 1);
	unit_test(embed_push(h, 6) == 0);
	unit_test(embed_depth(h)   == 2);
	unit_test(embed_pop(h, &v) == 0);
	unit_test(v == 6);
	unit_test(embed_pop(h, &v) == 0);
	unit_test(v == 5);
	unit_test(embed_pop(h, &v) != 0);
	unit_test(embed_depth(h)   == 0);
	unit_test(embed_pop(h, &v) != 0);
	unit_test(embed_depth(h)   == 0);
	unit_test(embed_push(h, 7) == 0);
	unit_test(embed_pop(h, &v) == 0);
	unit_test(v == 7);

	unit_test(embed_eval(h, "2 2 + \n") == 0);
	/* @todo Fix this so there's not loads of junk on the stack */
	unit_test(embed_pop(h, &v) == 0); /* yield */
	unit_test(embed_pop(h, &v) == 0); /* yield */
	unit_test(embed_pop(h, &v) == 0); /* result */
	unit_test(v == 4);

	embed_free(h);
	unit_test_finish();
}

typedef struct {
	int result;
} test_callback_t;

static int test_callback(embed_t *h, void *param)
{
	assert(h && param);
	test_callback_t *result = (test_callback_t*)param;
	cell_t r1 = 0;
	cell_t r2 = 0;
	if(embed_depth(h) < 2)
		return -1;
	embed_pop(h, &r1);
	embed_pop(h, &r2);
	result->result = r1 + r2;
	return 0;
}

static void test_embed_callbacks(void) {
	unit_test_start();

	test_callback_t parameter = { .result = 0 };
	embed_t *h = embed_new();
	unit_test_verify(h != NULL);
	embed_opt_t o = embed_opt_get(h);
	o.callback = test_callback;
	o.param    = &parameter;
	embed_opt_set(h, o);

	unit_test(embed_eval(h, " 3 4 vm \n") == 0);
	unit_test(parameter.result == 7);
	unit_test(embed_depth(h) == 2); /* @bug should be zero, but yield parameters still on stack */

	unit_test(embed_eval(h, " 5 3 vm \n") == 0);
	unit_test(parameter.result == 8);
	unit_test(embed_depth(h) == 2); /* @bug should be zero, but yield parameters still on stack */

	embed_free(h);
	unit_test_finish();
}

int main(void) {
	test_embed_eval();
	test_embed_callbacks();
	return 0;
}

