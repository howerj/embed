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
#include <stdint.h>
struct embed_t;                 /**< Forth Virtual Machine State */
typedef struct embed_t embed_t; /**< Forth Virtual Machine State Type Define */

void     embed_die(const char *fmt, ...);                                 /**< fprintf to stderr and die */
FILE    *embed_fopen_or_die(const char *file, const char *mode);          /**< die on fopen failure */
void    *embed_alloc_or_die(size_t sz);                                   /**< 'calloc' or die */
embed_t *embed_new(void);                                                 /**< make a new Forth VM */
embed_t *embed_copy(embed_t const * const h);                             /**< Copy existing instance of a Forth VM */
void     embed_free(embed_t *h);                                          /**< Delete a Forth VM */
int      embed_forth(embed_t *h, FILE *in, FILE *out, const char *block); /**< Run the VM */
int      embed_load(embed_t *h, const char *name);                        /**< Load VM image off disk */
int      embed_load_buffer(embed_t *h, const uint8_t *buf, size_t length);      /**< Load VM image from memory */
int      embed_load_file(embed_t *h, FILE *input);                        /**< Load VM image from FILE* */
int      embed_save(const embed_t *h, const char *name);                  /**< Save VM image to disk, 0 == success */
size_t   embed_length(embed_t const * const h);                           /**< Length in bytes of core memory */
char    *embed_core(embed_t *h);                                          /**< Get core memory, of embed_length size */
uint16_t embed_swap16(uint16_t s);                                        /**< Swap byte order of a 2-byte value */
void     embed_buffer_swap16(uint16_t *b, size_t l);                      /**< Swap byte order of a buffer of 2-byte values */

extern const uint8_t embed_default_block[];   /**< default VM image, generated from 'embed.blk' */
extern const size_t embed_default_block_size; /**< size of default VM image */

#ifdef __cplusplus
}
#endif
#endif /* EMBED_H */

