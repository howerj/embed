#ifndef H2_H
#define H2_H

#include <stddef.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>

#define MAX_PROGRAM          (8192u)
#define MAX_MEMORY           (65536u)
#define STK_SIZE             (64u)
#define START_ADDR           (0u)
#define VARIABLE_STACK_START (MAX_PROGRAM)
#define RETURN_STACK_START   (MAX_PROGRAM+STK_SIZE)

#define FORTH_BLOCK          ("forth.blk") /**< default file for flash initialization */

typedef struct {
	uint16_t core[MAX_MEMORY/2]; /**< main memory */
	uint16_t pc;  /**< program counter */
	uint16_t tos; /**< top of stack */
	uint16_t rp;  /**< return stack pointer */
	uint16_t sp;  /**< variable stack pointer */
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
	uint16_t value;
	bool hidden;
} symbol_t;

typedef struct {
	size_t length;
	symbol_t **symbols;
} symbol_table_t;

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

#define MAX(X, Y)     ((X) > (Y) ? (X) : (Y))
#define MIN(X, Y)     ((X) > (Y) ? (Y) : (X))

#define NUMBER_OF_INTERRUPTS (8u)

#define OP_BRANCH        (0x0000)
#define OP_0BRANCH       (0x2000)
#define OP_CALL          (0x4000)
#define OP_ALU_OP        (0x6000)
#define OP_LITERAL       (0x8000)

#define IS_LITERAL(INST) (((INST) & 0x8000) == 0x8000)
#define IS_BRANCH(INST)  (((INST) & 0xE000) == 0x0000)
#define IS_0BRANCH(INST) (((INST) & 0xE000) == 0x2000)
#define IS_CALL(INST)    (((INST) & 0xE000) == 0x4000)
#define IS_ALU_OP(INST)  (((INST) & 0xE000) == 0x6000)

#define ALU_OP_LENGTH   (5u)
#define ALU_OP_START    (8u)
#define ALU_OP(INST)    (((INST) >> ALU_OP_START) & ((1 << ALU_OP_LENGTH) - 1))

#define DSTACK_LENGTH   (2u)
#define DSTACK_START    (0u)
#define DSTACK(INST)    (((INST) >> DSTACK_START) & ((1 << DSTACK_LENGTH) - 1))

#define RSTACK_LENGTH   (2u)
#define RSTACK_START    (2u)
#define RSTACK(INST)    (((INST) >> RSTACK_START) & ((1 << RSTACK_LENGTH) - 1))

#define R_TO_PC_BIT_INDEX     (4u)
#define N_TO_ADDR_T_BIT_INDEX (5u)
#define T_TO_R_BIT_INDEX      (6u)
#define T_TO_N_BIT_INDEX      (7u)

#define R_TO_PC         (1u << R_TO_PC_BIT_INDEX)
#define N_TO_ADDR_T     (1u << N_TO_ADDR_T_BIT_INDEX)
#define T_TO_R          (1u << T_TO_R_BIT_INDEX)
#define T_TO_N          (1u << T_TO_N_BIT_INDEX)

typedef enum {
	ALU_OP_T,                  /**< Top of Stack         */
	ALU_OP_N,                  /**< Copy T to N          */
	ALU_OP_T_PLUS_N,           /**< Addition             */
	ALU_OP_T_AND_N,            /**< Bitwise AND          */
	ALU_OP_T_OR_N,             /**< Bitwise OR           */
	ALU_OP_T_XOR_N,            /**< Bitwise XOR          */
	ALU_OP_T_INVERT,           /**< Bitwise Inversion    */
	ALU_OP_T_EQUAL_N,          /**< Equality test        */
	ALU_OP_N_LESS_T,           /**< Signed comparison    */
	ALU_OP_N_RSHIFT_T,         /**< Logical Right Shift  */
	ALU_OP_T_DECREMENT,        /**< Decrement            */
	ALU_OP_R,                  /**< Top of return stack  */
	ALU_OP_T_LOAD,             /**< Load from address    */
	ALU_OP_N_LSHIFT_T,         /**< Logical Left Shift   */
	ALU_OP_DEPTH,              /**< Depth of stack       */
	ALU_OP_N_ULESS_T,          /**< Unsigned comparison  */

	ALU_OP_RX,                 /**< Send byte            */
	ALU_OP_TX,                 /**< Get byte             */
	ALU_OP_SAVE,               /**< Save Image           */
	ALU_OP_BYE,                /**< Return               */
	ALU_OP_RDEPTH,             /**< R Stack Depth        */
	ALU_OP_T_EQUAL_0,          /**< T == 0               */
} alu_code_e;

#define DELTA_0  (0)
#define DELTA_1  (1)
#define DELTA_N2 (2)
#define DELTA_N1 (3)

#define MK_DSTACK(DELTA) ((DELTA) << DSTACK_START)
#define MK_RSTACK(DELTA) ((DELTA) << RSTACK_START)
#define MK_CODE(CODE)    ((CODE)  << ALU_OP_START)

