/* Embed forth main driver - Richard James Howe */
#include "embed.h"
#include <string.h>

static const char *usage = "usage: forth f|i input.blk output.blk file.fth";

int main(int argc, char **argv)
{
	forth_t *h = embed_new();
	int interactive = 0, r = 0;
	if(argc < 4)
		embed_die(usage);
	interactive = !strcmp(argv[1], "-i");
	if(!interactive && strcmp(argv[1], "-f"))
		embed_die(usage);
	embed_load(h, argv[2]);
	for(int i = 4; i < argc; i++) {
		FILE *in = embed_fopen_or_die(argv[i], "rb");
		if((r = embed_forth(h, in, stdout, argv[3])))
			embed_die("run failed: %d\n", r);
		fclose(in);
	}
	if(interactive)
		r = embed_forth(h, stdin, stdout, argv[3]);
	return r != 0 ? -1 : 0;
}
