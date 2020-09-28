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
embed_log_level_e embed_log_level_get(void) { return global_log_level; }
void embed_die(void) { exit(EXIT_FAILURE); }
void *embed_alloc(const size_t sz) { return calloc(sz, 1); }

/*NB. Logging and other helper functions probably do not belong in this library */
static void _embed_logger(embed_log_level_e level, const char *file, const char *func, unsigned line, const char *fmt, va_list arg) {
	assert(file && func && fmt && level < EMBED_LOG_LEVEL_ALL_ON);
	if (level > embed_log_level_get())
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
	if (level == EMBED_LOG_LEVEL_FATAL)
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
	if (!(h = fopen(file, mode)))
		embed_fatal("file open %s (mode %s) failed: %s", file, mode, strerror(errno));
	return h;
}

embed_t *embed_new(void) {
	embed_t *h = calloc(sizeof(struct embed_t), 1);
	if (!h)
		goto fail;
	h->m = calloc(EMBED_CORE_SIZE * sizeof(cell_t), 1);
	if (!(h->m))
		goto fail;
	if (embed_default_hosted(h) < 0)
		goto fail;
	h->o = embed_opt_default();
	return h;
fail:
	embed_free(h);
	return NULL;
}

void embed_free(embed_t *h)  {
	if (!h)
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
	if (!f)
		return -69;
	const int r = embed_load_file(h, f);
	fclose(f);
	return r;
}

