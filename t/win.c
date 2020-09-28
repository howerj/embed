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
 * terminal. This project, and the embed library, were compiled and tested with
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

#define EOT    (4)  /**< ASCII End Of Transmission */
#define ESCAPE (27) /**< ASCII Escape Character */

static bool a_tty = false;

static int getch_wrapper(bool *eagain) {
	bool again = false;
	int ch = EOF;
	if (kbhit())
		ch = getch();
	else
		again = true;
	*eagain = again;
	return ch;
}

static int win_getch(void *file, int *no_data) {
	assert(no_data); /*zero is a valid file descriptor*/
	FILE *in = file;
	if (!a_tty) {
		assert(in);
		*no_data = 0;
		return fgetc(in);
	}
	bool eagain = false;
	int r = getch_wrapper(&eagain);
	*no_data = eagain ? -1 : 0;
	r = (r == ESCAPE) || (r == EOT) ? EOF : r;
	return r;
}

static int win_putch(int ch, void *file) {
	const int r = fputc(ch, file);
	fflush(file);
	return r;
}

static void binary(FILE *f) {
	_setmode(_fileno(f), _O_BINARY);
}

int main(void) {
	int r;
	embed_vm_option_e options = 0;
	FILE *in = stdin;
	binary(stdin);
	binary(stdout);
	binary(stderr);

	if (_isatty(_fileno(stdin))) {
		embed_info("TTY RAW/NO-BLOCKING - UART Simulation");
		embed_info("Hit ESCAPE or type 'bye' to quit");
		options |= EMBED_VM_RAW_TERMINAL;
		a_tty = true;
		in = NULL;
	} else {
		embed_info("NOT A TTY");
		options |= EMBED_VM_QUITE_ON;
	}

	embed_opt_t o = embed_opt_default_hosted();
	o.get      = win_getch,     o.put   = win_putch,
	o.in       = in,            o.out   = stdout,
	o.options  = options;

	embed_t *h = embed_new();
	if (!h)
		embed_fatal("embed: allocate failed");
	embed_opt_set(h, &o);

	for (r = 0; (r = embed_vm(h)) > 0; Sleep(10/*milliseconds*/))
		/*fputc('.', stdout)*/ /*do nothing*/;
	return r;
}

