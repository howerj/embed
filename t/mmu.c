/**@brief Embed library Memory Management Unit (MMU) test program
 * @license MIT
 * @author Richard James Howe
 * @file mmu.c
 *
 * See <https://github.com/howerj/embed> for more information.
 *
 * This test program implements custom MMU read and write functions that log
 * the locations the virtual machine reads and writes to, this can be useful
 * for creating a memory map that would allow sections of memory to be placed
 * into Read Only Memory (ROM) to save on space.  */

#include "util.h"
#include "embed.h"
#include <stdint.h>
#include <inttypes.h>
#include <limits.h>
#include <assert.h>
#include <stdlib.h>
#include <stdbool.h>
#include <string.h>

#define MMU_REPORT ("mmu.log")

/* ================= Bit Map Routines : Start ============================= */

typedef unsigned bitmap_unit_t;
#define BITS (sizeof(bitmap_unit_t)*CHAR_BIT)
#define MASK (BITS-1)

typedef struct {
	size_t bits;
	bitmap_unit_t map[];
} bitmap_t;

size_t bitmap_units(size_t bits) {
	return bits/BITS + !!(bits & MASK);
}

size_t bitmap_bits(bitmap_t *b) {
	assert(b);
	return b->bits;
}

size_t bitmap_sizeof(bitmap_t *b) {
	assert(b);
	return sizeof(*b) + bitmap_units(b->bits)*sizeof(bitmap_unit_t);
}

bitmap_t *bitmap_new(size_t bits) {
	const size_t length = bitmap_units(bits)*sizeof(bitmap_unit_t);
	assert(length < (SIZE_MAX/bits));
	assert((length + sizeof(bitmap_t)) > length);
	bitmap_t *r = calloc(sizeof(bitmap_t) + length, 1);
	if (!r)
		return NULL;
	r->bits = bits;
	return r;
}

bitmap_t *bitmap_copy(bitmap_t *b) {
	assert(b);
	bitmap_t *r = bitmap_new(b->bits);
	if (!r)
		return NULL;
	return memcpy(r, b, bitmap_sizeof(b));
}

void bitmap_free(bitmap_t *b) {
	free(b);
}

void bitmap_set(bitmap_t *b, size_t bit) {
	assert(b);
	assert(bit < b->bits);
	b->map[bit/BITS] |=  (1u << (bit & MASK));
}

void bitmap_clear(bitmap_t *b, size_t bit) {
	assert(b);
	assert(bit < b->bits);
	b->map[bit/BITS] &= ~(1u << (bit & MASK));
}

void bitmap_toggle(bitmap_t *b, size_t bit) {
	assert(b);
	assert(bit < b->bits);
	b->map[bit/BITS] ^=  (1u << (bit & MASK));
}

bool bitmap_get(bitmap_t *b, size_t bit) {
	assert(b);
	assert(bit < b->bits);
	return !!(b->map[bit/BITS] & (1u << (bit & MASK)));
}

/* ================= Bit Map Routines : End =============================== */

static bitmap_t *read_map  = NULL;
static bitmap_t *write_map = NULL;

static cell_t  mmu_read_cb(embed_t const * const h, cell_t addr) {
	assert(!(0x8000 & addr));
	bitmap_set(read_map, addr);
	return ((cell_t*)h->m)[addr];
}

static void mmu_write_cb(embed_t * const h, cell_t addr, cell_t value) {
	assert(!(0x8000 & addr));
	/*if (m[addr] != value)*/
	bitmap_set(write_map, addr);
	((cell_t*)h->m)[addr] = value;
}

#ifndef MIN
#define MIN(X, Y) ((X) > (Y) ? (Y) : (X))
#endif

static bitmap_t *bitmap_union(bitmap_t *a, bitmap_t *b) {
	const size_t al = bitmap_bits(a), bl = bitmap_bits(b);
	bitmap_t *u = (al > bl) ? bitmap_copy(a) : bitmap_copy(b);
	if (!u)
		return NULL;
	bitmap_t *m = (al > bl) ? b : a;
	const size_t ml = MIN(al, bl);
	for (size_t i = 0; i < ml; i++)
		if (bitmap_get(m, i))
			bitmap_set(u, i);
	return u;
}

static void bitmap_print_range(bitmap_t *b, FILE *out) {
	assert(b);
	assert(out);
	size_t total = 0;
	for (size_t i = 0; i < bitmap_bits(b);) {
		size_t start = i, end = i, j = i;
		if (!bitmap_get(b, i)) {
			i++;
			continue;
		}

		for (j = i; j < bitmap_bits(b); j++)
			if (!bitmap_get(b, j))
				break;
		end = bitmap_get(b, j) ? j :
			j > (i+1)      ? j-1 : i;
		if (start == end) {
			total++;
			fprintf(out, "    1\t%zu\n", end);
		} else {
			assert(end >= start);
			const size_t range = (end - start) + 1;
			total += range;
			fprintf(out, "%5zu\t%zu-%zu\n", range, start, end);
		}
		i = j;
	}
	fprintf(out, "total: %zu\n", total);
}

/*static int bitmap_print(bitmap_t *b, size_t bit, void *param)
{
	FILE *out = (FILE*)param;
	if (bitmap_get(b, bit))
		return fprintf(out, "%zu\n", bit) > 0;
	return 0;
}*/

static int bitmap_report(const char *name, bitmap_t *read_map, bitmap_t *write_map) {
	assert(name);
	assert(read_map);
	assert(write_map);
	bitmap_t *u = bitmap_union(read_map, write_map);
	if (!u)
		embed_fatal("report: union allocation failed");
	FILE *report = embed_fopen_or_die(name, "wb");
	fprintf(report, "write:\n");
	bitmap_print_range(write_map, report);
	fprintf(report, "read:\n");
	bitmap_print_range(read_map, report);
	fprintf(report, "rw:\n");
	bitmap_print_range(u, report);
	bitmap_free(u);
	fclose(report);
	return 0;
}

int main(int argc, char **argv) {
	int r = 0;
	read_map  = bitmap_new(UINT16_MAX);
	write_map = bitmap_new(UINT16_MAX);
	if (!read_map || !write_map)
		embed_fatal("bitmap: allocate failed");

	embed_opt_t o = embed_opt_default_hosted();
	o.read  = mmu_read_cb;
	o.write = mmu_write_cb;

	embed_t *h = embed_new();
	if (!h)
		embed_fatal("embed: allocate failed");

	embed_opt_set(h, &o);

	if (argc > 1) {
		o.options |= EMBED_VM_QUITE_ON;
		for (int i = 1; i < argc; i++) {
			FILE *in = embed_fopen_or_die(argv[i], "rb");
			o.in = in;
			embed_opt_set(h, &o);
			r = embed_vm(h);
			fclose(in);
			o.in = stdin;
			embed_opt_set(h, &o);
			if (r < 0)
				return r;
		}
	} else {
		r = embed_vm(h);
	}

	embed_free(h);
	bitmap_report(MMU_REPORT, read_map, write_map);
	bitmap_free(read_map);
	bitmap_free(write_map);
	return r;
}