int embed_save_cb(const embed_t *h, const void *name, const size_t start, const size_t length) {
	assert(h);
	const embed_mmu_read_t  mr = h->o.read;
	if (!name || !(((length - start) <= length) && ((start + length) <= embed_cells(h))))
		return -69; /* open-file IOR */
	FILE *out = fopen(name, "wb");
	if (!out)
		return -69; /* open-file IOR */
	int r = 0;
	for (size_t i = start; i < length; i++)
		if (fputc(mr(h, i) & 255, out) < 0 || fputc(mr(h, i) >> 8, out) < 0)
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
	if (embed_default(h) < 0)
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

static inline int is_big_endian(void) {
	return (*(uint16_t *)"\0\xff" < 0x100);
}

static void embed_normalize(embed_t *h, size_t l)  {
	assert(h);
	if (is_big_endian())
		embed_buffer_swap(h->m, l);
}

int embed_load_file(embed_t *h, FILE *input) {
	assert(h && input);
	const size_t r = fread(h->m, 1, EMBED_CORE_SIZE * sizeof(cell_t), input);
	embed_normalize(h, r / 2);
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

/* Adapted from: <https://stackoverflow.com/questions/10404448> */
int embed_getopt(embed_getopt_t *opt, const int argc, char *const argv[], const char *fmt) {
	assert(opt);
	assert(fmt);
	assert(argv);
	enum { BADARG_E = ':', BADCH_E = '?' };
	static const char *string_empty = "";

	if (!(opt->init)) {
		opt->place = string_empty; /* option letter processing */
		opt->init  = 1;
		opt->index = 1;
	}

	if (opt->reset || !*opt->place) { /* update scanning pointer */
		opt->reset = 0;
		if (opt->index >= argc || *(opt->place = argv[opt->index]) != '-') {
			opt->place = string_empty;
			return -1;
		}
		if (opt->place[1] && *++opt->place == '-') { /* found "--" */
			opt->index++;
			opt->place = string_empty;
			return -1;
		}
	}

	const char *oli; /* option letter list index */
	if ((opt->option = *opt->place++) == ':' || !(oli = strchr(fmt, opt->option))) { /* option letter okay? */
		 /* if the user didn't specify '-' as an option, assume it means -1.  */
		if (opt->option == '-')
			return -1;
		if (!*opt->place)
			opt->index++;
		if (opt->error && *fmt != ':')
			embed_error("illegal option -- %c", opt->option);
		return BADCH_E;
	}

	if (*++oli != ':') { /* don't need argument */
		opt->arg = NULL;
		if (!*opt->place)
			opt->index++;
	} else {  /* need an argument */
		if (*opt->place) { /* no white space */
			opt->arg = opt->place;
		} else if (argc <= ++opt->index) { /* no arg */
			opt->place = string_empty;
			if (*fmt == ':')
				return BADARG_E;
			if (opt->error)
				embed_error("option requires an argument -- %c", opt->option);
			return BADCH_E;
		} else	{ /* white space */
			opt->arg = argv[opt->index];
		}
		opt->place = string_empty;
		opt->index++;
	}
	return opt->option; /* dump back option letter */
}

/* --- Built In Self Test --- */

typedef struct {
	unsigned passed,
		 run;
} unit_test_t;

static inline unit_test_t _unit_test_start(const char *file, const char *func, unsigned line) {
	unit_test_t t = { .run = 0, .passed = 0 };
	fprintf(stdout, "Start tests: %s in %s:%u\n\n", func, file, line);
	return t;
}

static inline void _unit_test_statement(const char *expr_str) {
	fprintf(stdout, "   STATE: %s\n", expr_str);
}

static inline void _unit_test(unit_test_t *t, int failed, const char *expr_str, const char *file, const char *func, unsigned line, int die) {
	assert(t);
	if(failed) {
		fprintf(stdout, "  FAILED: %s (%s:%s:%u)\n", expr_str, file, func, line);
		if(die) {
			fputs("VERIFY FAILED - EXITING\n", stdout);
			exit(EXIT_FAILURE);
		}
	} else {
		fprintf(stdout, "      OK: %s\n", expr_str);
		t->passed++;
	}
	t->run++;
}

static inline int unit_test_finish(unit_test_t *t) {
	assert(t);
	fprintf(stdout, "Tests passed/total: %u/%u\n", t->passed, t->run);
	if(t->run != t->passed) {
		fputs("[FAILED]\n", stdout);
		return -1;
	}
	fputs("[SUCCESS]\n", stdout);
	return 0;
}

#define unit_test_statement(T, EXPR) do { (void)(T); EXPR; _unit_test_statement(( #EXPR)); } while(0)
#define unit_test_start()         _unit_test_start(__FILE__, __func__, __LINE__)
#define unit_test(T, EXPR)        _unit_test((T), 0 == (EXPR), (# EXPR), __FILE__, __func__, __LINE__, 0)
#define unit_test_verify(T, EXPR) _unit_test((T), 0 == (EXPR), (# EXPR), __FILE__, __func__, __LINE__, 1)

static inline int test_embed_stack(void) {
	unit_test_t t = unit_test_start();
	embed_t *h = NULL;
	unit_test_verify(&t, (h = embed_new()) != NULL);

	cell_t v = 0;
	unit_test(&t, embed_depth(h)   == 0);
	unit_test(&t, embed_push(h, 5) == 0);
	unit_test(&t, embed_depth(h)   == 1);
	unit_test(&t, embed_push(h, 6) == 0);
	unit_test(&t, embed_depth(h)   == 2);
	unit_test(&t, embed_pop(h, &v) == 0);
	unit_test(&t, v == 6);
	unit_test(&t, embed_pop(h, &v) == 0);
	unit_test(&t, v == 5);
	unit_test(&t, embed_pop(h, NULL) != 0);
	unit_test(&t, embed_depth(h)   == 0);
	unit_test(&t, embed_pop(h, &v) != 0);
	unit_test(&t, embed_depth(h)   == 0);
	unit_test(&t, embed_push(h, 7) == 0);
	unit_test(&t, embed_pop(h, &v) == 0);
	unit_test(&t, v == 7);

	unit_test_statement(&t, embed_free(h));
	return unit_test_finish(&t);
}

static inline int test_embed_eval(void) {
	unit_test_t t = unit_test_start();
	embed_t *h = NULL;
	unit_test_verify(&t, (h = embed_new()) != NULL);

	unit_test(&t, embed_eval(h, "2 2 + \n") == 0);
	cell_t v = 0;
	unit_test(&t, embed_pop(h, &v) == 0); /* result */
	unit_test(&t, v == 4);

	unit_test_statement(&t, embed_free(h));

	return unit_test_finish(&t);
}

static inline int test_embed_reset(void) {
	unit_test_t t = unit_test_start();
	embed_t *h = NULL;
	unit_test_verify(&t, (h = embed_new()) != NULL);

	unit_test(&t, embed_depth(h)   == 0);
	unit_test(&t, embed_push(h, 1) == 0);
	unit_test(&t, embed_push(h, 1) == 0);
	unit_test(&t, embed_depth(h)   == 2);
	unit_test_statement(&t, embed_reset(h));
	unit_test(&t, embed_depth(h)   == 0);

	unit_test_statement(&t, embed_free(h));
	return unit_test_finish(&t);
}

typedef struct {
	int result;
} test_callback_t;

static inline int test_callback(embed_t *h, void *param) {
	assert(h && param);
	test_callback_t *result = (test_callback_t*)param;
	cell_t r1 = 0;
	cell_t r2 = 0;
	if(embed_depth(h) < 2)
		return -1;
	embed_pop(h, &r1);
	embed_pop(h, &r2);
	result->result = r1 + r2;
	return 0;
}

static inline int test_embed_callbacks(void) {
	unit_test_t t = unit_test_start();
	embed_t *h = NULL;
	unit_test_verify(&t, (h = embed_new()) != NULL);

	test_callback_t parameter = { .result = 0 };

	embed_opt_t o = *embed_opt_get(h);
	unit_test_statement(&t, o.callback = test_callback);
	unit_test_statement(&t, o.param    = &parameter);
	unit_test_statement(&t, embed_opt_set(h, &o));
	unit_test(&t, embed_eval(h, "only forth definitions system +order\n") == 0);
	unit_test(&t, embed_eval(h, " 3 4 vm \n") == 0);
	unit_test(&t, parameter.result == 7);
	unit_test(&t, embed_depth(h) == 0);

	unit_test(&t, embed_eval(h, " 5 3 vm \n") == 0);
	unit_test(&t, parameter.result == 8);
	unit_test(&t, embed_depth(h) == 0);

	unit_test_statement(&t, embed_free(h));
	return unit_test_finish(&t);
}

static int test_yield(void *param) {
	(void)param;
	static unsigned i = 0;
	return i++ > 1000; //406701;
}

static inline int test_embed_yields(void) {
	unit_test_t t = unit_test_start();
	embed_t *h = NULL;
	unit_test_verify(&t, (h = embed_new()) != NULL);

	embed_opt_t o = *embed_opt_get(h);
	unit_test_statement(&t, o.yield = test_yield);
	unit_test_statement(&t, embed_opt_set(h, &o));
	unit_test(&t, embed_vm(h) == 0);

	unit_test_statement(&t, embed_free(h));
	return unit_test_finish(&t);
}

static inline int test_embed_file(void) {
	unit_test_t t = unit_test_start();
	embed_t *h = NULL;
	unit_test_verify(&t, (h = embed_new()) != NULL);
	FILE *in = NULL;
	static const char test_file[] = "test_program.log";
	static const char test_program[] = "$CAFE $1040 -\n";

	/*unit_test_verify(&t, (in = tmpfile()) != NULL); // Causes problems on Windows */
	unit_test_statement(&t, remove(test_file));
	unit_test_verify(&t, (in = fopen(test_file, "wb+")) != NULL);
	unit_test_verify(&t, fwrite(test_program, 1, sizeof(test_program), in) == sizeof(test_program));
	unit_test_verify(&t, fflush(in) == 0);
	unit_test_verify(&t, fseek(in, 0L, SEEK_SET) != -1);

	unit_test(&t, embed_forth_opt(h, EMBED_VM_QUITE_ON, in, stdout, NULL) == 0);
	cell_t v = 0;
	unit_test(&t, embed_pop(h, &v) == 0);
	unit_test(&t, v == 0xBABE);

	unit_test(&t, fclose(in) == 0);
	unit_test(&t, remove(test_file) == 0);

	unit_test_statement(&t, embed_free(h));
	return unit_test_finish(&t);
}

int embed_tests(void) {
#ifdef NDEBUG
	embed_warning("NDEBUG Defined - unit tests not compiled into program");
	return 0;
#else
	typedef int (*test_func)(void);
	test_func funcs[] = {
		test_embed_stack,     test_embed_reset,  test_embed_eval,
		test_embed_callbacks, test_embed_yields, test_embed_file,
	};

	int r = 0;
	for (size_t i = 0; i < sizeof (funcs) / sizeof (funcs[0]); i++)
		if (funcs[i]() < 0)
			r = -1;
	return r;
#endif
}

