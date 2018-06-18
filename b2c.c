#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include "embed.h"

#define N (20u)

static int header(FILE *out, const char *var)
{
	const char *fmt  ="\
#include <stdint.h>\n\
#include <stddef.h>\n\
\n\
const uint8_t %s[] = {\n";
	return fprintf(out, fmt, var);
}

static int line(FILE *out, const uint8_t *b, size_t n)
{
	int r = 0;
	//r += fputc('\t', out);
	for(size_t i = 0; i < n; i++)
		r += fprintf(out, "%u,", b[i]); // r += fprintf(out, "%3u, ", b[i]);
	r += fputc('\n', out);
	return r;
}

static int tail(FILE *out, size_t total, const char *var)
{
	const char *fmt = "};\n\n\
const size_t %s_size = %zu;\n\n";
	return fprintf(out, fmt, var, total);
}

/* Add options for name, size, header output, hexdump like output, ...*/
int main(int argc, char **argv) {
	if(argc != 4)
		embed_die("usage: %s var image.bin image.c", argv[0]);
	const char *var = argv[1];
	FILE *in  = embed_fopen_or_die(argv[2], "rb"), 
	     *out = embed_fopen_or_die(argv[3], "wb");
	size_t i = 0;
	uint8_t b[N] = { 0 };
	header(out, var);
	for(size_t r = 0; (r = fread(b, 1, N, in)); memset(b, 0, sizeof b)) {
		line(out, b, r);
		i += r;
	}
	tail(out, i, var);
	return 0;
}

