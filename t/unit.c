#include "embed.h"
#include "util.h"
#include "unit.h"
#include <stdio.h>
#undef NDEBUG
#include <assert.h>

static void test_embed_swap(void) {
	unit_test_start();

	uint16_t v = 0;
	unit_test_statement(v = 0x1234);
	unit_test(embed_swap(v) == 0x3412);

	unit_test_finish();
}

static void test_embed_stack(void) {
	unit_test_start();
	embed_t *h = NULL;
	unit_test_verify((h = embed_new()) != NULL);

	cell_t v = 0;
	unit_test(embed_depth(h)   == 0);
	unit_test(embed_push(h, 5) == 0);
	unit_test(embed_depth(h)   == 1);
	unit_test(embed_push(h, 6) == 0);
	unit_test(embed_depth(h)   == 2);
	unit_test(embed_pop(h, &v) == 0);
	unit_test(v == 6);
	unit_test(embed_pop(h, &v) == 0);
	unit_test(v == 5);
	unit_test(embed_pop(h, NULL) != 0);
	unit_test(embed_depth(h)   == 0);
	unit_test(embed_pop(h, &v) != 0);
	unit_test(embed_depth(h)   == 0);
	unit_test(embed_push(h, 7) == 0);
	unit_test(embed_pop(h, &v) == 0);
	unit_test(v == 7);

	unit_test_statement(embed_free(h));
	unit_test_finish();
}

static void test_embed_eval(void) {
	unit_test_start();
	embed_t *h = NULL;
	unit_test_verify((h = embed_new()) != NULL);

	unit_test(embed_eval(h, "2 2 + \n") == 0);
	cell_t v = 0;
	unit_test(embed_pop(h, &v) == 0); /* result */
	unit_test(v == 4);

	unit_test_statement(embed_free(h));

	unit_test_finish();
}

static void test_embed_reset(void) {
	unit_test_start();
	embed_t *h = NULL;
	unit_test_verify((h = embed_new()) != NULL);

	unit_test(embed_depth(h)   == 0);
	unit_test(embed_push(h, 1) == 0);
	unit_test(embed_push(h, 1) == 0);
	unit_test(embed_depth(h)   == 2);
	unit_test_statement(embed_reset(h));
	unit_test(embed_depth(h)   == 0);

	unit_test_statement(embed_free(h));
	unit_test_finish();
}

typedef struct {
	int result;
} test_callback_t;

static int test_callback(embed_t *h, void *param) {
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
	embed_t *h = NULL;
	unit_test_verify((h = embed_new()) != NULL);

	test_callback_t parameter = { .result = 0 };

	embed_opt_t o = *embed_opt_get(h);
	unit_test_statement(o.callback = test_callback);
	unit_test_statement(o.param    = &parameter);
	unit_test_statement(embed_opt_set(h, &o));
	unit_test(embed_eval(h, "only forth definitions system +order\n") == 0);
	unit_test(embed_eval(h, " 3 4 vm \n") == 0);
	unit_test(parameter.result == 7);
	unit_test(embed_depth(h) == 0);

	unit_test(embed_eval(h, " 5 3 vm \n") == 0);
	unit_test(parameter.result == 8);
	unit_test(embed_depth(h) == 0); 

	unit_test_statement(embed_free(h));
	unit_test_finish();
}

static int test_yield(void *param) {
	(void)param;
	static unsigned i = 0;
	return i++ > 1000; //406701;
}

static void test_embed_yields(void) {
	unit_test_start();
	embed_t *h = NULL;
	unit_test_verify((h = embed_new()) != NULL);

	embed_opt_t o = *embed_opt_get(h);
	unit_test_statement(o.yield = test_yield);
	unit_test_statement(embed_opt_set(h, &o));

	unit_test(embed_vm(h) == 0);

	unit_test_statement(embed_free(h));
	unit_test_finish();
}

static void test_embed_file(void) {
	unit_test_start();
	embed_t *h = NULL;
	unit_test_verify((h = embed_new()) != NULL);

	FILE *in = NULL;
	const char test_program[] = "$CAFE $1040 -\n";

	unit_test_verify((in = tmpfile()) != NULL);
	unit_test_verify(fwrite(test_program, 1, sizeof(test_program), in) == sizeof(test_program));
	unit_test_verify(fflush(in) == 0);
	unit_test_verify(fseek(in, 0L, SEEK_SET) != -1);

	unit_test(embed_forth_opt(h, EMBED_VM_QUITE_ON, in, stdout, NULL) == 0);
	cell_t v = 0;
	unit_test(embed_pop(h, &v) == 0);
	unit_test(v == 0xBABE);

	unit_test(fclose(in) == 0);

	unit_test_statement(embed_free(h));
	unit_test_finish();
}

int main(void) {
	unit_color_on = 1;
	test_embed_swap();
	test_embed_stack();
	test_embed_reset();
	test_embed_eval();
	test_embed_callbacks();
	test_embed_yields();
	test_embed_file();
	return 0;
}

