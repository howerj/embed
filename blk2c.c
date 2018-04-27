#include <stdio.h>
#include <string.h>
#include <errno.h>

const unsigned width = 8;

int main(int argc, char **argv)
{
	FILE *in = stdin;
	FILE *out = stdout;

	if(argc > 2) {
		fprintf(stderr, "usage: %s file.blk", argv[0]);
		return -1;
	}

	if(argc == 2) {
		errno = 0;
		if(!(in = fopen(argv[1], "rb"))) {
			fprintf(stderr, "unable to open '%s' for reading: %s\n", argv[1], strerror(errno));
			return -1;
		}
	}

	fputs("#include \"embed.h\"\n#include <stdint.h>\n\n", out);
	fputs("uw_t block[] = {\n", out);

	unsigned i = 0;
	while(1) {
		const int a = fgetc(in);
		const int b = fgetc(in);

		if(a == EOF || b == EOF)
			break;

		if(!(i % width) && i)
			fputc('\n', out);
		if(!(i % width))
			fputc('\t', out);

		fprintf(out, "0x%04x, ", ((unsigned)a | (unsigned)b << 8));

		i++;
	}

	fputs("\n};\n\n", out);

	fclose(in);
	fclose(out);
	return 0;
}
