#include "embed.h"

#include <assert.h>
#include <conio.h>
#include <errno.h>
#include <fcntl.h>
#include <io.h>
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>

static int getch_wrapper(int fd, bool *eagain) /* Set terminal to raw mode */
{
	bool again = false;
	int ch = EOF;
	if(kbhit())
		ch = getch();
	else
		*eagain = true;
	*eagain = again;
	return ch;
}

static int win_getch(void *file, int *no_data)
{
	assert(no_data); /*zero is a valid file descriptor*/
	int fd = (int)(intptr_t)file;
	bool eagain = false;
	int r = getch_wrapper(fd, &eagain);
	*no_data = eagain ? -1 : 0;
	return r;
}

static int win_putch(int ch, void *file)
{
	int r = fputc(ch, file);
	fflush(file);
	return r;
}

int main(void)
{
	int r;
	embed_vm_option_e options = 0;

	//if(isatty(fd)) {
		fprintf(stdout, "TTY RAW/NO-BLOCKING - UART Simulation\n");
		options |= EMBED_VM_RX_NON_BLOCKING | EMBED_VM_RAW_TERMINAL;
	//} else {
	//	fprintf(stdout, "NOT A TTY\n");
	//}

	embed_opt_t o = {
		.get      = win_getch, .put   = win_putch, .save = embed_save_cb,
		.in       = 0,         .out   = stdout,    .name = NULL, 
		.callback = NULL,      .param = NULL,
		.options  = options
	};

	embed_t *h = embed_new();
	if(!h)
		embed_fatal("embed: allocate failed");
	/**@todo fix yield in Forth image so this works */
	for(r = 0; (r = embed_vm(h, &o)) > 0; /*usleep(10 * 1000uLL)*/)
		;
	return r;
}

