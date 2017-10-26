CFLAGS=-O2 -std=c99 -Wall -Wextra
CC=gcc

.PHONY: all clean run static

all: forth eforth.blk

compiler: compiler.c
	${CC} ${CFLAGS} $< -o $@

forth: forth.c
	${CC} ${CFLAGS} $< -o $@

%.blk: compiler %.fth
	./$^ $@

run: forth eforth.blk
	./forth i eforth.blk new.blk

static: CC=musl-gcc
static: CFLAGS+=-static
static: forth 
	strip forth

clean:
	rm -fv compiler forth
