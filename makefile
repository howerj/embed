CFLAGS=-std=c99 -Wall -Wextra
CC=gcc

all: embed

block: block.c

%.blk: %.txt block
	./block < $< > $@

embed: h2.c h2.h
	${CC} ${CFLAGS} $< -o $@

run: nvram.blk embed
	./embed -R h2.fth