#define X_MACRO_INSTRUCTIONS \
	X(DUP,    "dup",    true,  (OP_ALU_OP | MK_CODE(ALU_OP_T)        | T_TO_N  | MK_DSTACK(DELTA_1)))\
	X(OVER,   "over",   true,  (OP_ALU_OP | MK_CODE(ALU_OP_N)        | T_TO_N  | MK_DSTACK(DELTA_1)))\
	X(INVERT, "invert", true,  (OP_ALU_OP | MK_CODE(ALU_OP_T_INVERT)))\
	X(ADD,    "+",      true,  (OP_ALU_OP | MK_CODE(ALU_OP_T_PLUS_N)               | MK_DSTACK(DELTA_N1)))\
	X(SWAP,   "swap",   true,  (OP_ALU_OP | MK_CODE(ALU_OP_N)        | T_TO_N))\
	X(NIP,    "nip",    true,  (OP_ALU_OP | MK_CODE(ALU_OP_T)                      | MK_DSTACK(DELTA_N1)))\
	X(DROP,   "drop",   true,  (OP_ALU_OP | MK_CODE(ALU_OP_N)                      | MK_DSTACK(DELTA_N1)))\
	X(EXIT,   "exit",   true,  (OP_ALU_OP | MK_CODE(ALU_OP_T)        | R_TO_PC | MK_RSTACK(DELTA_N1)))\
	X(TOR,    ">r",     true,  (OP_ALU_OP | MK_CODE(ALU_OP_N)        | T_TO_R  | MK_DSTACK(DELTA_N1) | MK_RSTACK(DELTA_1)))\
	X(FROMR,  "r>",     true,  (OP_ALU_OP | MK_CODE(ALU_OP_R)        | T_TO_N  | MK_DSTACK(DELTA_1)  | MK_RSTACK(DELTA_N1)))\
	X(RAT,    "r@",     true,  (OP_ALU_OP | MK_CODE(ALU_OP_R)        | T_TO_N  | MK_DSTACK(DELTA_1)))\
	X(LOAD,   "@",      true,  (OP_ALU_OP | MK_CODE(ALU_OP_T_LOAD)))\
	X(STORE,  "store",  false, (OP_ALU_OP | MK_CODE(ALU_OP_N)        | N_TO_ADDR_T | MK_DSTACK(DELTA_N1)))\
	X(RSHIFT, "rshift", true,  (OP_ALU_OP | MK_CODE(ALU_OP_N_RSHIFT_T)             | MK_DSTACK(DELTA_N1)))\
	X(LSHIFT, "lshift", true,  (OP_ALU_OP | MK_CODE(ALU_OP_N_LSHIFT_T)             | MK_DSTACK(DELTA_N1)))\
	X(EQUAL,  "=",      true,  (OP_ALU_OP | MK_CODE(ALU_OP_T_EQUAL_N)              | MK_DSTACK(DELTA_N1)))\
	X(ULESS,  "u<",     true,  (OP_ALU_OP | MK_CODE(ALU_OP_N_ULESS_T)              | MK_DSTACK(DELTA_N1)))\
	X(LESS,   "<",      true,  (OP_ALU_OP | MK_CODE(ALU_OP_N_LESS_T)               | MK_DSTACK(DELTA_N1)))\
	X(AND,    "and",    true,  (OP_ALU_OP | MK_CODE(ALU_OP_T_AND_N)                | MK_DSTACK(DELTA_N1)))\
	X(XOR,    "xor",    true,  (OP_ALU_OP | MK_CODE(ALU_OP_T_XOR_N)                | MK_DSTACK(DELTA_N1)))\
	X(OR,     "or",     true,  (OP_ALU_OP | MK_CODE(ALU_OP_T_OR_N)                 | MK_DSTACK(DELTA_N1)))\
	X(DEPTH,  "sp@",    true,  (OP_ALU_OP | MK_CODE(ALU_OP_DEPTH)   | T_TO_N       | MK_DSTACK(DELTA_1)))\
	X(T_N1,   "1-",     true,  (OP_ALU_OP | MK_CODE(ALU_OP_T_DECREMENT)))\
	X(RDEPTH, "rp@",    true,  (OP_ALU_OP | MK_CODE(ALU_OP_RDEPTH)  | T_TO_N       | MK_DSTACK(DELTA_1)))\
	X(TE0,    "0=",     true,  (OP_ALU_OP | MK_CODE(ALU_OP_T_EQUAL_0)))\
	X(NOP,    "nop",    false, (OP_ALU_OP | MK_CODE(ALU_OP_T)))\
	X(BYE,    "(bye)",  false, (OP_ALU_OP | MK_CODE(ALU_OP_BYE)                    | MK_DSTACK(DELTA_N1)))\
	X(RX,     "_rx?",   true,  (OP_ALU_OP | MK_CODE(ALU_OP_RX)      | T_TO_N       | MK_DSTACK(DELTA_1)))\
	X(TX,     "_tx!",   true,  (OP_ALU_OP | MK_CODE(ALU_OP_TX)                     | MK_DSTACK(DELTA_N1)))\
	X(SAVE,   "save",   true,  (OP_ALU_OP | MK_CODE(ALU_OP_SAVE)))\
	X(RUP,    "rup",    false, (OP_ALU_OP | MK_CODE(ALU_OP_T))                     | MK_RSTACK(DELTA_1))\
	X(RDROP,  "rdrop",  true,  (OP_ALU_OP | MK_CODE(ALU_OP_T) | MK_RSTACK(DELTA_N1)))


typedef enum {
#define X(NAME, STRING, DEFINE, INSTRUCTION) CODE_ ## NAME = INSTRUCTION,
	X_MACRO_INSTRUCTIONS
#undef X
} forth_word_codes_e;




#endif
