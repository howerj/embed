
CFLAGS= -O2 -std=c99 -g -Wall -Wextra -fwrapv -fPIC
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

.PHONY: all clean run cross double-cross default tests docs 

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

lib${TARGET}.so: ${TARGET}.o core.gen.o
	${CC} -shared -o $@ $^

${FORTH}: main.o lib${TARGET}.a ${TARGET}.h
	${CC} $^ ${LDFLAGS} -o $@

${META1}: ${FORTH} ${EFORTH} embed.fth
	${DF}${FORTH} -o ${META1} -i ${EFORTH} embed.fth

${META2}: ${FORTH} ${META1} embed.fth
	${DF}${FORTH} -o ${META2} -i ${META1} embed.fth

dlopen: CFLAGS+=-I.
dlopen: t/dlopen.c libembed.so
	${CC} ${CFLAGS} $< -ldl -o $@

cross: ${META1}

double-cross: ${META2}
	${CMP} ${META1} ${META2}

run: cross
	${DF}${FORTH} -o ${TEMP} -i ${META1}

${UNIT}: ${FORTH} ${META1} t/unit.fth
	${DF}${FORTH} -o ${UNIT} -i ${META1} t/unit.fth

tests: ${UNIT}
	
%.pdf: %.md
	pandoc -V geometry:margin=0.5in --toc $< -o $@

%.md: %.fth t/convert
	t/${DF}convert $< > $@

%.htm: %.md t/convert
	markdown $< > $@

docs: ${TARGET}.pdf ${TARGET}.htm

static: CC=musl-gcc
static: CFLAGS=-Wall -Wextra -Os -fno-stack-protector -static -std=c99
static: LDFLAGS=-Wl,-O1
static: embed.c core.gen.c main.c
	${CC} ${CFLAGS} $^ -o $@
	strip $@

clean:
	${RM} ${FORTH} ${META1} ${META2} ${TEMP} ${UNIT} ${B2C}
	${RM} *.o *.a *.so *.pdf *.htm
	${RM} *.gen.c
	${RM} dlopen
	${RM} static

