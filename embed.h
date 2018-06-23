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
typedef uint16_t (*embed_callback_t)(void *param, uint16_t *s, uint16_t sp); /**< arbitrary user supplied callback */

typedef enum {
	EMBED_VM_OPT_TRACE_ON    = 1u << 0, /**< turn tracing on */
	EMBED_VM_RX_NON_BLOCKING = 1u << 1, /**< embed_fgetc_t passed in does not block (EOF = no data, not End Of File) */
	EMBED_VM_RAW_TERMINAL    = 1u << 2, /**< raw terminal mode */
} embed_vm_status_e;

typedef struct {
	embed_fgetc_t    get;      /**< callback to get a character, behaves like 'fgetc' */
	embed_fputc_t    put;      /**< callback to output a character, behaves like 'fputc' */
	embed_save_t     save;     /**< callback to save an image */
	embed_callback_t callback; /**< arbitrary user supplied callback */
	void *in,                  /**< first argument to 'getc' */
	     *out,                 /**< second argument to 'putc' */
	     *param;               /**< first argument to 'callback' */
	const void *name;          /**< second argument to 'save' */
	embed_vm_status_e options; /**< virtual machine options register */
} embed_opt_t; /**< Embed VM options structure for customizing behavior */

/* Default Callback which can be passed to options */
int embed_save_cb(const uint16_t m[/*static 32768*/], const void *name, const size_t start, const size_t length); /**< saves to a file called 'name */
int embed_fputc_cb(int ch, void *file); /**< file is a FILE*, like 'stdout' */
int embed_fgetc_cb(void *file); /**< file is a FILE*, like 'stdin' */

void      embed_die(const char *fmt, ...);                                 /**< fprintf to stderr and die */
FILE     *embed_fopen_or_die(const char *file, const char *mode);          /**< die on fopen failure */
void     *embed_alloc_or_die(size_t sz);                                   /**< 'calloc' or die */
embed_t  *embed_new(void);                                                 /**< make a new Forth VM */
embed_t  *embed_copy(embed_t const * const h);                             /**< Copy existing instance of a Forth VM */
void      embed_free(embed_t *h);                                          /**< Delete a Forth VM */
int       embed_forth(embed_t *h, FILE *in, FILE *out, const char *block); /**< Run the VM */
int       embed_load(embed_t *h, const char *name);                        /**< Load VM image off disk */
int       embed_load_buffer(embed_t *h, const uint8_t *buf, size_t length); /**< Load VM image from memory */
int       embed_load_file(embed_t *h, FILE *input);                        /**< Load VM image from FILE* */
int       embed_save(const embed_t *h, const char *name);                  /**< Save VM image to disk, 0 == success */
size_t    embed_length(embed_t const * const h);                           /**< Length in bytes of core memory */
char     *embed_core(embed_t *h);                                          /**< Get core memory, of embed_length size */
uint16_t  embed_swap16(uint16_t s);                                        /**< Swap byte order of a 2-byte value */
void      embed_buffer_swap16(uint16_t *b, size_t l);                      /**< Swap byte order of a buffer of 2-byte values */
int       embed_vm(embed_t *h, embed_opt_t *o);

extern const uint8_t embed_default_block[];   /**< default VM image, generated from 'embed.blk' */
extern const size_t embed_default_block_size; /**< size of default VM image */

#ifndef UNUSED
#define UNUSED(VARIABLE) ((void)(VARIABLE))
#endif

#ifndef MAX
#define MAX(X, Y) ((X) > (Y) ? (X) : (Y))
#endif

#ifndef MIN
#define MIN(X, Y) ((X) > (Y) ? (Y) : (X))
#endif

#ifdef __cplusplus
}
#endif

#define EMBED_LIBRARY
#endif /* EMBED_H */

