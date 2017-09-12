CFLAGS=-Os -std=c99 -Wall -Wextra
CC=gcc

.PHONY: clean all run static

all: forth forth.blk

compiler: compiler.c
	${CC} ${CFLAGS} $< -o $@

forth: forth.c
	${CC} ${CFLAGS} $< -o $@

forth.blk: compiler eforth.fth
	./$^

run: forth forth.blk
	./forth

static: CC=musl-gcc
static: CFLAGS+=-static
static: forth 
	strip forth

clean:
	rm -fv compiler forth
