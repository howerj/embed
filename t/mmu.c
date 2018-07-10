#include "util.h"
#include "embed.h"
#include <stdint.h>
#include <inttypes.h>
#include <limits.h>
#include <assert.h>
#include <stdlib.h>
#include <stdbool.h>
#include <string.h>

typedef unsigned bitmap_unit;
#define BITS (sizeof(bitmap_unit)*CHAR_BIT)
#define MASK (BITS-1)

typedef struct {
	size_t bits;
	bitmap_unit map[];
} bitmap_t;

/**@todo assert bit index in range */

size_t bitmap_units(size_t bits) {
	return bits/BITS + !!(bits & MASK);
}

size_t bitmap_sizeof(bitmap_t *b) {
	assert(b);
	return sizeof(*b) + bitmap_units(b->bits)*sizeof(bitmap_unit);
}

bitmap_t *bitmap_new(size_t bits) {
	size_t length = bitmap_units(bits)*sizeof(bitmap_unit);
	/**@todo detect overflow */
	bitmap_t *r = calloc(sizeof(bitmap_t) + length, 1);
	if(!r)
		return NULL;
	r->bits = bits;
	return r;
}

bitmap_t *bitmap_copy(bitmap_t *b) {
	assert(b);
	bitmap_t *r = bitmap_new(b->bits);
	if(!r)
		return NULL;
	return memcpy(r, b, bitmap_sizeof(b));
}

void bitmap_free(bitmap_t *b) {
	free(b);
}

void bitmap_set(bitmap_t *b, size_t bit) {
	assert(b);
	b->map[bit/BITS] |=  (1u << (bit & MASK));
}

void bitmap_clear(bitmap_t *b, size_t bit) {
	assert(b);
	b->map[bit/BITS] &= ~(1u << (bit & MASK));
}

void bitmap_toggle(bitmap_t *b, size_t bit) {
	assert(b);
	b->map[bit/BITS] ^=  (1u << (bit & MASK));
}

bool bitmap_get(bitmap_t *b, size_t bit) {
	assert(b);
	return !!(b->map[bit/BITS] & (1u << (bit & MASK)));
}

typedef int (*bitmap_foreach_callback_t)(bitmap_t *b, size_t bit, void *param);


int bitmap_foreach(bitmap_t *b, bitmap_foreach_callback_t cb, void *param)
{
	const size_t bits = b->bits;
	int r = 0;
	for(size_t i = 0; i < bits; i++)
		if((r = cb(b, i, param)) < 0)
			return r;
	return 0;
}


static bitmap_t *read_map  = NULL;
static bitmap_t *write_map = NULL;

static cell_t  mmu_read_cb(cell_t const * const m, cell_t addr) {
	bitmap_set(read_map, addr);
	return m[addr];
}

static void mmu_write_cb(cell_t * const m, cell_t addr, cell_t value) {
	bitmap_set(write_map, addr);
	m[addr] = value;
}

static int bitmap_print(bitmap_t *b, size_t bit, void *param)
{
	FILE *out = (FILE*)param;
	if(bitmap_get(b, bit))
		return fprintf(out, "%zu\n", bit) > 0;
	return 0;
}

int main(void) {
	read_map  = bitmap_new(UINT16_MAX);
	write_map = bitmap_new(UINT16_MAX);
	if(!read_map || !write_map)
		embed_fatal("bitmap: allocate failed");

	embed_opt_t o = embed_opt_default();
	o.read  = mmu_read_cb;
	o.write = mmu_write_cb;

	embed_t *h = embed_new();
	embed_opt_set(h, o);
	if(!h)
		embed_fatal("embed: allocate failed");
	const int r = embed_vm(h);
	embed_free(h);
	bitmap_foreach(write_map, bitmap_print, stdout);
	bitmap_free(read_map);
	bitmap_free(write_map);
	return r;
}

