#ifndef EMBED_CPP_H

#include "embed.h"
#include "util.h" /**@todo rename 'util.h' to something more unique */
#include <assert.h>
#include <exception>
#include <string>
#include <string.h>

class Embed {
	private:
		cell_t m[EMBED_CORE_SIZE];
		embed_t h;
		bool ran_once;
		void fthrow(int r) { if (r != 0) throw r; }
	public:
		Embed() {
			memset(m, 0, EMBED_CORE_SIZE);
			h.m = m;
			fthrow(embed_default_hosted(&h));
		}

		~Embed() {
		}

		void save(const char *file) { assert(file); fthrow(embed_save(&h, file)); }
		void save(uint8_t *buf, size_t length) {
			assert(buf);
			const embed_mmu_read_t  mr = h.o.read;
			const size_t elength = embed_cells(&h);
			if((length * 2) < embed_cells(&h))
				throw -69;
			for(size_t i = 0; i < elength; i++) {
				buf[(i*2) + 0] = mr(&h, i) >> 0;
				buf[(i*2) + 1] = mr(&h, i) >> 8;
			}
		}
		void load(const char *file) { assert(file); fthrow(embed_load(&h, file)); }
		void load(const std::string *file) { assert(file); fthrow(embed_load(&h, file->c_str())); }
		void load(const std::string  file) {               fthrow(embed_load(&h, file.c_str())); }
		void load(const uint8_t *buf, size_t length) { assert(buf); fthrow(embed_load_buffer(&h, buf, length)); }
		int eval(const char *str) { assert(str); return embed_eval(&h, str); }
		int eval(const std::string *str) { assert(str); return embed_eval(&h, str->c_str()); }
		int eval(const std::string  str) {              return embed_eval(&h, str.c_str()); }
		size_t depth()      { return embed_depth(&h); }
		void push(cell_t v) { if (!ran_once) throw -1; fthrow(embed_push(&h, v)); }
		cell_t pop()        { if (!ran_once) throw -1; cell_t rv = 0; fthrow(embed_pop(&h, &rv)); return rv; }
		int run()           { ran_once = true; return embed_vm(&h); }
		void reset()        { embed_reset(&h); }
};

#endif
