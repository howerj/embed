#include "embed.h"

#include <assert.h>
#include <conio.h>
#include <errno.h>
#include <fcntl.h>
#include <io.h>
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>
#include <windows.h>

static bool a_tty = false;

static int getch_wrapper(bool *eagain)
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
	FILE *in = (FILE*)file;
	bool eagain = false;
	if(in) {
		*no_data = 0;
		return fgetc(in);
	}
	int r = getch_wrapper(&eagain);
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
	FILE *in = stdin;

	if(_isatty(_fileno(stdin))) {
		embed_info("TTY RAW/NO-BLOCKING - UART Simulation");
		options |= EMBED_VM_RX_NON_BLOCKING | EMBED_VM_RAW_TERMINAL;
		a_tty = true;
		in = NULL;
	} else {
		embed_info("NOT A TTY");
	}

	embed_opt_t o = {
		.get      = win_getch, .put   = win_putch, .save = embed_save_cb,
		.in       = in,        .out   = stdout,    .name = NULL, 
		.callback = NULL,      .param = NULL,
		.options  = options
	};

	embed_t *h = embed_new();
	if(!h)
		embed_fatal("embed: allocate failed");
	/**@todo fix yield in Forth image so this works */
	for(r = 0; (r = embed_vm(h, &o)) > 0; Sleep(10/*milliseconds*/))
		/*fputc('.', stdout)*/ /*do nothing*/;
	return r;
}

