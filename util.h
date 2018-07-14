/** @file      util.h
 *  @brief     Utility functions used by Embed library test applications
 *  @copyright Richard James Howe (2018)
 *  @license   MIT 
 *
 *  Do not be afraid to modify things and generally hack around with things,
 *  if you want to port this to a microcontroller you might need to modify
 *  this file and 'embed.c' as well. 
 */
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

#ifdef __cplusplus
}
#endif
#endif

