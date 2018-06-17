CFLAGS= -O2 -std=c99 -g -Wall -Wextra -fwrapv
CC=gcc
EXE=
DF=
EFORTH=embed.blk
META1=embed-1.blk
META2=embed-2.blk
TEMP=tmp.blk
UNIT=unit.blk
TARGET=embed
CMP=cmp
RM=rm -fv

.PHONY: all clean run cross double-cross default tests docs floats view

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
F2C=f2c${EXE}

all: ${FORTH}

${F2C}: f2c.o embed.o
	${CC} $^ -o $@

core.gen.c: ${F2C} embed.blk
	${DF}${F2C} embed_block embed.blk core.gen.c

${FORTH}: main.o embed.o core.gen.o embed.h

${META1}: ${FORTH} ${EFORTH} embed.fth
	${DF}${FORTH} ${EFORTH} ${META1} embed.fth

${META2}: ${FORTH} ${META1} embed.fth
	${DF}${FORTH} ${META1} ${META2} embed.fth

cross: ${META1}

double-cross: ${META2}
	${CMP} ${META1} ${META2}

run: cross
	${DF}${FORTH} ${META1}

tests: ${UNIT}

	
${UNIT}: ${FORTH} ${META1} unit.fth
	${DF}${FORTH} ${META1} ${UNIT} unit.fth

floats: ${UNIT}
	${DF}${FORTH} $<

libembed.a: embed.o
	ar rcs $@ $<

%.pdf: %.md
	pandoc -V geometry:margin=0.5in --toc $< -o $@

%.md: %.fth convert
	${DF}convert $< > $@

%.htm: %.md convert
	markdown $< > $@

view: meta.pdf
	mupdf $< &>/dev/null&

docs: meta.pdf meta.htm

clean:
	${RM} ${FORTH} ${META1} ${META2} ${TEMP} ${UNIT} ${F2C}
	${RM} *.o *.a *.pdf *.htm
	${RM} *.gen.c

