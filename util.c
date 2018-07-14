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
		return NULL; 
	if(embed_load_buffer(h, embed_default_block, embed_default_block_size) < 0) {
		embed_free(h);
		return NULL;
	}
	h->o = embed_opt_default();
	return h; 
}

void embed_free(embed_t *h)  { 
	assert(h); 
	memset(h, 0, sizeof(*h)); free(h); 
}

embed_t *embed_copy(embed_t const * const h) { 
	assert(h); 
	embed_t *r = embed_new(); 
	if(!r) 
		return NULL; 
	return memcpy(r, h, sizeof(*h)); 
}

