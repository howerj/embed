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

struct forth_t;                 /**< Forth Virtual Machine State */
typedef struct forth_t forth_t; /**< Forth Virtual Machine State Type Define */

void      embed_die(const char *fmt, ...);                                 /**< fprintf to stderr and die */
FILE     *embed_fopen_or_die(const char *file, const char *mode);          /** die on fopen failure */
forth_t  *embed_new(void);                                                 /**< make a new Forth VM */
forth_t  *embed_copy(forth_t const * const h);                             /**< Copy existing instance of a Forth VM */
void      embed_free(forth_t *h);                                          /**< Delete a Forth VM */
int       embed_forth(forth_t *h, FILE *in, FILE *out, const char *block); /**< Run! */
int       embed_load(forth_t *h, const char *name);                        /**< Load VM image off disk */
int       embed_save(forth_t *h, const char *name);                        /**< Save VM image to disk */
size_t    embed_length(forth_t const * const h);                           /**< Length in bytes of core memory */
char     *embed_get_core(forth_t *h);                                      /**< Get core memory */

#ifdef __cplusplus
}
#endif
#endif /* EMBED_H */
