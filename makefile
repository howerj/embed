CFLAGS= -O2 -std=c99 -g -Wall -Wextra
CC=gcc
EXE=
DF=
EFORTH=eforth.blk
META1=meta1.blk
META2=meta2.blk
TEMP=tmp.blk
TARGET=embed
CMP=cmp
RM=rm -fv

.PHONY: all clean run cross cross-run double-cross default tests docs

default: all

ifeq ($(OS),Windows_NT)
DF=
EXE=.exe
.PHONY: ${TARGET}
else # assume unixen
DF=./
EXE=
endif

FORTH=${TARGET}${EXE}

all: ${FORTH}

${FORTH}: embed.c embed.h
	${CC} ${CFLAGS} -DUSE_EMBED_MAIN $< -o $@

${META1}: ${FORTH} ${EFORTH} meta.fth
	${DF}${FORTH} ${EFORTH} ${META1} meta.fth

${META2}: ${FORTH} ${META1} meta.fth
	${DF}${FORTH} ${META1} ${META2} meta.fth

cross: ${META1}

double-cross: ${META2}

run: ${FORTH} ${EFORTH}
	${DF}${FORTH} ${EFORTH} ${TEMP}

cross-run: cross
	${DF}${FORTH} ${META1} ${TEMP}

cross-tests: cross unit.fth
	${DF}${FORTH} ${META1} ${TEMP} unit.fth

tests: ${FORTH} ${META1} unit.fth
	${DF}${FORTH} ${META1} ${TEMP} unit.fth

libembed.a: embed.o
	ar rcs $@ $<

%.pdf: %.md
	pandoc -V geometry:margin=0.5in --toc $< -o $@

%.md: %.fth convert
	./convert $< > $@

%.htm: %.md convert
	markdown $< > $@

view: meta.pdf
	mupdf $< &>/dev/null&

docs: meta.pdf meta.htm

clean:
	${RM} ${FORTH} ${META1} ${META2} ${TEMP} *.o *.a *.pdf *.htm

