#include "embed.h"
#include "util.h"
#include <assert.h>
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

static int load_default_or_file(embed_t *h, const char *file) {
	assert(h);
	if (!file)
		return embed_load_buffer(h, embed_default_block, embed_default_block_size);
	return embed_load(h, file);
}

static int run(embed_t *h, embed_vm_option_e opt, bool load, FILE *in, FILE *out, const char *iblk, const char *oblk) {
	assert(h);
	if (load)
		if (load_default_or_file(h, iblk) < 0)
			embed_fatal("embed: load failed (input = %s)", iblk ? iblk : "(null)");
	embed_reset(h); /* reset virtual machine in between calls to it, this might be undesired behavior */
	return embed_forth_opt(h, opt, in, out, oblk);
}

static int run_file(embed_t *h, embed_vm_option_e opt, bool load, char *in_file, FILE *out, const char *iblk, const char *oblk) {
	FILE *in = embed_fopen_or_die(in_file, "rb");
	const int r = run(h, opt, load, in, out, iblk, oblk);
	fclose(in);
	return r;
}

static const char *help ="\
usage: ./embed [-hqtTa-] -i in.blk -o out.blk file.fth...\n\n\
Program: Embed Virtual Machine and eForth Image\n\
Author:  Richard James Howe\n\
License: MIT\n\
Site:    https://github.com/howerj/embed\n\n\
Options:\n\
\t-i in.blk   load virtual machine image from 'in.blk'\n\
\t-o out.blk  set save location to 'out.blk'\n\
\t-h          display this help message and die\n\
\t-q          quite mode on\n\
\t-t          turn tracing on\n\
\t-I file.fth set input file\n\
\t-O file.txt set output file\n\
\t-T          run built in self tests\n\
\t-a          read from stdin/file specified by '-I' after files\n\
\t--          stop processing command arguments\n\
\tfile.fth    read from 'file.fth'\n\n\
If no input Forth file is given standard input is read from. If no input\n\
block is given a built in block containing an eForth interpreter is\n\
used.\n\n\
";

int main(int argc, char **argv) {
	embed_getopt_t go = { .init = 0, .error = 1 };
	embed_vm_option_e option = 0;
	const char *oblk = NULL, *iblk = NULL;
	FILE *in = stdin, *out = stdout;
	bool ran = false, terminal = false;
	int r = 0, ch;
	binary(stdin);
	binary(stdout);
	binary(stderr);

	static cell_t m[EMBED_CORE_SIZE] = { 0 };
	static embed_t h = { .m = m };
	if (embed_default_hosted(&h) < 0)
		embed_fatal("embed: load failed\n");

	while ((ch = embed_getopt(&go, argc, argv, "hqtTi:o:I:O:a")) != -1) {
		switch (ch) {
		case 'h': fputs(help, stdout); return 0;
		case 'i': iblk = go.arg; break;
		case 'o': oblk = go.arg; break;
		case 'q': option |= EMBED_VM_QUITE_ON; break;
		case 't': option |= EMBED_VM_TRACE_ON; break;
		case 'O': if (out != stdout) { fclose(out); } out = embed_fopen_or_die(go.arg, "wb"); break;
		case 'I': if (in  != stdin)  { fclose(in); }  in  = embed_fopen_or_die(go.arg, "rb"); break;
		case 'T': return embed_tests();
		case 'a': terminal = true; break;
		default: fputs(help, stdout); return 1;
		}
	}

	for (int i = go.index; i < argc; i++) {
		if ((r = run_file(&h, option | EMBED_VM_QUITE_ON, !ran, argv[i], out, iblk, oblk)) < 0)
			break;
		ran = true;
	}

	if (go.index == argc || terminal)
		r = run(&h, option, !ran, in, out, iblk, oblk);
	fclose(in);
	fclose(out);
	return r;
}

