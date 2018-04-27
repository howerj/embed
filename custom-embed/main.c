#include "embed.h"
#include <string.h>

static const char *e1 = " 1 2 + . cr\n ";
static const char *e2 = " .( Hello, World! ) cr\n ";
static const char *e3 = " $20 2 + \n ";
static const char *e4 = " 2 - . \n ";

#define OBUF_SZ (1024u)

static int evaluator(forth_t *h, const char *s)
{
	char obuf[OBUF_SZ] = { 0 };
	int r = embed_eval(h, s, strlen(s), obuf, OBUF_SZ);
	fputs(obuf, stdout);
	return r;
}

int main(void)
{
	forth_t *h = embed_new();
	int r = 0;
	h = embed_new();
	embed_load(h, "eforth.blk");

	evaluator(h, e1);
	evaluator(h, e2);
	evaluator(h, e3);
	evaluator(h, e4);

	embed_free(h);
	return r;
}
