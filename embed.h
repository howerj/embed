/** @file      embed.h
 *  @brief     Embed Forth Virtual Machine Library Interface
 *  @copyright Richard James Howe (2017,2018)
 *  @license   MIT 
 *
 *  Do not be afraid to modify things and generally hack around with things,
 *  if you want to port this to a microcontroller you might need to modify
 *  this file and 'embed.c' as well. 
 */
#ifndef EMBED_H
#define EMBED_H

#ifdef __cplusplus
extern "C" {
#endif
#include <stdio.h>
#include <stddef.h>
#include <stdint.h>

typedef uint16_t cell_t;               /**< Virtual Machine Cell size: 16-bit*/
typedef  int16_t signed_cell_t;        /**< Virtual Machine Signed Cell */
typedef uint32_t double_cell_t;        /**< Virtual Machine Double Cell (2*sizeof(cell_t)) */
typedef  int32_t signed_double_cell_t; /**< Virtual Machine Signed Double Cell */

struct embed_t;                 /**< Forth Virtual Machine State (Opaque) */
typedef struct embed_t embed_t; /**< Forth Virtual Machine State Type Define (Opaque) */

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
typedef int (*embed_fputc_t)(int ch, void *file); /**< write character to file, return character wrote on success */

/**@brief Function pointer typedef for functions that are to write sections of
 * the virtual machine image to mass storage. Mass storage on a hosted machine
 * would be a file on disk, but on a microcontroller it could be a Flash
 * chip, for example.
 * @param m,      Virtual Machine memory to write to, of embed_length() cell_t long (maximum length is 32768).
 * @param name,   handle that identifies place to write to (such as a 'FILE*')
 * @param start,  position in 'm' to start write from
 * @param length, length of section to save from 'm', starting at 'start'.
 * @return zero on success, negative on failure */
typedef int (*embed_save_t)(const cell_t m[/*static 32768*/], const void *name, const size_t start, const size_t length);

/**@brief Function pointer typedef for user supplied callbacks for doing
 * arbitrary things. The function should return zero on success or a number
 * that the virtual machine should throw on failure.
 * @param h,     initialized Virtual Machine image
 * @param param, arbitrary parameter data
 * @return zero to continue execute, non-zero to throw */
typedef int (*embed_callback_t)(embed_t *h, void *param);

typedef enum {
	EMBED_VM_TRACE_ON        = 1u << 0, /**< turn tracing on */
	EMBED_VM_RX_NON_BLOCKING = 1u << 1, /**< embed_fgetc_t passed in does not block (EOF = no data, not End Of File) */
	EMBED_VM_RAW_TERMINAL    = 1u << 2, /**< raw terminal mode */
	EMBED_VM_QUITE_ON        = 1u << 3, /**< turn off 'okay' prompt and welcome message */
} embed_vm_option_e; /**< VM option enum */

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

/**@brief Saves to a file called 'name', this is the default callback to save
 * an image to disk with the 'save' ALU instruction.
 * @param m,       memory to save to disk, 32768 cell_t long
 * @param name,    name of file to save to on disk
 * @param start,   start of image location to save from
 * @param length,  length in cell_t to save, starting at 'start'
 * @return 0 on success, negative on failure */
int embed_save_cb(const cell_t m[/*static 32768*/], const void *name, const size_t start, const size_t length); 

/**@brief 'embed_fputc_t' callback to write to a file
 * @param file, a 'FILE*' object to write to
 * @param ch,  unsigned char to write to file
 * @return ch on success, negative on failure */
int embed_fputc_cb(int ch, void *file); 

/**@brief 'embed_fgetc_t' callback to read from a file
 * @param file, a 'FILE*' object to read from
 * @param no_data, if there is no data to be at the moment but there might be
 * some in the future -1 will be written to 'no_data'.
 * @return EOF on failure, unsigned char value on success */
int embed_fgetc_cb(void *file, int *no_data);         /**< 'file' is a 'FILE*', like 'stdin' */

/**@brief alternative 'embed_fgetc_t' to read data from a string
 * @param string_ptr, pointer to character array ('char**') to read from
 * @param no_data, if there is no data to be at the moment but there might be
 * some in the future -1 will be written to 'no_data'.
 * @return EOF on failure, unsigned char value on success */
int embed_sgetc_cb(void *string_ptr, int *no_data);   /**< 'string_ptr' is a 'char **' to ASCII NUL terminated string */

typedef enum {
	EMBED_LOG_LEVEL_ALL_OFF, /**< Turn all log messages off, EMBED_LOG_LEVEL_FATAL still kills the process */
	EMBED_LOG_LEVEL_FATAL,   /**< Log a fatal error message, and die! */
	EMBED_LOG_LEVEL_ERROR,   /**< For errors, recoverable */
	EMBED_LOG_LEVEL_WARNING, /**< Warning information */
	EMBED_LOG_LEVEL_INFO,    /**< General information, */
	EMBED_LOG_LEVEL_DEBUG,   /**< Debug operations, may produce voluminous output */
	EMBED_LOG_LEVEL_ALL_ON,  /**< Turn all log messages on */
} embed_log_level_e; /**< Log levels, and all on/off enumerations */

#ifndef NDEBUF
#define embed_fatal(...)   embed_logger(EMBED_LOG_LEVEL_FATAL,   __FILE__, __func__, __LINE__, __VA_ARGS__)
#define embed_error(...)   embed_logger(EMBED_LOG_LEVEL_ERROR,   __FILE__, __func__, __LINE__, __VA_ARGS__)
#define embed_warning(...) embed_logger(EMBED_LOG_LEVEL_WARNING, __FILE__, __func__, __LINE__, __VA_ARGS__)
#define embed_info(...)    embed_logger(EMBED_LOG_LEVEL_INFO,    __FILE__, __func__, __LINE__, __VA_ARGS__)
#define embed_debug(...)   embed_logger(EMBED_LOG_LEVEL_DEBUG,   __FILE__, __func__, __LINE__, __VA_ARGS__)
#else
/* fatal is always so, even if debugging is off */
#define embed_fatal(...)   embed_die()
#define embed_error(...)   do { } while(0)
#define embed_warning(...) do { } while(0)
#define embed_info(...)    do { } while(0)
#define embed_debug(...)   do { } while(0)
#endif

#ifndef UNUSED
/**@brief This macro can be used to suppress warnings relating to a variable
 * being unused in a function. This should be used carefully and sparingly, and
 * to indicate intention. Valid uses include in callbacks where a parameter
 * might not be used in that specific callback, or in code that is selected for
 * depending on platform which may not use a variable on that platform.
 * @param VARIABLE, variable to silence warning of and mark as unused */
#define UNUSED(VARIABLE) ((void)(VARIABLE))
#endif

#ifndef MAX
/**@brief Macro to return the maximum value of X and Y
 * @param X, value
 * @param Y, value
 * @return Maximum value of X and Y */
#define MAX(X, Y) ((X) > (Y) ? (X) : (Y))
#endif

#ifndef MIN
/**@brief Macro to return the Minimum value of X and Y
 * @param X, value
 * @param Y, value
 * @return Minimum value of X and Y */
#define MIN(X, Y) ((X) > (Y) ? (Y) : (X))
#endif

/**@brief Set the global log level, this may be any 
* @param level, level to log up to, any log level equal to or lower than than
* this value will be logged */
void embed_log_level_set(embed_log_level_e level);

/**@brief Get the global log level
*  @return Global log level */
embed_log_level_e embed_log_level_get(void);            

/**@brief Exit system with failure */
void embed_die(void);

/**@brief Printf a format string to standard error with a few additional
 * extras to make things easier. A new line is automatically appended to the
 * logged line, and log-level/file/function and line information is printed.
 * Whether something is logged or the log is suppressed can be controlled with
 * by the 'embed_log_level_set()' function.
 * @param level, logging level, should be WITHIN 'EMBED_LOG_LEVEL_ALL_OFF' and
 * 'EMBED_LOG_LEVEL_ALL_ON', which themselves are not valid logging levels. Also
 * of note, EMBED_LOG_LEVEL_FATAL causes the process to terminate! Even if the
 * log is not printed because the log level is off, 'exit()' will still be
 * called if the log level is fatal. 'exit' is called with the 'EXIT_FAILURE'
 * value.
 * @param file,  file logging occurs within, should be __FILE__
 * @param func,  function logging occurs within, should be __func__
 * @param line,  line logging occurred on, should be __LINE__
 * @param fmt,   a printf format string
 * @param ...,   variable length parameter list for 'fmt' */
void embed_logger(embed_log_level_e level, const char *file, const char *func, unsigned line, const char *fmt, ...); 

/**@brief Open up 'file', and if that fails print out an error message and
 * call exit with EXIT_FAILURE.
 * @param file, name of file to open
 * @param mode, mode to open file in
 * @return An open file handle, this never returns NULL */
FILE *embed_fopen_or_die(const char *file, const char *mode);         

/**@brief 'calloc' of size 'sz'
 * @param sz, number of bytes to allocate
 * @return pointer to memory of size 'sz', or NULL on failure */
void *embed_alloc(size_t sz);

/**@brief 'calloc' or die 
 * @param sz, number of bytes to allocate
 * @return pointer to memory of size 'sz', never returns NULL */
void *embed_alloc_or_die(size_t sz);                              

/**@brief Make a new Forth VM, and load with default image. The default image
 * contains a fully working eForth image.
 * @return a pointer to a new Forth VM, loaded with the default image */
embed_t  *embed_new(void); 

/**@brief Copy existing instance of a Forth VM 
 * @param h,     initialized Virtual Machine image
 * @return a copy of h, or NULL on failure */
embed_t  *embed_copy(embed_t const * const h); 

/**@brief Free a Forth VM
 * @param h,     initialized Virtual Machine image to free */
void embed_free(embed_t *h);                                      

/**@brief Run the VM, reading from 'in' and writing to 'out'. This function
 * provides sensibly default options that suite most (but not all) needs for a
 * hosted system.
 * @param h,     initialized Virtual Machine image
 * @param in,    input file for VM to read from
 * @param out,   output file for VM to write to
 * @param block, name of file to write block to, may be NULL
 * @return 0 on success, negative on failure */
int embed_forth(embed_t *h, FILE *in, FILE *out, const char *block); 

/**@brief Run the VM, reading from 'in' and writing to 'out'. The user can
 * supply their own functions and options but 'in' and 'out' will be passed
 * to the get and put character callbacks.
 * @param h,     initialized Virtual Machine image
 * @param opt,   options for the virtual machine to customize its behavior 
 * @param in,    input file for VM to read from
 * @param out,   output file for VM to write to
 * @param block, name of file to write block to, may be NULL
 * @return 0 on success, negative on failure */
int embed_forth_opt(embed_t *h, embed_vm_option_e opt, FILE *in, FILE *out, const char *block); 

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

/**@brief Load VM image from FILE*
 * @param h,      uninitialized Virtual Machine image
 * @param input,  open file to read from to load a disk image
 * @return zero on success, negative on failure */
int embed_load_file(embed_t *h, FILE *input);                      

/**@brief Save VM image to disk, 0 == success
 * @param h,     Virtual Machine image to save to disk
 * @param name,  name of file to load
 * @return zero on success, negative on failure */
int embed_save(const embed_t *h, const char *name);

/**@brief Length in bytes of core memory 
 * @param h, initialized Virtual Machine image
 * @return bytes in h */
size_t embed_length(embed_t const * const h);            

/**@brief Swap byte order of a 'cell_t'
 * @param s, value to swap byte order of
 * @return cell_t with swapped byte order */
cell_t embed_swap(cell_t s);                                

/**@brief Swap byte order of a buffer of 2-byte values
 * @param b, buffer to change endianess of
 * @param l, length of buffer in cell_t*/
void embed_buffer_swap(cell_t *b, size_t l);                   

/**@brief Run the virtual machine directly, with custom options.
 * 'embed_options_default()' can be used to get a copy of a structure
 * which contains the defaults which can be modified for your purposes. The
 * options structure contains the callbacks and the data the callbacks might
 * require. You should call this function if you need to customize the virtual
 * machines behavior so it reads or writes to different I/O sources.
 * @param h, initialized virtual machine
 * @param o, options structure containing custom callbacks and callback data
 * @return zero on success, negative on failure */
int embed_vm(embed_t *h, embed_opt_t *o);  

/**@brief Push value onto the Virtual Machines stack. This can be called from
 * within the 'embed_callback_t' callback and from outside of it.
 * @param h,     initialized Virtual Machines
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

/**@brief Retrieve a copy of some sensible default options, the default options
 * contain callbacks and file handles that will read data from standard in,
 * write data to standard out and save to disk. You can modify the returned
 * structure as you please.
 * @return returns a structure, not a pointer to a structure */
embed_opt_t embed_options_default(void);

/**@brief write a string to output specified in 'o'
 * @param o, options structure containing place to write to
 * @param s, string to write
 * @return negative on failure, number of characters written otherwise */
int embed_puts(embed_opt_t const * const o, const char *s);

/**@brief Reset the virtual machine image, this means that the stack pointers,
 * top of stack register and program counter will be set to the defaults
 * contained within 'shadow' registers.
 * @param h, initialized Virtual machine image to reset  */
void embed_reset(embed_t *h);

/**@brief get a pointer to VM core 
 * @warning be careful with this!
 * @param h, initialized Virtual Machine image
 * @return point to core image of embed_length() bytes long  */
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
 * @param constant expression to check */
#define BUILD_BUG_ON(condition) ((void)sizeof(char[1 - 2*!!(condition)]))
#endif

#ifdef __cplusplus
}
#endif

#define EMBED_LIBRARY
#endif /* EMBED_H */

