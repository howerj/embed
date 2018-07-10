/**@brief Windows non-blocking input mode simulation for the Embed library
 * @file    win.c
 * @author  Richard James Howe
 * @license MIT
 *
 * See <https://github.com/howerj/embed>
 *
 * This is the Windows version of the 'unix.c' test program for non-blocking
 * input. For a description of how this program is meant to work, refer to the
 * 'unix.c' test program, it is essential identical except it uses Windows
 * terminal handling routines. Also note, Windows is picky as to what it
 * considers a terminal, the program is liable to only work correctly when run
 * under 'cmd.exe', or at least not detect that a user is reading input from a
 * terminal. This project, and the embed library, were compile and tested with
 * MinGW. */

#include "embed.h"
#include "util.h"
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

static int getch_wrapper(bool *eagain) {
	bool again = false;
	int ch = EOF;
	if(kbhit())
		ch = getch();
	else
		*eagain = true;
	*eagain = again;
	return ch;
}

static int win_getch(void *file, int *no_data) {
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

static int win_putch(int ch, void *file) {
	int r = fputc(ch, file);
	fflush(file);
	return r;
}

int main(void) {
	int r;
	embed_vm_option_e options = 0;
	FILE *in = stdin;

	if(_isatty(_fileno(stdin))) {
		embed_info("TTY RAW/NO-BLOCKING - UART Simulation");
		options |= EMBED_VM_RAW_TERMINAL;
		a_tty = true;
		in = NULL;
	} else {
		embed_info("NOT A TTY");
	}

	embed_opt_t o = embed_opt_default();
	o.get      = unix_getch,           o.put   = unix_putch, o.save = embed_save_cb,
	o.in       = (void*)(intptr_t)fd,  o.out   = out,
	o.options  = options;

	embed_t *h = embed_new();
	embed_opt_set(h, o);

	embed_t *h = embed_new();
	if(!h)
		embed_fatal("embed: allocate failed");
	for(r = 0; (r = embed_vm(h)) > 0; Sleep(10/*milliseconds*/))
		/*fputc('.', stdout)*/ /*do nothing*/;
	return r;
}

