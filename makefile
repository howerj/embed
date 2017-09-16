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
	./$^

image.inc: forth eforth.blk programs/dump.fth
	./$^ > $@

all-in-one: image.inc
	${CC} ${CFLAGS} -DALL_IN_ONE forth.c -o $@


static: CC=musl-gcc
static: CFLAGS+=-static
static: forth 
	strip forth

clean:
	rm -fv compiler forth
