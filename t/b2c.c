#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <errno.h>
#include <stdlib.h>
#include <assert.h>

#define N (20)

static FILE *fopen_or_die(const char * const file, const char * const mode)
{
	assert(file && mode);
	errno = 0;
	FILE *r = fopen(file, mode);
	if(!r) {
		fprintf(stderr, "unable to open file '%s' (mode = %s): %s\n", file, mode, strerror(errno));
		exit(EXIT_FAILURE);
	}
	return r;
}

static int header(FILE *out, const char *var, const char *msg)
{
	const char *fmt  ="\
/* %s */\n\
#include <stdint.h>\n\
#include <stddef.h>\n\
\n\
const uint8_t %s[] = {\n";
	return fprintf(out, fmt, msg, var);
}

static int line(FILE *out, const uint8_t *b, size_t n, size_t rrr)
{
	int r = rrr;
	for(size_t i = 0; i < n; i++) {
		r += fprintf(out, "%u,", b[i]);
		if(r >= ((N*4)-4)) {
			fputc('\n', out);
			r = 0;
		}
	}
	return r;
}

static int tail(FILE *out, size_t total, const char *var)
{
	const char *fmt = "\n};\n\n\
const size_t %s_size = %zu;\n\n";
	return fprintf(out, fmt, var, total);
}

int main(int argc, char **argv) {
	if(argc != 5) {
		fprintf(stderr, "usage: %s variable-name image.bin image.c \"comment\"\n", argv[0]);
		return -1;
	}
	const char *var = argv[1];
	FILE *in  = fopen_or_die(argv[2], "rb"), 
	     *out = fopen_or_die(argv[3], "wb");
	const char *msg = argv[4];
	size_t i = 0;
	uint8_t b[N] = { 0 };
	int rrr = 0;
	header(out, var, msg);
	for(size_t r = 0; (r = fread(b, 1, N, in)); memset(b, 0, sizeof b)) {
		rrr = line(out, b, r, rrr);
		i += r;
	}
	tail(out, i, var);
	return 0;
}

