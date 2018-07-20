#include "util.h"
#include <stdio.h>
#include <assert.h>
#include <stdint.h>
#include <stdlib.h>
#include <errno.h>
#include <string.h>
#include <stdarg.h>

static embed_log_level_e global_log_level = EMBED_LOG_LEVEL_INFO; /**< Global log level */

void embed_log_level_set(embed_log_level_e level) { global_log_level = level; }
embed_log_level_e embed_log_level_get(void)       { return global_log_level; }
void embed_die(void)                              { exit(EXIT_FAILURE); }
void *embed_alloc(size_t sz)                      { return calloc(sz, 1); }

/*NB. Logging and other helper functions probably do not belong in this library */
static void _embed_logger(embed_log_level_e level, const char *file, const char *func, unsigned line, const char *fmt, va_list arg) {
	assert(file && func && fmt && level < EMBED_LOG_LEVEL_ALL_ON);
	if(level > embed_log_level_get())
		goto end;
	static const char *str[] = {
		[EMBED_LOG_LEVEL_ALL_OFF]  =  "all-off",
		[EMBED_LOG_LEVEL_FATAL]    =  "fatal",
		[EMBED_LOG_LEVEL_ERROR]    =  "error",
		[EMBED_LOG_LEVEL_WARNING]  =  "warning",
		[EMBED_LOG_LEVEL_INFO]     =  "info",
		[EMBED_LOG_LEVEL_DEBUG]    =  "debug",
		[EMBED_LOG_LEVEL_ALL_ON]   =  "all-on",
	};
	fprintf(stderr, "(%s:%s:%s:%u)\t", str[level], file, func, line);
	vfprintf(stderr, fmt, arg);
	fputc('\n', stderr);
end:
	if(level == EMBED_LOG_LEVEL_FATAL)
		embed_die();
}

void embed_logger(embed_log_level_e level, const char *file, const char *func, unsigned line, const char *fmt, ...) {
	va_list arg;
	va_start(arg, fmt);
	_embed_logger(level, file, func, line, fmt, arg);
	va_end(arg);
}

FILE *embed_fopen_or_die(const char *file, const char *mode) {
	assert(file && mode);
	FILE *h = NULL;
	errno = 0;
	if(!(h = fopen(file, mode)))
		embed_fatal("file open %s (mode %s) failed: %s", file, mode, strerror(errno));
	return h;
}

void *embed_alloc_or_die(size_t sz) {
	errno = 0;
	void *r = embed_alloc(sz);
		embed_fatal("allocation of size %u bytes failed: %s", (unsigned)sz, strerror(errno));
	return r;
}

embed_t *embed_new(void) { 
	embed_t *h = calloc(sizeof(struct embed_t), 1); 
	if(!h) 
		goto fail;
	h->m = calloc(EMBED_CORE_SIZE*sizeof(cell_t), 1);
	if(!(h->m))
		goto fail;
	if(embed_default_hosted(h) < 0)
		goto fail;
	h->o = embed_opt_default();
	return h; 
fail:
	embed_free(h);
	return NULL;
}

void embed_free(embed_t *h)  { 
	if(!h)
		return;
	memset(h, 0, sizeof(*h)); 
	free(h->m);
	free(h); 
}

int embed_save(const embed_t *h, const char *name) { 
	assert(name); 
	return embed_save_cb(h, name, 0, embed_cells(h)); 
}

int embed_load(embed_t *h, const char *name) { 
	FILE *f = fopen(name, "rb"); 
	if(!f) 
		return -69; 
	int r = embed_load_file(h, f); 
	fclose(f); 
	return r; 
}

int embed_save_cb(const embed_t *h, const void *name, const size_t start, const size_t length) {
	assert(h);
	const embed_mmu_read_t  mr = h->o.read;
	if(!name || !(((length - start) <= length) && ((start + length) <= embed_cells(h))))
		return -69; /* open-file IOR */
	FILE *out = fopen(name, "wb");
	if(!out)
		return -69; /* open-file IOR */
	int r = 0;
	for(size_t i = start; i < length; i++)
		if(fputc(mr(h, i)&255, out) < 0 || fputc(mr(h, i)>>8, out) < 0)
			r = -76; /* write-file IOR */
	return fclose(out) < 0 ? -62 /* close-file IOR */ : r;
}

embed_opt_t embed_opt_default_hosted(void) {
	embed_opt_t o = embed_opt_default();
	o.in   = stdin;
	o.out  = stdout;
	o.put  = embed_fputc_cb;
	o.get  = embed_fgetc_cb;
	o.save = embed_save_cb;
	return o;
}

int embed_default_hosted(embed_t *h) {
	assert(h);
	if(embed_default(h) < 0)
		return -1;
	h->o = embed_opt_default_hosted();
	return 0;
}

int embed_fputc_cb(int ch, void *file) { 
	assert(file); 
	return fputc(ch, file); 
}

int embed_fgetc_cb(void *file, int *no_data) { 
	assert(file && no_data); 
	*no_data = 0; 
	return fgetc(file); 
}

static inline int is_big_endian(void)              { return (*(uint16_t *)"\0\xff" < 0x100); }
static void embed_normalize(embed_t *h, size_t l)  { assert(h); if(is_big_endian()) embed_buffer_swap(h->m, l); }

int embed_load_file(embed_t *h, FILE *input) {
	assert(h && input);
	size_t r = fread(h->m, 1, EMBED_CORE_SIZE * sizeof(cell_t), input);
	embed_normalize(h, r/2);
	return r < 128 ? -70 /* read-file IOR */ : 0; /* minimum size checks, 128 bytes */
}

int embed_forth_opt(embed_t *h, embed_vm_option_e opt, FILE *in, FILE *out, const char *block) {
	embed_opt_t o_old = embed_opt_default_hosted();
	embed_opt_t o_new = o_old;
	o_new.in = in, o_new.out = out, o_new.options = opt, o_new.name = block;
	embed_opt_set(h, &o_new);
	const int r = embed_vm(h);
	embed_opt_set(h, &o_old);
	return r;
}

int embed_forth(embed_t *h, FILE *in, FILE *out, const char *block) { 
	return embed_forth_opt(h, 0, in, out, block); 
}

