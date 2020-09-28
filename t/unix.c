/**@brief Embed Unix UART simulation, for Unix
 * @license MIT
 * @author Richard James Howe
 * @file unix.c
 *
 * See <https://github.com/howerj/embed>
 *
 * This program demonstrates using the embed library with a non-blocking source
 * of keyboard input, this allows a virtual machine image to yield when it has
 * nothing to do. There is a Windows equivalent to this in a file called
 * 'win.c'.
 *
 * The program implements a custom callback that the virtual machine can use
 * which gets input from a file descriptor that might be a terminal, if it is,
 * then it will set that file descriptor into raw mode, and non-blocking mode
 * (which is separate from raw mode).
 *
 * In non blocking mode if the user has not hit a key the call back sets its
 * 'no_data' parameter to a non-zero value, indicating to the program running
 * under the virtual machine that there is no data - at this time. If the user
 * has hit a key, it returns the key value and 'no_data' should be set to zero.
 *
 * This program also tests that the default virtual machine image handles raw
 * mode correctly. Unlike handling a non-blocking input source, the virtual
 * machine needs to be told explicitly that the terminal is acting in raw mode.
 * This mode means that input is unbuffered and input characters are not echoed
 * back to the user by the terminal handling program - instead the eForth image
 * must echo back characters and handle character deletion.
 *
 * See <https://unix.stackexchange.com/questions/21752> for the difference
 * between 'raw' and 'cooked' modes. */

#include "embed.h"
#include "util.h"

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

#define EOT    (4)  /**< ASCII End Of Transmission */
#define ESCAPE (27) /**< ASCII Escape Character */

static int getch(int fd, bool *eagain) { /* Set terminal to raw mode */
	uint8_t b = 0;
	bool again = false;
	errno = 0;
	int r = read(fd, &b, 1);
	if (r < 0)
		again = errno == EAGAIN || errno == EWOULDBLOCK;
	*eagain = again;
	return r == 1 ? (int)b : EOF;
}

static int raw(int fd) {
	errno = 0;
	if (tcgetattr(fd, &old) < 0)
		return -1;
	new          = old;
	new.c_iflag &= ~(ICRNL);
	new.c_lflag &= ~(ICANON | ECHO);
	/* fprintf(stdout, "erase = %u\n", (unsigned)old.c_cc[VERASE]); */
	errno = 0;
	if (tcsetattr(fd, TCSANOW, &new) < 0)
		return -1;
	errno = 0;
	if (fcntl(fd, F_SETFL, fcntl(fd, F_GETFL) | O_NONBLOCK) < 0)
		return -1;
	return 0;
}

static void cooked(void) {
	tcsetattr(fd, TCSANOW, &old);
}

static int unix_getch(void *file, int *no_data) {
	assert(no_data); /*zero is a valid file descriptor*/
	int fd = (int)(intptr_t)file;
	bool eagain = false;
	int r = getch(fd, &eagain);
	*no_data = eagain ? -1 : 0;
	r = (r == ESCAPE || r == EOT) ? EOF : r;
	return r;
}

static int unix_putch(int ch, void *file) {
	int r = fputc(ch, file);
	fflush(file);
	return r;
}

int main(void) {
	int r;
	embed_vm_option_e options = 0;
	FILE *out = stdout;

	fd = STDIN_FILENO;
	if (isatty(fd)) {
		embed_info("TTY RAW/NO-BLOCKING - UART Simulation");
		embed_info("Hit ESCAPE or type 'bye' to quit");
		options |= EMBED_VM_RAW_TERMINAL;
		if (raw(fd) < 0)
			embed_fatal("failed to set terminal attributes: %s", strerror(errno));
		atexit(cooked);
	} else {
		embed_info("NOT A TTY");
		options |= EMBED_VM_QUITE_ON;
	}

	embed_opt_t o = embed_opt_default_hosted();
	o.get      = unix_getch,           o.put   = unix_putch, o.save = embed_save_cb,
	o.in       = (void*)(intptr_t)fd,  o.out   = out,
	o.options  = options;

	embed_t *h = embed_new();
	if (!h)
		embed_fatal("embed: allocate failed");
	embed_opt_set(h, &o);
	/* NB. The eForth image will return '1' if there is more work to do,
	 * '0' on successful exit (with no more work to do) and negative on an
	 * error (with no more work to do). This is however only by convention,
	 * another image that is not the default image is free to return
	 * whatever it likes. Also, we call 'usleep()' here, but we could do
	 * other work if we wanted to. */
	for (r = 0; (r = embed_vm(h)) > 0; )
		usleep(10 * 1000uLL);
	return r;
}

