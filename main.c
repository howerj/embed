/** @file      main.c
 *  @brief     Embed Forth Virtual Machine Driver
 *  @copyright Richard James Howe (2017,2018)
 *  @license   MIT */
#include "embed.h"
#include <assert.h>
#include <string.h>

#ifdef _WIN32 /* Making standard input streams on Windows binary mode */
#include <windows.h>
#include <io.h>
#include <fcntl.h>
extern int _fileno(FILE *);
static void binary(FILE *f) { assert(f); _setmode(_fileno(f), _O_BINARY); }
#else
#define UNUSED(VARIABLE) ((void)(VARIABLE))
static inline void binary(FILE *f) { assert(f); UNUSED(f); }
#endif

static void usage(const char *arg_0)
{
	assert(arg_0);
	embed_die("usage: %s f|i input.blk output.blk file.fth", arg_0);
}

int main(int argc, char **argv)
{
	forth_t *h;
	int interactive = 0, r = 0;
	binary(stdin); 
	binary(stdout);
	binary(stderr);
	h = embed_new();
	if(argc < 4)
		usage(argv[0]);
	if(!strcmp(argv[1], "i"))
		interactive = 1;
	else if(strcmp(argv[1], "f"))
		usage(argv[0]);
	embed_load(h, argv[2]);
	for(int i = 4; i < argc; i++) {
		FILE *in = embed_fopen_or_die(argv[i], "rb");
		r = embed_forth(h, in, stdout, argv[3]);
		fclose(in);
		if(r != 0) {
			fprintf(stderr, "run failed: %d\n", r);
			goto failed;
		}
	}
	if(interactive)
		r = embed_forth(h, stdin, stdout, argv[3]);
failed:
	embed_free(h);
	return r;
}
