CFLAGS=-std=c99 -Wall -Wextra
RM=rm -rfv
SRCS := $(wildcard *.c)
OBJS := $(SRCS:.c=.o)
TARGET := forth
ARCHIVE = custom-embed

all: ${TARGET}

${TARGET}: ${OBJS}
	${CC} ${CFLAGS} $^ -o $@

run: ${TARGET}
	./${TARGET}

${ARCHIVE}: ${SRCS} *.blk *.h makefile
	mkdir -p $@
	cp -v $^ $@

%.tgz: %
	tar zcvf $@ $<

dist: ${ARCHIVE}.tgz

clean:
	${RM} *.o
	${RM} *.tgz
	${RM} ${TARGET} ${ARCHIVE}
