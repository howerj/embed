CFLAGS=-O2 -std=c99 -Wall -Wextra
CC=gcc
EXE=
DF=
EFORTH=eforth.blk
META=meta1.blk
XX=meta2.blk
TEMP=tmp.blk

.PHONY: all clean run cross cross-run double-cross default static tests more sokoban life

default: all

ifeq ($(OS),Windows_NT)
DF=
EXE=.exe
.PHONY: forth compiler
forth:  ${FORTH}
else # assume unixen
DF=./
EXE=
endif

FORTH=forth${EXE}

all: ${FORTH}

${FORTH}: forth.c
	${CC} ${CFLAGS} $< -o $@

run: ${FORTH} ${EFORTH}
	${DF}${FORTH} i ${EFORTH} new.blk

${META}: ${FORTH} ${EFORTH} meta.fth
	${DF}${FORTH} f ${EFORTH} ${META} meta.fth

cross: ${META}

cross-run: cross
	${DF}${FORTH} i ${META} ${META}

double-cross: cross
	${DF}${FORTH} f ${META} ${XX} meta.fth
	cmp ${META} ${XX}

tests: ${FORTH} ${META} unit.fth
	${DF}${FORTH} f ${META} ${TEMP} unit.fth

tron: CFLAGS += -DTRON
tron: forth.c
	${CC} ${CFLAGS} $< -o $@

more: cross
	${DF}${FORTH} i ${META} ${XX} more.fth

static: CC = musl-gcc
static: CFLAGS += -static
static: ${FORTH}
	strip ${FORTH}

sokoban: ${FORTH} ${EFORTH} sokoban.fth
	${DF}${FORTH} i ${EFORTH} new.blk sokoban.fth

life: ${FORTH} ${EFORTH} life.fth
	${DF}${FORTH} i ${EFORTH} new.blk life.fth

clean:
	rm -fv ${COMPILER} ${FORTH} ${META} ${XX}
