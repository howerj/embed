#include "embed.h"
#include "util.h"
#include <stdio.h>
#include <stdbool.h>
#include <string.h>

#ifdef _WIN32 /* Making standard input streams on Windows binary */
#include <windows.h>
#include <io.h>
#include <fcntl.h>
extern int _fileno(FILE *stream);
static void binary(FILE *f) { _setmode(_fileno(f), _O_BINARY); }
#else
static inline void binary(FILE *f) { UNUSED(f); }
#endif

static int load_default_or_file(embed_t *h, char *file)
{
	if(!file)
		return embed_load_buffer(h, embed_default_block, embed_default_block_size);
	return embed_load(h, file);
}

static int run(embed_t *h, embed_vm_option_e opt, bool load, FILE *in, FILE *out, char *iblk, char *oblk)
{
	if(load)
		if(load_default_or_file(h, iblk) < 0)
			embed_fatal("embed: load failed (input = %s)", iblk ? iblk : "(null)");
	embed_reset(h); /* reset virtual machine in between calls to it, this might be undesired behavior */
	return embed_forth_opt(h, opt, in, out, oblk);
}

static int run_file(embed_t *h, embed_vm_option_e opt, bool load, char *in_file, FILE *out, char *iblk, char *oblk)
{
	FILE *in = embed_fopen_or_die(in_file, "rb");
	int r = run(h, opt, load, in, out, iblk, oblk);
	fclose(in);
	return r;
}

static const char *help ="\
usage: ./embed -i in.blk -o out.blk file.fth...\n\n\
Program: Embed Virtual Machine and eForth Image\n\
Author:  Richard James Howe\n\
License: MIT\n\
Site:    https://github.com/howerj/embed\n\n\
Options:\n\
  -i in.blk   load virtual machine image from 'in.blk'\n\
  -o out.blk  set save location to 'out.blk'\n\
  -h          display this help message and die\n\
  -q          quite mode on\n\
  -t          turn tracing on\n\
  file.fth    read from 'file.fth'\n\n\
If no input Forth file is given standard input is read from. If no input\n\
block is given a built in version containing an eForth interpreter is\n\
used.\n\
";

static char *next(int *i, const int argc, char **argv)
{
	const int j = *i;
	if(j + 1 >= argc)
		embed_fatal("%s expects option", argv[j]);
	*i = j + 1;
	return argv[*i];
}

int main(int argc, char **argv)
{
	embed_vm_option_e option = 0;
	char *oblk = NULL, *iblk = NULL;
	FILE *in = stdin, *out = stdout;
	bool ran = false, stop = false;
	int r = 0;
	binary(stdin);
	binary(stdout);
	binary(stderr);

	embed_t *h = embed_new();
	if(!h)
		embed_fatal("embed: new failed");
	for(int i = 1; i < argc; i++) {
		if(stop)
			goto optend;
		if(!strcmp("-i", argv[i])) {
			if(iblk)
				embed_fatal("embed: input block already set");
			iblk = next(&i, argc, argv);
			if(embed_load(h, iblk) < 0)
				embed_fatal("embed: load failed");
		} else if(!strcmp("-o", argv[i])) {
			if(oblk)
				embed_fatal("embed: output block already set");
			oblk = next(&i, argc, argv);
		} else if(!strcmp("-q", argv[i])) { /* quite mode */
			option |= EMBED_VM_QUITE_ON;
		} else if(!strcmp("-t", argv[i])) { /* trace */
			option |= EMBED_VM_TRACE_ON;
		} else if(!strcmp("-h", argv[i])) {
			embed_fatal("%s", help);
		} else if(!strcmp("--", argv[i])) {
			stop = true;
		} else {
optend:
			r = run_file(h, option | EMBED_VM_QUITE_ON, !ran, argv[i], out, iblk, oblk);
			ran = true;
			if(r < 0)
				goto end;
		}
	}
	if(!ran)
		r = run(h, option, !ran, in, out, iblk, oblk);
end:
	embed_free(h);
	return r;
}

