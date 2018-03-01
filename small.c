#include "embed.h"

int main(void)
{
	forth_t *f = embed_new();
	embed_load(f, "eforth.blk");
	return embed_forth(f, stdin, stdout, NULL);
}
