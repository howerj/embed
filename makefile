CFLAGS=-O2 -std=c99 -Wall -Wextra
CC=gcc

.PHONY: all clean run cross cross-run static

all: forth eforth.blk

compiler: compiler.c
	${CC} ${CFLAGS} $< -o $@

forth: forth.c
	${CC} ${CFLAGS} $< -o $@

%.blk: compiler %.fth
	./$^ $@

run: forth eforth.blk
	./forth i eforth.blk new.blk

new.blk: forth eforth.fth meta.fth
	./forth f eforth.blk new.blk meta.fth

cross: new.blk
	xxd new.blk

cross-run: cross
	./forth i new.blk new.blk

static: CC=musl-gcc
static: CFLAGS+=-static
static: forth 
	strip forth

clean:
	rm -fv compiler forth
