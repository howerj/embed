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
TESTAPPS=call mmu rom
TRACER=

.PHONY: all clean run cross double-cross default test docs apps dist check BIST

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

### New Image Creation (renamed core.gen.c to image.c) ####################### 

b2c.blk: ${TARGET} b2c.fth embed-1.blk
	${DF}$< -i embed-1.blk -o $@ b2c.fth

core.gen.c: embed b2c.blk 
	./$< -i b2c.blk -I embed-1.blk -O $@

### Meta Compilation ######################################################### 

${META1}: ${FORTH} embed.fth
	${DF}${FORTH} -o ${META1} embed.fth

cross: ${META1}

run: cross ref
	${DF}ref ${META1}

### Unit Tests ############################################################### 

${UNIT}: ${FORTH} ${META1} t/unit.fth
	${DF}${FORTH} -o ${UNIT} -i ${META1} t/unit.fth

# Built in self tests
BIST: ${FORTH}
	${DF}${FORTH} -T

test: BIST ${UNIT}

### Release Distribution ##################################################### 

embed.blk: embed-1.blk
	cp $< $@


### Cleanup ################################################################## 

clean:
	${RM} ${FORTH} *.blk ref
	${RM} *.o *.a *.so *.pdf *.htm *.log
	${RM} *.gen.c *.tgz *.bin

### EOF ###################################################################### 

