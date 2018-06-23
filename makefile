# Embed Virtual Machine Makefile
#
# Targets:
# 	- Unix (Linux Tested)
# 	- Windows (Using MinGW)

CFLAGS= -O2 -std=c99 -g -Wall -Wextra -fwrapv -fPIC -pedantic -I.
CC=gcc
EXE=
DF=
META1=embed-1.blk
META2=embed-2.blk
TEMP=tmp.blk
UNIT=unit.blk
TARGET=embed
CMP=cmp
AR=ar
ARFLAGS=rcs
RM=rm -fv
TESTAPPS=cpp ref

.PHONY: all clean run cross double-cross default tests docs apps dist

default: all

ifeq ($(OS),Windows_NT)
DF=
EXE=.exe
.PHONY: ${TARGET}
else # assume unixen
DF=./
EXE=
TESTAPPS+= dlopen eforth unix
endif

FORTH=${TARGET}${EXE}
B2C=b2c${EXE}

all: ${FORTH}

${B2C}: t/b2c.o embed.o
	${CC} ${CFLAGS} $^ -o $@

core.gen.c: ${B2C} embed-1.blk
	${DF}${B2C} embed_default_block embed-1.blk $@ "eForth Image"

lib${TARGET}.a: ${TARGET}.o image.o
	${AR} ${ARFLAGS} $@ $^

lib${TARGET}.so: ${TARGET}.o image.o
	${CC} -shared -o $@ $^

${FORTH}: main.o lib${TARGET}.a ${TARGET}.h
	${CC} $^ ${LDFLAGS} -o $@

### Meta Compilation ######################################################### 

${META1}: ${FORTH} embed.fth
	${DF}${FORTH} -o ${META1} embed.fth

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

### Release Distribution ##################################################### 

dist: lib${TARGET}.so lib${TARGET}.a ${TARGET}.pdf embed.1 ${FORTH} ${TARGET}.h embed.blk
	tar zcf ${TARGET}.tgz $^

### Test Applications ######################################################## 

dlopen: t/dlopen.c libembed.so
	${CC} ${CFLAGS} $< -ldl -o $@

cpp: t/cpp.cpp libembed.a
	${CXX} ${CPPFLAGS} -I. -o $@ $^

eforth: CC=musl-gcc
eforth: CFLAGS=-Wall -Wextra -Os -fno-stack-protector -static -std=c99 -DNDEBUG
eforth: LDFLAGS=-Wl,-O1
eforth: embed.c image.c main.c
	${CC} ${CFLAGS} $^ -o $@
	strip $@

ref: t/ref.c
	${CC} ${CFLAGS} $< -o $@

unix: t/unix.c libembed.a
	${CC} ${CFLAGS} $^ -o $@

apps: ${TESTAPPS}

### Cleanup ################################################################## 

clean:
	${RM} ${FORTH} ${META1} ${META2} ${TEMP} ${UNIT} ${B2C}
	${RM} *.o *.a *.so *.pdf *.htm
	${RM} *.gen.c
	${RM} *.tgz
	${RM} ${TESTAPPS}

### EOF ###################################################################### 

