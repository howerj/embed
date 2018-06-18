
CFLAGS= -O2 -std=c99 -g -Wall -Wextra -fwrapv
LDFLAGS=-Wl,-O1
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
AR=ar
ARFLAGS=rcs
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
B2C=b2c${EXE}

all: ${FORTH}

${B2C}: b2c.o embed.o
	${CC} $^ -o $@

core.gen.c: ${B2C} embed.blk
	${DF}${B2C} embed_default_block embed.blk $@

lib${TARGET}.a: ${TARGET}.o core.gen.o
	${AR} ${ARFLAGS} $@ $^

${FORTH}: main.o lib${TARGET}.a ${TARGET}.h

${META1}: ${FORTH} ${EFORTH} embed.fth
	${DF}${FORTH} ${META1} ${EFORTH} embed.fth

${META2}: ${FORTH} ${META1} embed.fth
	${DF}${FORTH} ${META2} ${META1} embed.fth

cross: ${META1}

double-cross: ${META2}
	${CMP} ${META1} ${META2}

run: cross
	${DF}${FORTH} ${TEMP} ${META1}

tests: ${UNIT}

	
${UNIT}: ${FORTH} ${META1} unit.fth
	${DF}${FORTH} ${UNIT} ${META1} unit.fth

floats: ${UNIT}
	${DF}${FORTH} ${TEMP} ${UNIT}

%.pdf: %.md
	pandoc -V geometry:margin=0.5in --toc $< -o $@

%.md: %.fth convert
	${DF}convert $< > $@

%.htm: %.md convert
	markdown $< > $@

view: ${TARGET}.pdf
	mupdf $< &>/dev/null&

docs: ${TARGET}.pdf ${TARGET}.htm

clean:
	${RM} ${FORTH} ${META1} ${META2} ${TEMP} ${UNIT} ${B2C}
	${RM} *.o *.a *.pdf *.htm
	${RM} *.gen.c

