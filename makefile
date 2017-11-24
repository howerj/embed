CFLAGS=-O2 -std=c99 -Wall -Wextra
CC=gcc
EXE=
DF=
EFORTH=eforth.blk
META=meta1.blk
XX=meta2.blk


.PHONY: all clean run cross cross-run double-cross default static

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

tron: CFLAGS+=-DTRON
tron: ${FORTH}

static: CC=musl-gcc
static: CFLAGS+=-static
static: ${FORTH}
	strip ${FORTH}

clean:
	rm -fv ${COMPILER} ${FORTH} ${META} ${XX}
