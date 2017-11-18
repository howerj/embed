CFLAGS=-O2 -std=c99 -Wall -Wextra
CC=gcc
EXE=
DF=
.PHONY: all clean run cross cross-run default static

default: all

ifeq ($(OS),Windows_NT)
DF=
EXE=.exe
.PHONY: forth compiler
forth:  ${FORTH}
compiler: ${COMPILER}
else # assume unixen
DF=./
EXE=
endif

FORTH=forth${EXE}
COMPILER=compiler${EXE}

all: ${FORTH} eforth.blk

${COMPILER}: compiler.c
	${CC} ${CFLAGS} $< -o $@

${FORTH}: forth.c
	${CC} ${CFLAGS} $< -o $@

%.blk: ${COMPILER} %.fth
	${DF}$^ $@

run: ${FORTH} eforth.blk
	${DF}${FORTH} i eforth.blk new.blk

meta.blk: ${FORTH} eforth.blk meta.fth
	${DF}${FORTH} f eforth.blk meta.blk meta.fth

cross: meta.blk

cross-run: cross
	${DF}${FORTH} i meta.blk meta.blk

double-cross-run: cross
	${DF}${FORTH} f meta.blk xx.blk meta.fth
	cmp meta.blk xx.blk

static: CC=musl-gcc
static: CFLAGS+=-static
static: ${FORTH}
	strip ${FORTH}

clean:
	rm -fv ${COMPILER} ${FORTH} *.blk
