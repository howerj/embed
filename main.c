#include "embed.h"

static int load_default_or_file(embed_t *h, char *file)
{
	if(!file)
		return embed_load_buffer(h, embed_default_block, embed_default_block_size);
	return embed_load(h, file);
}

int main(int argc, char **argv)
{
	embed_t *h = embed_new();
	if(argc > 4)
		embed_die("usage: %s [out.blk] [in.blk] [file.fth]", argv[0]);
	if(load_default_or_file(h, argc < 3 ? NULL : argv[2]) < 0)
		embed_die("embed: load failed");
	FILE *in = argc <= 3 ? stdin : embed_fopen_or_die(argv[3], "rb");
	if(embed_forth(h, in, stdout, argc < 2 ? NULL : argv[1]))
		embed_die("embed: run failed");
	return 0; /* exiting takes care of closing files, freeing memory */
}

