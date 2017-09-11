CFLAGS=-O3 -std=c99 -Wall -Wextra
CC=gcc

all: embed

embed: h2.c h2.h
	${CC} ${CFLAGS} $< -o $@

forth.blk: embed h2.fth
	./$^

run: forth.blk
	./embed
