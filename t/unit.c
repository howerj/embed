#include "embed.h"
#include "unit.h"

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
	unit_test(embed_pop(h, &v) == 0); /* key + quit */
	unit_test(embed_pop(h, &v) == 0); /* key + quit */
	unit_test(embed_pop(h, &v) == 0); /* key + quit */
	unit_test(embed_pop(h, &v) == 0); /* result */
	unit_test(v == 4);

	embed_free(h);

	unit_test_finish();
}

int main(void) {
	test_embed_eval();
	return 0;
}

