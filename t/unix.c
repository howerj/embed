#include "embed.h"

#define _POSIX_C_SOURCE 200809L
#include <assert.h>
#include <stdbool.h>
#include <termios.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <string.h>
#include <stdlib.h>

static struct termios old, new;
static int fd = -1;

static int getch(int fd, bool *eagain) /* Set terminal to raw mode */
{
	uint8_t b = 0;
	bool again = false;
	errno = 0;
	int r = read(fd, &b, 1);
	if(r < 0)
		again = errno == EAGAIN || errno == EWOULDBLOCK;
	*eagain = again;
	return r == 1 ? (int)b : EOF;
}

static int raw(int fd)
{
	errno = 0;
	if(tcgetattr(fd, &old) < 0)
		return -1;
	new          = old;
	new.c_iflag &= ~(ICRNL);
	new.c_lflag &= ~(ICANON | ECHO);
	/* fprintf(stdout, "erase = %u\n", (unsigned)old.c_cc[VERASE]); */
	errno = 0;
	if(tcsetattr(fd, TCSANOW, &new) < 0)
		return -1;
	errno = 0;
	if(fcntl(fd, F_SETFL, fcntl(fd, F_GETFL) | O_NONBLOCK) < 0)
		return -1;
	return 0;
}

static void cooked(void)
{
	tcsetattr(fd, TCSANOW, &old);
}

static int unix_getch(void *file)
{
	int fd = (int)(intptr_t)file;
	bool eagain = false;
	return getch(fd, &eagain);
}

static int unix_putch(int ch, void *file)
{
	int r = fputc(ch, file);
	fflush(file);
	return r;
}

int main(void)
{
	int r;
	embed_vm_option_e options = 0;

	fd = STDIN_FILENO;
	if(isatty(fd)) {
		fprintf(stdout, "TTY RAW/NO-BLOCKING - UART Simulation\n");
		options |= EMBED_VM_RX_NON_BLOCKING | EMBED_VM_RAW_TERMINAL;
		if(raw(fd) < 0)
			embed_fatal("failed to set terminal attributes: %s", strerror(errno));
		atexit(cooked);
	} else {
		fprintf(stdout, "NOT A TTY\n");
	}

	embed_opt_t o = {
		.get      = unix_getch,           .put   = unix_putch, .save = embed_save_cb,
		.in       = (void*)(intptr_t)fd,  .out   = stdout,     .name = NULL, 
		.callback = NULL,                 .param = NULL,
		.options  = options
	};

	embed_t *h = embed_new();
	/**@todo fix yield in Forth image so this works */
	if(embed_load_buffer(h, embed_default_block, embed_default_block_size) < 0)
		embed_fatal("embed: load failed");
	for(r = 0; (r = embed_vm(h, &o)) > 0; usleep(10 * 1000uLL))
		;
	return r;
}

