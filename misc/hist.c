/*
 * xxd -g 1 file | awk '{for(i=2;i<18;i++) {print $i}}' | sort | uniq -c
 *
 * "uniq -c" replacement:
 * awk '{ips[$1]++} END {for (ip in ips) { print ips[ip], ip}}'
 *
 * @todo Look at generating huffman codes from the table
 * See: https://www.siggraph.org/education/materials/HyperGraph/video/mpeg/mpegfaq/huffman_tutorial.html
 * And printing out the tree. The idea is to take the two least common nodes, and create
 * a new one with a combined count of the two nodes until no more nodes to combine remain.
 * Perhaps a priority queue could be used to store the nodes
 */

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <assert.h>

#define UNUSED(VARIABLE) ((void)(VARIABLE))
#define NBINS            (256u)
#define WIDTH            (72ul)

#ifdef _WIN32
#include <windows.h>
#include <io.h>
#include <fcntl.h>
extern int _fileno(FILE *);
static void binary(FILE *f) { _setmode(_fileno(f), _O_BINARY); }
#else
static void binary(FILE *f) { UNUSED(f); }
#endif

typedef struct {
	uint8_t bin;
	unsigned long count;
} histogram_t;

static inline void swap(histogram_t *a, histogram_t *b)
{
	assert(a);
	assert(b);
	const histogram_t t = *a;
	*a = *b;
	*b = t;
}

static void sort(histogram_t *array, const size_t size){ /* gnome sort */
	assert(array);
	for(size_t i = 1; i < size; ) {
		if(array[i-1].count <= array[i].count) {
			++i;
		} else {
			swap(&array[i], &array[i - 1]);
			--i;
			if(i == 0)
				i = 1;
		}
	}
}

static void reverse(histogram_t *array, const size_t size)
{
	assert(array);
	for(size_t i = 0; i < size/2; i++)
		swap(&array[size - (1 + i)], &array[i]);
}

static int banner(FILE *f, const char c, const unsigned count)
{
	assert(f);
	unsigned i = count;
	while(i--)
		if(fputc(c, f) != c)
			return -1;
	return (int)count;
}

/**@todo allow for configurable number of bins (256 or 65536) */
int main(void)
{
	static histogram_t h[NBINS];
	int c, max;
	FILE *o;
	binary(stdin);
	o = stdout;
	memset(h, 0, sizeof(h[0])*NBINS);

	for(size_t i = 0; i < NBINS; i++)
		h[i].bin = i;

	while((c = fgetc(stdin)) != EOF)
		h[(uint8_t)c].count++;

	sort(h, NBINS);
	reverse(h, NBINS);

	max = h[0].count > h[NBINS - 1].count ? h[0].count : h[NBINS - 1].count;
	max = max ? max : 1;

	for(size_t i = 0; i < NBINS; i++) 
		if(h[i].count) {
			fprintf(o, "%lu\t%lu\t", (unsigned long)h[i].bin, h[i].count);
			banner(o, '*', (h[i].count * WIDTH) / max);
			fputc('\n', o);
		}
	return 0;
}

