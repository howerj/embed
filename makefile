# Embed Virtual Machine Makefile
#
# Targets:
# 	- Unix (Linux Tested)
# 	- Windows (Using MinGW)

CFLAGS= -O2 -std=c99 -g -Wall -Wextra -fwrapv -fPIC -pedantic -I. -Wmissing-prototypes
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
TESTAPPS=cpp call mmu rom ref
TRACER=

.PHONY: all clean run cross double-cross default test docs apps dist check

default: all

ifeq ($(OS),Windows_NT)
DF=
EXE=.exe
TESTAPPS+= win
.PHONY: ${TARGET}
else # assume unixen
DF=./
EXE=
TESTAPPS+= unix
endif

FORTH=${TARGET}${EXE}

all: ${FORTH}

embed.o: embed.c embed.h

util.o: util.c util.h

lib${TARGET}.a: ${TARGET}.o image.o
	${AR} ${ARFLAGS} $@ $^

lib${TARGET}.so: ${TARGET}.o image.o
	${CC} -shared -o $@ $^

${FORTH}: main.o util.o lib${TARGET}.a 
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
	${TRACER} ${DF}${FORTH} -o ${TEMP} -i ${META1}

### Unit Tests ############################################################### 

${UNIT}: ${FORTH} ${META1} t/unit.fth
	${DF}${FORTH} -o ${UNIT} -i ${META1} t/unit.fth

unit: t/unit.c util.o libembed.a
	${CC} ${CFLAGS} $^ -o $@

test: unit ${UNIT}
	${DF}unit${EXE}

### Static Code Analysis ##################################################### 

check:
	cppcheck --std=c99 -I. --enable=warning,style,performance,portability,information,missingInclude *.c t/*.c

### Documentation ############################################################ 

%.pdf: %.md
	pandoc -V geometry:margin=0.5in --toc $< -o $@

%.md: %.fth t/convert
	t/${DF}convert $< > $@

%.htm: %.md t/convert
	markdown $< > $@

docs: ${TARGET}.pdf ${TARGET}.htm

### Release Distribution ##################################################### 

embed.blk: embed-1.blk
	cp $< $@

dist: lib${TARGET}.so lib${TARGET}.a ${TARGET}.pdf embed.1 ${FORTH} ${TARGET}.h embed.blk
	tar zcf ${TARGET}.tgz $^

### Test Applications ######################################################## 

cpp: t/cpp.cpp t/embed.hpp util.o libembed.a
	${CXX} ${CPPFLAGS} -I. -It -o $@ $^

eforth: CC=musl-gcc
eforth: CFLAGS=-Wall -Wextra -Os -fno-stack-protector -static -std=c99 -DNDEBUG 
eforth: LDFLAGS=-Wl,-O1
eforth: embed.c image.c util.c main.c
	${CC} ${CFLAGS} $^ -o $@
	strip $@

unix: CFLAGS=-O2 -Wall -Wextra -std=gnu99 -I.
unix: t/unix.c util.o libembed.a
	${CC} ${CFLAGS} $^ -o $@

win: CFLAGS=-Wall -Wextra -std=gnu99 -I.
win: t/win.c util.o libembed.a
	${CC} ${CFLAGS} $^ -o $@

call: CFLAGS=-O3 -Wall -Wextra -std=c99 -I.
call: t/call.c util.o libembed.a
	${CC} ${CFLAGS} $^ -lm -o $@

mmu: CFLAGS=-O2 -Wall -Wextra -std=c99 -I.
mmu: t/mmu.c util.o libembed.a 
	${CC} ${CFLAGS} $^ -o $@

rom: CFLAGS=-O2 -Wall -Wextra -std=c99 -I. -g
rom: t/rom.c util.o libembed.a 
	${CC} ${CFLAGS} $^ -o $@

ref: t/ref.c embed.blk
	${CC} ${CFLAGS} $< -o $@

b2c.blk: embed b2c.fth embed-1.blk
	./$< -i embed-1.blk -o $@ b2c.fth

core.gen.c: embed b2c.blk 
	./$< -i b2c.blk < embed-1.blk > $@

apps: ${TESTAPPS}

### Cleanup ################################################################## 

clean:
	${RM} ${FORTH} *.blk ${B2C}
	${RM} *.o *.a *.so *.pdf *.htm *.log
	${RM} *.gen.c
	${RM} *.tgz
	${RM} *.bin
	${RM} ${TESTAPPS} eforth unit

### EOF ###################################################################### 

