/** @file      embed.h
 *  @brief     Embed Forth Virtual Machine Library Interface
 *  @copyright Richard James Howe (2017,2018)
 *  @license   MIT */
#ifndef EMBED_H
#define EMBED_H

#ifdef __cplusplus
extern "C" {
#endif
#include <stdio.h>
#include <stddef.h>
#include <stdint.h>

struct embed_t;                 /**< Forth Virtual Machine State (Opaque) */
typedef struct embed_t embed_t; /**< Forth Virtual Machine State Type Define (Opaque) */

typedef int (*embed_fgetc_t)(void*); /**< read character from file, return EOF on failure **/
typedef int (*embed_fputc_t)(int ch, void*); /**< write character to file, return character wrote on success */
typedef int (*embed_save_t)(const uint16_t m[/*static 32768*/], const void *name, const size_t start, const size_t length);
typedef int (*embed_callback_t)(embed_t *h, void *param); /**< arbitrary user supplied callback */

typedef enum {
	EMBED_VM_TRACE_ON        = 1u << 0, /**< turn tracing on */
	EMBED_VM_RX_NON_BLOCKING = 1u << 1, /**< embed_fgetc_t passed in does not block (EOF = no data, not End Of File) */
	EMBED_VM_RAW_TERMINAL    = 1u << 2, /**< raw terminal mode */
	EMBED_VM_QUITE_ON        = 1u << 3, /**< turn off 'okay' prompt and welcome message */
	EMBED_VM_USE_SHADOW_REGS = 1u << 4, /**< use shadow registers on entry */
} embed_vm_option_e;

typedef struct {
	embed_fgetc_t    get;      /**< callback to get a character, behaves like 'fgetc' */
	embed_fputc_t    put;      /**< callback to output a character, behaves like 'fputc' */
	embed_save_t     save;     /**< callback to save an image */
	embed_callback_t callback; /**< arbitrary user supplied callback */
	void *in,                  /**< first argument to 'getc' */
	     *out,                 /**< second argument to 'putc' */
	     *param;               /**< first argument to 'callback' */
	const void *name;          /**< second argument to 'save' */
	embed_vm_option_e options; /**< virtual machine options register */
} embed_opt_t; /**< Embed VM options structure for customizing behavior */

/* Default Callback which can be passed to options */
int embed_save_cb(const uint16_t m[/*static 32768*/], const void *name, const size_t start, const size_t length); /**< saves to a file called 'name */
int embed_fputc_cb(int ch, void *file); /**< file is a FILE*, like 'stdout' */
int embed_fgetc_cb(void *file);         /**< file is a FILE*, like 'stdin' */

typedef enum {
	EMBED_LOG_LEVEL_ALL_OFF, /**< Turn all log messages off, EMBED_LOG_LEVEL_FATAL still kills the process */
	EMBED_LOG_LEVEL_FATAL,   /**< Log a fatal error message, and die! */
	EMBED_LOG_LEVEL_ERROR,   /**< For errors, recoverable */
	EMBED_LOG_LEVEL_WARNING, /**< Warning information */
	EMBED_LOG_LEVEL_INFO,    /**< General information, */
	EMBED_LOG_LEVEL_DEBUG,   /**< Debug operations, may produce voluminous output */
	EMBED_LOG_LEVEL_ALL_ON,  /**< Turn all log messages on */
} embed_log_level_e;

#ifndef NDEBUF
#define embed_fatal(...)   embed_logger(EMBED_LOG_LEVEL_FATAL,   __FILE__, __func__, __LINE__, __VA_ARGS__)
#define embed_error(...)   embed_logger(EMBED_LOG_LEVEL_ERROR,   __FILE__, __func__, __LINE__, __VA_ARGS__)
#define embed_warning(...) embed_logger(EMBED_LOG_LEVEL_WARNING, __FILE__, __func__, __LINE__, __VA_ARGS__)
#define embed_info(...)    embed_logger(EMBED_LOG_LEVEL_INFO,    __FILE__, __func__, __LINE__, __VA_ARGS__)
#define embed_debug(...)   embed_logger(EMBED_LOG_LEVEL_DEBUG,   __FILE__, __func__, __LINE__, __VA_ARGS__)
#else
#define embed_fatal(...)   embed_die()
#define embed_error(...)   do { } while(0)
#define embed_warning(...) do { } while(0)
#define embed_info(...)    do { } while(0)
#define embed_debug(...)   do { } while(0)
#endif

#ifndef UNUSED
#define UNUSED(VARIABLE) ((void)(VARIABLE))
#endif

#ifndef MAX
#define MAX(X, Y) ((X) > (Y) ? (X) : (Y))
#endif

#ifndef MIN
#define MIN(X, Y) ((X) > (Y) ? (Y) : (X))
#endif

void      embed_log_level_set(embed_log_level_e level); /**< set global log level */
embed_log_level_e embed_log_level_get(void);            /**< get global log level */
void      embed_die(void);                              /**< exit system with failure */
void      embed_logger(embed_log_level_e level, const char *file, const char *func, unsigned line, const char *fmt, ...); /**< fprintf to stderr */
FILE     *embed_fopen_or_die(const char *file, const char *mode);          /**< die on fopen failure */
void     *embed_alloc_or_die(size_t sz);                                   /**< 'calloc' or die */
embed_t  *embed_new(void);                                                 /**< make a new Forth VM */
embed_t  *embed_copy(embed_t const * const h);                             /**< Copy existing instance of a Forth VM */
void      embed_free(embed_t *h);                                          /**< Delete a Forth VM */
int       embed_forth(embed_t *h, FILE *in, FILE *out, const char *block); /**< Run the VM */
int       embed_forth_opt(embed_t *h, embed_vm_option_e opt, FILE *in, FILE *out, const char *block); /**< Run the VM */
int       embed_load(embed_t *h, const char *name);                        /**< Load VM image off disk */
int       embed_load_buffer(embed_t *h, const uint8_t *buf, size_t length); /**< Load VM image from memory */
int       embed_load_file(embed_t *h, FILE *input);                        /**< Load VM image from FILE* */
int       embed_save(const embed_t *h, const char *name);                  /**< Save VM image to disk, 0 == success */
size_t    embed_length(embed_t const * const h);                           /**< Length in bytes of core memory */
char     *embed_core(embed_t *h);                                          /**< Get core memory, of embed_length size */
uint16_t  embed_swap16(uint16_t s);                                        /**< Swap byte order of a 2-byte value */
void      embed_buffer_swap16(uint16_t *b, size_t l);                      /**< Swap byte order of a buffer of 2-byte values */
int       embed_vm(embed_t *h, embed_opt_t *o);   /**< run the virtual machine directly, with options */
int       embed_push(embed_t *h, uint16_t value); /**< push value, returns negative on failure */
int       embed_pop(embed_t *h, uint16_t *value); /**< pop value in 'value', returns negative on failure */
embed_opt_t embed_options_default(void);          /**< retrieve a copy of some sensible default options */
void      embed_reset(embed_t *h);                /**< reset the virtual machine image */

extern const uint8_t embed_default_block[];   /**< default VM image, generated from 'embed.blk' */
extern const size_t embed_default_block_size; /**< size of default VM image */

#ifdef __cplusplus
}
#endif

#define EMBED_LIBRARY
#endif /* EMBED_H */

