# Embed Virtual Machine Makefile
#
# Targets:
# 	- Unix (Linux Tested)
# 	- Windows (Using MinGW)

CFLAGS= -O2 -std=c99 -g -Wall -Wextra -fwrapv -fPIC -pedantic -I.
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
TESTAPPS=cpp simple eforth

.PHONY: all clean run cross double-cross default tests docs apps

default: all

ifeq ($(OS),Windows_NT)
DF=
EXE=.exe
.PHONY: ${TARGET}
else # assume unixen
DF=./
EXE=
TESTAPPS+= dlopen
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

### Meta Compilation ######################################################### 

${META1}: ${FORTH} ${EFORTH} embed.fth
	${DF}${FORTH} -o ${META1} -i ${EFORTH} embed.fth

${META2}: ${FORTH} ${META1} embed.fth
	${DF}${FORTH} -o ${META2} -i ${META1} embed.fth

cross: ${META1}

double-cross: ${META2}
	${CMP} ${META1} ${META2}

run: cross
	${DF}${FORTH} -o ${TEMP} -i ${META1}

### Unit Tests ############################################################### 

${UNIT}: ${FORTH} ${META1} t/unit.fth
	${DF}${FORTH} -o ${UNIT} -i ${META1} t/unit.fth

tests: ${UNIT}

### Documentation ############################################################ 

%.pdf: %.md
	pandoc -V geometry:margin=0.5in --toc $< -o $@

%.md: %.fth t/convert
	t/${DF}convert $< > $@

%.htm: %.md t/convert
	markdown $< > $@

docs: ${TARGET}.pdf ${TARGET}.htm

### Test Applications ######################################################## 

dlopen: t/dlopen.c libembed.so
	${CC} ${CFLAGS} $< -ldl -o $@

cpp: t/cpp.cpp libembed.a
	${CXX} ${CPPFLAGS} -I. -o $@ $^

eforth: CC=musl-gcc
eforth: CFLAGS=-Wall -Wextra -Os -fno-stack-protector -static -std=c99
eforth: LDFLAGS=-Wl,-O1
eforth: embed.c core.gen.c main.c
	${CC} ${CFLAGS} $^ -o $@
	strip $@

simple: CFLAGS+=-DEMBED_H
simple: embed.c
	${CC} ${CFLAGS} $< -o $@

apps: ${TESTAPPS}

### Cleanup ################################################################## 

clean:
	${RM} ${FORTH} ${META1} ${META2} ${TEMP} ${UNIT} ${B2C}
	${RM} *.o *.a *.so *.pdf *.htm
	${RM} *.gen.c
	${RM} ${TESTAPPS}

### EOF ###################################################################### 

