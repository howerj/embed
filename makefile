CFLAGS=-std=c99 -Wall -Wextra
CC=gcc

all: embed

embed: h2.c h2.h
	${CC} ${CFLAGS} $< -o $@

%.hex: %.fth embed
	./embed -a $< > $@

run: h2.hex embed
	./embed -r h2.hex
