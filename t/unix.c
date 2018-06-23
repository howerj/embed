#include "embed.h"

#define _POSIX_C_SOURCE 200809L
#include <stdbool.h>
#include <termios.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <string.h>
#include <stdlib.h>

static struct termios old, new;
static int fd = -1;

static int getch(int fd) /* Set terminal to raw mode */
{
	uint8_t b = 0;
	int r = read(fd, &b, 1); /**@todo check errno against EAGAIN and EWOULDBLOCK, and indicate non-blocking versus EOF */
	//return getchar();
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
	return getch(fd);
}

int main(void)
{
	embed_vm_status_e options = 0;

	fd = STDIN_FILENO;
	if(isatty(fd)) {
		fprintf(stdout, "TTY\n");
		options = EMBED_VM_RX_NON_BLOCKING | EMBED_VM_RAW_TERMINAL;
		if(raw(fd) < 0)
			embed_die("failed to set terminal attributes: %s", strerror(errno));
		atexit(cooked);
	}

	embed_opt_t o = {
		.get      = unix_getch,           .put   = embed_fputc_cb, .save = embed_save_cb,
		.in       = (void*)(intptr_t)fd,  .out   = stdout,         .name = NULL, 
		.callback = NULL,                 .param = NULL,
		.options  = options
	};

	embed_t *h = embed_new();
	if(embed_load_buffer(h, embed_default_block, embed_default_block_size) < 0)
		embed_die("embed: load failed");
	return embed_vm(h, &o);
}
