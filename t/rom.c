/**@brief Embed library ROM test program
 * @license MIT
 * @author Richard James Howe
 * @file mmu.c
 *
 * See <https://github.com/howerj/embed> for more information.
 */

#include "embed.h"
#include "util.h"
#include <assert.h>
#include <stdlib.h>
#include <stdbool.h>

#define PAGE_SIZE (128u)
#define NPAGES    (5u)

typedef struct {
	cell_t m[NPAGES][PAGE_SIZE];
} pages_t;

static pages_t pages = { 0 };

static const uint16_t page_0 = 0x0000;
/*static const uint16_t page_1 = PAGE_SIZE ;*/
static const uint16_t page_2 = 0x2000;
static const uint16_t page_3 = 0x2400;
static const uint16_t page_4 = (EMBED_CORE_SIZE - PAGE_SIZE);

static inline bool within(cell_t range, cell_t addr) {
	return (addr >= range) && (addr < (range + PAGE_SIZE));
}

static cell_t  rom_read_cb(embed_t const * const h, cell_t addr) {
	assert(h);
	assert(!(0x8000 & addr));
	pages_t *p = (pages_t*)h->m;
	const uint16_t blksz = embed_default_block_size >> 1;

	if(within(page_0, addr)) {
		return p->m[0][addr];
	} else if((addr >= PAGE_SIZE) && (addr < blksz)) {
		const uint16_t naddr = addr << 1;
		const uint16_t lo    = embed_default_block[naddr+0];
		const uint16_t hi    = embed_default_block[naddr+1];
		return (hi<<8u) | lo;
	} else if(within(blksz, addr)) {
		return p->m[1][addr - blksz];
	} else if(within(page_2, addr)) {
		return p->m[2][addr - page_2];
	} else if(within(page_3, addr)) {
		return p->m[3][addr - page_3];
	} else if(within(page_4, addr)) {
		return p->m[4][addr - page_4];
	}
	return 0;
}

static void rom_write_cb(embed_t * const h, cell_t addr, cell_t value) {
	assert(h);
	assert(!(0x8000 & addr));
	pages_t * const p = (pages_t*)h->m;

	const uint16_t blksz = embed_default_block_size >> 1;

	if(within(page_0, addr)) {
		p->m[0][addr] = value;
		return;
	} else if((addr >= PAGE_SIZE) && (addr < blksz)) {
		/* ROM */
	} else if(within(blksz, addr)) {
		p->m[1][addr - blksz]   = value;
		return;
	} else if(within(page_2, addr)) {
		p->m[2][addr - page_2] = value;
		return;
	} else if(within(page_3, addr)) {
		p->m[3][addr - page_3] = value;
		return;
	} else if(within(page_4, addr)) {
		p->m[4][addr - page_4] = value;
		return;
	}
}

int main(void) {
	static embed_t h;
	h.m = &pages;
	embed_opt_t o = embed_opt_default_hosted();
	o.read  = rom_read_cb;
	o.write = rom_write_cb;

	for(size_t i = 0; i < (PAGE_SIZE*2); i+=2) {
		const uint16_t lo = embed_default_block[i+0];
		const uint16_t hi = embed_default_block[i+1];
		pages.m[0][i >> 1] = (hi<<8u) | lo;
	}

	embed_opt_set(&h, &o);

	const int r = embed_vm(&h);

	return r;
}

