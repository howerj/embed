# embed: A tiny embeddable Forth interpreter

| Project   | Forth SoC written in VHDL |
| --------- | ------------------------- |
| Author    | Richard James Howe        |
| Copyright | 2017 Richard James Howe   |
| License   | MIT                       |
| Email     | howe.r.j.89@gmail.com     |

Available at <https://github.com/howerj/embed>

This project was derived from a simulator for a [Forth][] CPU available from here:
<https://github.com/howerj/forth-cpu>. The simulator and compiler have been
modified so they can be used as a C like Forth for the PC.

The project is a work in progress, but most of the system is in place. It is
currently being code golfed so the Forth program running on the machine is as
small as possible, Forth is Sudoku for programmers after all.

For a more complete description of the system, see [meta.fth][].

## Program Operation

To build the project you will need a [C compiler][], and [make][]. The
system should build under [Linux][] and [Windows][]. After installing
[make][] and a [C99][] compiler, simply type "make" to build the
Forth virtual machine (from [forth.c][]), an image containing a working Forth
implementation is provided [eforth.blk][].


	Linux:
	./forth  i  eforth.blk new.blk
	Windows:
	forth.exe i eforth.blk new.blk

To exit the virtual machine cleanly either type "bye" and then hit
return, or press CTRL+D (on Linux) / CTRL+Z (on Windows ) and then return.

The source code for [eforth.blk][] is provided in [meta.blk][], which contains
an explanation on how a Forth cross compiler works (know as a *metacompiler* in
Forth terminology) as well as a specification for the virtual machine and a
little about [Forth][] itself.

[forth.c]: forth.c
[eforth.blk]: forth.c
[meta.fth]: eforth.fth
[C compiler]: https://gcc.gnu.org/
[make]: https://www.gnu.org/software/make/
[Windows]: https://en.wikipedia.org/wiki/Microsoft_Windows
[Linux]: https://en.wikipedia.org/wiki/Linux
[C99]: https://en.wikipedia.org/wiki/C99
[meta.fth]: meta.fth
[forth]: https://en.wikipedia.org/wiki/Forth_(programming_language)
