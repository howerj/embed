CFLAGS=-O2 -std=c99 -g -Wall -Wextra
CC=gcc
EXE=
DF=
EFORTH=eforth.blk
META1=meta1.blk
META2=meta2.blk
TEMP=tmp.blk

.PHONY: all clean run cross cross-run double-cross default static tests 

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

embed.o: embed.c embed.h

${FORTH}: main.o embed.o embed.h
	${CC} ${CFLAGS} $^ -o $@

run: ${FORTH} ${EFORTH}
	${DF}${FORTH} i ${EFORTH} new.blk

${META1}: ${FORTH} ${EFORTH} meta.fth
	${DF}${FORTH} f ${EFORTH} ${META1} meta.fth

cross: ${META1}

cross-run: cross
	${DF}${FORTH} i ${META1} ${META1}

double-cross: cross
	${DF}${FORTH} f ${META1} ${META2} meta.fth
	cmp ${META1} ${META2}

tests: ${FORTH} ${META1} unit.fth
	${DF}${FORTH} f ${META1} ${TEMP} unit.fth

tron: CFLAGS += -DTRON
tron: main.c embed.c embed.h
	${CC} ${CFLAGS} $^ -o $@

static: CC = musl-gcc
static: CFLAGS += -static
static: ${FORTH}
	strip ${FORTH}

small: embed.o small.o

clean:
	rm -fv ${COMPILER} ${FORTH} ${META1} ${META2} ${SIMPLE} ${TRON} *.o

