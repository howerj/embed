/**@brief Convert a binary file into a C data structure
 * @file b2c.c
 * @author Richard James Howe
 * @license MIT
 *
 * This is a simple utility to convert a file into a C data structure, it tries
 * to pack the structure as densely as possible by using decimal (hexadecimal
 * requires a '0x' for each character) and by placing as many bytes on a 80
 * character line as is possible.
 */

#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <errno.h>
#include <stdlib.h>
#include <assert.h>

#define N (20) /**< column with is N*4 */

static FILE *fopen_or_die(const char * const file, const char * const mode) {
	assert(file && mode);
	errno = 0;
	FILE *r = fopen(file, mode);
	if(!r) {
		fprintf(stderr, "unable to open file '%s' (mode = %s): %s\n", file, mode, strerror(errno));
		exit(EXIT_FAILURE);
	}
	return r;
}

static int header(FILE *out, const char *var, const char *msg) {
	const char *fmt  ="\
/* %s */\n\
#include <stdint.h>\n\
#include <stddef.h>\n\
\n\
const uint8_t %s[] = {\n";
	return fprintf(out, fmt, msg, var);
}

static int line(FILE *out, const uint8_t *b, size_t n, size_t rrr) {
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

static int tail(FILE *out, size_t total, const char *var) {
	const char *fmt = "\n};\n\n\
const size_t %s_size = %zu;\n\n";
	return fprintf(out, fmt, var, total);
}

static void help(FILE *output, const char *arg0)
{
	static const char usage[] = "\
usage: %s variable-name image.bin image.c \"comment\"\n\n\
b2c - convert a binary to a C data structure\n\n\
All four options must be given to the program, they are:\n\n\
\t* variable-name  C variable name for the byte array to be generated. Two\n\
\t                 variables will be generated, the array with the name \n\
\t                 specified and a variable with the name specified and a\n\
\t                 postfix of '_size' containing the arrays size.\n\
\t* image.bin      Any file, does not have to be binary, this file will\n\
\t                 be converted into the byte array.\n\
\t* image.c        The C file to generate.\n\
\t* \"comment\"    This string will be place within a comment in the\n\
\t                 file generated\n\n\
LICENSE:   MIT\n\
COPYRIGHT: Richard James Howe (2018)\n\n";
	fprintf(output, usage, arg0);
}

int main(int argc, char **argv) {
	if(argc != 5) {
		help(stderr, argv[0]);
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

