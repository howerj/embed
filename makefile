CFLAGS=-O3 -std=c99 -Wall -Wextra
CC=gcc

all: forth forth.blk

compiler: compiler.c
	${CC} ${CFLAGS} $< -o $@

forth: forth.c
	${CC} ${CFLAGS} $< -o $@

forth.blk: compiler eforth.fth
	./$^

run: forth forth.blk
	./forth

clean:
	rm -fv compiler forth
