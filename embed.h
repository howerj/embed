/** @file      embed.h
 *  @brief     Embed Forth Virtual Machine Library Interface
 *  @copyright Richard James Howe (2017,2018)
 *  @license   MIT
 *
 *  Do not be afraid to modify things and generally hack around with things,
 *  if you want to port this to a microcontroller you might need to modify
 *  this file and 'embed.c' as well. */
#ifndef EMBED_H
#define EMBED_H

#ifdef __cplusplus
extern "C" {
#endif
#include <stddef.h>
#include <stdint.h>

#define EMBED_CORE_SIZE (32768uL)      /**< core size in cells */

typedef uint16_t cell_t;               /**< Virtual Machine Cell size: 16-bit*/
typedef  int16_t signed_cell_t;        /**< Virtual Machine Signed Cell */
typedef uint32_t double_cell_t;        /**< Virtual Machine Double Cell (2*sizeof(cell_t)) */
typedef  int32_t signed_double_cell_t; /**< Virtual Machine Signed Double Cell */

struct embed_t;                 /**< Forth Virtual Machine State */
typedef struct embed_t embed_t; /**< Forth Virtual Machine State Type Define */

/**@brief Function pointer typedef for functions that are to retrieve a
 * character of input from a source. This function should behave the same
 * as 'fgetc' but may get its data from a different source (for example a UART
 * or a string). Another addition is a variable to indicate the blocking status
 * of the call.
 * @param file, contains a pointer to any data needed (if any) by your
 * version of this function, it may contain a pointer to a string ('char **')
 * or a file handle ('FILE*') for example.
 * @param no_data, a pointer to integer to place the blocking status of this
 * function. If there is no data to be had at the moment and you do not want
 * to block waiting for more, set the 'no_data' variable to -1, otherwise set
 * this to zero.
 * @return int, return EOF (-1) on no more input/failure, and an unsigned 8-bit
 * character value on success. */
typedef int (*embed_fgetc_t)(void *file, int *no_data);

/**@brief Function pointer typedef for functions that write a byte to an
 * output source, they should behave like 'fputc' in that they should accept
 * a character to write, return the same character on success and negative
 * on failure.
 * @param ch,   unsigned byte to write
 * @param file, handle needed to write to a source, if needed
 * @return ch on success, negative on failure */
typedef int (*embed_fputc_t)(int ch, void *file);

/**@brief Function pointer typedef for functions that are to write sections of
 * the virtual machine image to mass storage. Mass storage on a hosted machine
 * would be a file on disk, but on a microcontroller it could be a Flash
 * chip, for example.
 * @param h,      Virtual Machine memory to write to, of embed_length() cell_t long, use
 * 'embed_core_get' to get a pointer to the core to save.
 * @param name,   handle that identifies place to write to (such as a 'FILE*')
 * @param start,  position in 'm' to start write from
 * @param length, length of section to save from 'm', starting at 'start'.
 * @return zero on success, negative on failure */
typedef int (*embed_save_t)(const embed_t *h, const void *name, const size_t start, const size_t length);

/**@brief Function pointer typedef for user supplied callbacks for doing
 * arbitrary things. The function should return zero on success or a number
 * that the virtual machine should throw on failure.
 * @param h,     initialized Virtual Machine image
 * @param param, arbitrary parameter data
 * @return zero to continue execute, non-zero to throw */
typedef int (*embed_callback_t)(embed_t *h, void *param);

/**@brief Function pointer typedef for user supplied callbacks for
 * reading from the Virtual Machines memory
 * @param  h,    initialized Virtual Machine image
 * @param  addr, address of location to read from
 * @return return of MMU read */
typedef cell_t (*embed_mmu_read_t)(embed_t const * const h, cell_t addr);

/**@brief Function pointer typedef for user supplied callbacks for
 * writing to the Virtual Machines memory
 * @param h,     initialized Virtual Machine image
 * @param addr,  address of value to write
 * @param value, value to write to 'addr' */
typedef void (*embed_mmu_write_t)(embed_t * const h, cell_t addr, cell_t value);

/**@brief This function is called by the virtual machine to determine whether
 * the virtual machine should yield or not, it can be used to limit time spent
 * in the virtual machine.
 * @param param, arbitrary data to supply to the yield function
 * @return returns non zero if virtual machine should yield, and zero if it
 * should continue */
typedef int (*embed_yield_t)(void *param);

typedef enum {
	EMBED_VM_TRACE_ON     = 1u << 0, /**< turn tracing on */
	EMBED_VM_RAW_TERMINAL = 1u << 1, /**< raw terminal mode */
	EMBED_VM_QUITE_ON     = 1u << 2, /**< turn off 'ok' prompt and welcome message */
} embed_vm_option_e; /**< VM option enum */

typedef struct {
	embed_fgetc_t     get;      /**< callback to get a character, behaves like 'fgetc' */
	embed_fputc_t     put;      /**< callback to output a character, behaves like 'fputc' */
	embed_save_t      save;     /**< callback to save an image */
	embed_mmu_write_t write;    /**< callback to write location to virtual machine memory */
	embed_mmu_read_t  read;     /**< callback to read location from virtual machine memory */
	embed_callback_t  callback; /**< arbitrary user supplied callback */
	embed_yield_t     yield;    /**< callback to force the virtual machine to yield */
	void	*in,                /**< first argument to 'getc' */
		*out,               /**< second argument to 'putc' */
		*param,             /**< first argument to 'callback' */
		*yields;            /**< parameter to yield */
	const void *name;           /**< second argument to 'save' */
	embed_vm_option_e options;  /**< virtual machine options register */
} embed_opt_t; /**< Embed VM options structure for customizing behavior */

struct embed_t { /**@todo merge with embed_opt_t */
	embed_opt_t o; /**< options structure for virtual machine */
	void *m;       /**< virtual machine core memory - @warning you need to set this to something sensible! */
}; /**< Embed Forth VM structure */

/**@brief alternative 'embed_fgetc_t' to read data from a string
 * @param string_ptr, pointer to character array ('char**') to read from, this
 * should be an ASCII NUL terminated string.
 * @param no_data, if there is no data to be at the moment but there might be
 * some in the future -1 will be written to 'no_data'.
 * @return EOF on failure, unsigned char value on success */
int embed_sgetc_cb(void *string_ptr, int *no_data);

/**@brief 'embed_fputc_t' callback, discards data output
 * @param  ch,   character (discarded)
 * @param  file, can be NULL, or anything
 * @return returns 'ch' */
int embed_nputc_cb(int ch, void *file);

/**@brief 'embed_fgetc_t' callback, always returns EOF
 * @param file, not used
 * @param no_data, set to zero
 * @return returns 'EOF' */
int embed_ngetc_cb(void *file, int *no_data);

/**@brief The default yield callback, this function never yields.
 * @param param, unused
 * @return always returns false */
int embed_yield_cb(void *param);

/**@brief Default callback for reading virtual machine memory, this is equivalent to
 * returning 'm[addr]'.
 * @param h,     initialized Virtual Machine image
 * @param addr, address to read
 * @return read in address */
cell_t  embed_mmu_read_cb(embed_t const * const h, cell_t addr);

/**@brief Default callback for writing to virtual machine memory, this is
 * equivalent to 'm[addr] = value'.
 * @param h,     initialized Virtual Machine image
 * @param addr,  address to write to
 * @param value, value to write */
void embed_mmu_write_cb(embed_t * const h, cell_t addr, cell_t value);

/**@brief Load VM image off disk
 * @param h,     uninitialized Virtual Machine image
 * @param name,  name of file to load off disk
 * @return zero on success, negative on failure */
int embed_load(embed_t *h, const char *name);

/**@brief Load VM image from memory
 * @param h,      uninitialized Virtual Machine image
 * @param buf,    byte buffer to load from
 * @param length, length of 'buf'
 * @return zero on success, negative on failure */
int embed_load_buffer(embed_t *h, const uint8_t *buf, size_t length);

/**@brief Load the default configuration options for the embed virtual machine
 * and the default image as well.
 * @param h, an uninitialized
 * @return returns non-zero on failure, and zero on success */
int embed_default(embed_t *h);

/**@brief Length in bytes of core memory
 * @param h, initialized Virtual Machine image
 * @return bytes in h */
size_t embed_length(embed_t const * const h);

/**@brief Length in cells of core memory
 * @param h, initialized Virtual Machine image
 * @return cells in h*/
size_t embed_cells(embed_t const * const h);

/**@brief Swap byte order of a buffer of 2-byte values
 * @param b, buffer to change endianess of
 * @param l, length of buffer in cell_t */
void embed_buffer_swap(cell_t *b, size_t l);

/**@brief Run the virtual machine directly, with custom options.
 * 'embed_opt_default()' can be used to get a copy of a structure
 * which contains the defaults which can be modified for your purposes. The
 * options structure contains the callbacks and the data the callbacks might
 * require. You should call this function if you need to customize the virtual
 * machines behavior so it reads or writes to different I/O sources.
 * @param h, initialized virtual machine
 * @return zero on success, negative on failure */
int embed_vm(embed_t *h);

/**@brief Push value onto the Virtual Machines stack. This can be called from
 * within the 'embed_callback_t' callback and from outside of it.
 * @param h,     initialized Virtual Machine image
 * @param value, value to push
 * @return zero on success, negative on failure */
int embed_push(embed_t *h, cell_t value);

/**@brief Pop value in 'value', returns negative on failure. This can be
 * called from within the 'embed_callback_t' callback and from outside of
 * it. It places that value into 'value' on success.
 * @param h,     initialized Virtual Machine
 * @param value, pointer to value to pop into
 * @return zero on success, negative on failure */
int embed_pop(embed_t *h, cell_t *value);

/**@brief Return the current variable stack depth
 * @param h, initialized Virtual Machine
 * @return The current stack depth in cells */
size_t embed_depth(embed_t *h);

/**@brief Retrieve a copy of some sensible default options, the default options
 * contain callbacks and file handles that will read data from standard in,
 * write data to standard out and save to disk. You can modify the returned
 * structure as you please.
 * @return returns a structure, not a pointer to a structure */
embed_opt_t embed_opt_default(void);

/**@brief Retrieve a copy of the current options set in 'h'
 * @param h, initialized virtual machine image
 * @return copy of current embed_opt_t structure in 'h' */
embed_opt_t *embed_opt_get(embed_t *h);

/**@brief Retrieve a copy of the current options set in 'h'
 * @param h, initialized virtual machine image
 * @return copy of current embed_opt_t structure in 'h' */
void embed_opt_set(embed_t *h, embed_opt_t *opt);

/**@brief write a string to output specified in the options within 'h'
 * @param h, initialized virtual machine image with options set
 * @param s, string to write
 * @return negative on failure, number of characters written otherwise */
int embed_puts(embed_t *h, const char *s);

/**@brief Reset the virtual machine image, this means that the stack pointers,
 * top of stack register and program counter will be set to the defaults.
 * @param h, initialized Virtual Machine image to reset */
void embed_reset(embed_t *h);

/**@brief get a pointer to VM core
 * @warning be careful with this!
 * @param h, initialized Virtual Machine image
 * @return point to core image of embed_length() bytes long */
cell_t *embed_core_get(embed_t *h);

/**@brief evaluate a string, each line should be less than 80 chars and end in a newline
 * @param h,   an initialized virtual machine
 * @param str, string to evaluate
 * @return zero on success, negative on failure */
int embed_eval(embed_t *h, const char *str);

/**@brief This array contains the default virtual machine image, generated from
 * 'embed-1.blk', which is included in the library. It contains a fully working
 * eForth image */
extern const uint8_t embed_default_block[];

/**@brief This is size, in bytes, of 'embed_default_block' */
extern const size_t embed_default_block_size;

#ifndef BUILD_BUG_ON
/**@brief This is effectively a static_assert for condition
 * @param condition, constant expression to check */
#define BUILD_BUG_ON(condition) ((void)sizeof(char[1 - 2*!!(condition)]))
#endif

#ifdef __cplusplus
}
#endif

#define EMBED_LIBRARY
#endif /* EMBED_H */

