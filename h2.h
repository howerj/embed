#ifndef H2_H
#define H2_H

#include <stddef.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>

/**@note STK_SIZE is fixed to 64, but h2.vhd allows for the instantiation of
 * CPUs with different stack sizes, within reasonable limits, so long as they
 * are a power of 2. */

#define MAX_CORE             (8192u)
#define STK_SIZE             (64u)
#define START_ADDR           (0u)

#define H2_CPU_ID_SIMULATION (0xDEADu)

#define FLASH_INIT_FILE      ("nvram.blk") /**< default file for flash initialization */

typedef uint16_t word_t;

typedef struct {
	size_t length;
	word_t *points;
} break_point_t;

typedef struct {
	word_t core[MAX_CORE]; /**< main memory */
	word_t rstk[STK_SIZE]; /**< return stack */
	word_t dstk[STK_SIZE]; /**< variable stack */
	word_t pc;  /**< program counter */
	word_t tos; /**< top of stack */
	word_t rp;  /**< return stack pointer */
	word_t sp;  /**< variable stack pointer */

	break_point_t bp; /**< list of break points */
	word_t rpm; /**< maximum value of rp ever encountered */
	word_t spm; /**< maximum value of sp ever encountered */
} h2_t; /**< state of the H2 CPU */

typedef enum {
	SYMBOL_TYPE_LABEL,
	SYMBOL_TYPE_CALL,
	SYMBOL_TYPE_CONSTANT,
	SYMBOL_TYPE_VARIABLE,
} symbol_type_e;

typedef struct {
	symbol_type_e type;
	char *id;
	word_t value;
	bool hidden;
} symbol_t;

typedef struct {
	size_t length;
	symbol_t **symbols;
} symbol_table_t;

#define UART_RX_FIFO_EMPTY_BIT     (8)
#define UART_RX_FIFO_FULL_BIT      (9)
#define UART_RX_RE_BIT             (10)
#define UART_TX_FIFO_EMPTY_BIT     (11)
#define UART_TX_FIFO_FULL_BIT      (12)
#define UART_TX_WE_BIT             (13)

#define UART_RX_FIFO_EMPTY         (1 << UART_RX_FIFO_EMPTY_BIT)
#define UART_RX_FIFO_FULL          (1 << UART_RX_FIFO_FULL_BIT)
#define UART_RX_RE                 (1 << UART_RX_RE_BIT)
#define UART_TX_FIFO_EMPTY         (1 << UART_TX_FIFO_EMPTY_BIT)
#define UART_TX_FIFO_FULL          (1 << UART_TX_FIFO_FULL_BIT)
#define UART_TX_WE                 (1 << UART_TX_WE_BIT)

#define CHIP_MEMORY_SIZE           (1*1024*1024) /*NB. size in WORDs not bytes! */
#define FLASH_MASK_ADDR_UPPER_MASK (0x1ff)

#define SRAM_CHIP_SELECT_BIT       (11)
#define FLASH_MEMORY_WAIT_BIT      (12)
#define FLASH_MEMORY_OE_BIT        (14)
#define FLASH_MEMORY_WE_BIT        (15)

#define FLASH_CHIP_SELECT          (1 << FLASH_CHIP_SELECT_BIT)
#define SRAM_CHIP_SELECT           (1 << SRAM_CHIP_SELECT_BIT)
#define FLASH_MEMORY_OE            (1 << FLASH_MEMORY_OE_BIT)
#define FLASH_MEMORY_WE            (1 << FLASH_MEMORY_WE_BIT)

#define FLASH_BLOCK_MAX            (130)

typedef struct {
	uint8_t uart_getchar_register;
	word_t vram[CHIP_MEMORY_SIZE];
	word_t mem_control;
	word_t mem_addr_low;
	word_t mem_dout;
} h2_soc_state_t;

typedef word_t (*h2_io_get)(h2_soc_state_t *soc, word_t addr, bool *debug_on);
typedef void     (*h2_io_set)(h2_soc_state_t *soc, word_t addr, word_t value, bool *debug_on);
typedef void     (*h2_io_update)(h2_soc_state_t *soc);

typedef struct {
	h2_io_get in;
	h2_io_set out;
	h2_io_update update;
	h2_soc_state_t *soc;
} h2_io_t;

typedef enum {
	iUart         = 0x4000,
	iMemDin       = 0x4002,
} h2_input_addr_t;

typedef enum {
	oUart         = 0x4000,
	oMemDout      = 0x4002,
	oMemControl   = 0x4004,
	oMemAddrLow   = 0x4006,
} h2_output_addr_t;

/** @warning LOG_FATAL level kills the program */
#define X_MACRO_LOGGING\
	X(LOG_MESSAGE_OFF,  "")\
	X(LOG_FATAL,        "fatal")\
	X(LOG_ERROR,        "error")\
	X(LOG_WARNING,      "warning")\
	X(LOG_NOTE,         "note")\
	X(LOG_DEBUG,        "debug")\
	X(LOG_ALL_MESSAGES, "any")

typedef enum {
#define X(ENUM, NAME) ENUM,
	X_MACRO_LOGGING
#undef X
} log_level_e;

extern log_level_e log_level;

#define fatal(FMT, ...)   logger(LOG_FATAL,   __func__, __LINE__, FMT, ##__VA_ARGS__)
#define error(FMT, ...)   logger(LOG_ERROR,   __func__, __LINE__, FMT, ##__VA_ARGS__)
#define warning(FMT, ...) logger(LOG_WARNING, __func__, __LINE__, FMT, ##__VA_ARGS__)
#define note(FMT, ...)    logger(LOG_NOTE,    __func__, __LINE__, FMT, ##__VA_ARGS__)
#define debug(FMT, ...)   logger(LOG_DEBUG,   __func__, __LINE__, FMT, ##__VA_ARGS__)

#define BACKSPACE (8)
#define ESCAPE    (27)
#define DELETE    (127)  /* ASCII delete */

#endif
