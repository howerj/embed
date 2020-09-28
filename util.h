/** @file      util.h
 *  @brief     Utility functions used by Embed library test applications
 *  @copyright Richard James Howe (2018)
 *  @license   MIT
 *
 *  Do not be afraid to modify things and generally hack around with things,
 *  if you want to port this to a microcontroller you might need to modify
 *  this file and 'embed.c' as well. */
#ifndef UTIL_H
#define UTIL_H
#ifdef __cplusplus
extern "C" {
#endif

#include "embed.h"
#include <stddef.h>
#include <stdio.h>

typedef enum {
	EMBED_LOG_LEVEL_ALL_OFF, /**< Turn all log messages off, EMBED_LOG_LEVEL_FATAL still kills the process */
	EMBED_LOG_LEVEL_FATAL,   /**< Log a fatal error message, and die! */
	EMBED_LOG_LEVEL_ERROR,   /**< For errors, recoverable */
	EMBED_LOG_LEVEL_WARNING, /**< Warning information */
	EMBED_LOG_LEVEL_INFO,    /**< General information, */
	EMBED_LOG_LEVEL_DEBUG,   /**< Debug operations, may produce voluminous output */
	EMBED_LOG_LEVEL_ALL_ON,  /**< Turn all log messages on */
} embed_log_level_e; /**< Log levels, and all on/off enumerations */

typedef struct {
	const char *arg;   /**< parsed argument */
	int error,   /**< turn error reporting on/off */
	    index,   /**< index into argument list */
	    option,  /**< parsed option */
	    reset;   /**< set to reset */
	const char *place; /**< internal use: scanner position */
	int  init;   /**< internal use: initialized or not */
} embed_getopt_t;    /**< getopt clone */

/* returns -1 when finished, '?' (bad option), ':' (bad argument) on error */
int embed_getopt(embed_getopt_t *opt, int nargc, char *const nargv[], const char *fmt);

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

/**@brief Make a new Forth VM, and load with default image. The default image
 * contains a fully working eForth image.
 * @return a pointer to a new Forth VM, loaded with the default image */
embed_t  *embed_new(void);

/**@brief Free a Forth VM
 * @param h,     initialized Virtual Machine image to free */
void embed_free(embed_t *h);

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
int embed_fgetc_cb(void *file, int *no_data);

/**@brief Saves to a file called 'name', this is the default callback to save
 * an image to disk with the 'save' ALU instruction.
 * @param h,       embed virtual machine to save
 * @param name,    name of file to save to on disk
 * @param start,   start of image location to save from
 * @param length,  length in cell_t to save, starting at 'start'
 * @return 0 on success, negative on failure */
int embed_save_cb(const embed_t *h, const void *name, const size_t start, const size_t length);

/**@brief Default the virtual machine image with parameters suitable for a
 * hosted environment
 * @param h, a virtual machine image, possible uninitialized.
 * @return zero on success, negative on failure */
int embed_default_hosted(embed_t *h);

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

/**@brief returns an initialized 'embed_opt_t' structure for hosted use
 * @return an initialized 'embed_opt_t' structure suitable for hosted use */
embed_opt_t embed_opt_default_hosted(void);

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

/**@brief Run the built in self tests for the eForth interpreter, this may
 * generate temporary files in the directory the executable is run.
 * @return zero on success, negative on failure */
int embed_tests(void);

#ifndef NDEBUG
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

#ifdef __cplusplus
}
#endif
#endif

