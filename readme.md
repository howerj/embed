# embed: A tiny embeddable Forth interpreter

| Project   | Forth SoC written in VHDL |
| --------- | ------------------------- |
| Author    | Richard James Howe        |
| Copyright | 2017 Richard James Howe   |
| License   | MIT                       |
| Email     | howe.r.j.89@gmail.com     |

Available at <https://github.com/howerj/embed>

This project contains a tiny virtual machine (VM) optimized to execute 
[Forth][]. It is powerful and well developed enough to be self hosted, 
the VM and Forth interpreter image can be used to recreate a new image from
source (which is in [meta.fth][]). [meta.fth][] contains a more complete
description of the Forth interpreter, the virtual machine (which is only ~200
Lines of C code) and how a Forth meta compiler works.

The virtual machine is available as a library, as well, so it can be
**embedded** into another project, hence the project name. The virtual machine
([embed.c][], [embed.h][] and [main.c][]), the eForth image ([eforth.blk][]), 
and the metacompiler ([meta.fth][]) are all licensed under the [MIT License][].

## Program Operation

To build the project you will need a [C compiler][], and [make][]. The
system should build under [Linux][] and [Windows][] (MinGW). After installing
[make][] and a [C99][] compiler, simply type "make" to build the
Forth virtual machine. An image containing a working Forth
implementation is provided [eforth.blk][].

Linux:

	./forth i eforth.blk new.blk

Windows:

	forth.exe i eforth.blk new.blk

To exit the virtual machine cleanly either type "bye" and then hit
return, or press CTRL+D (on Linux) / CTRL+Z (on Windows) and then return.

The source code for [eforth.blk][] is provided in [meta.blk][], which contains
an explanation on how a Forth cross compiler works (know as a *metacompiler* in
Forth terminology) as well as a specification for the virtual machine and a
little about [Forth][] itself.

If you do not have a copy of [make][], but do have a [C99][] compiler, the
following command should build the project:

	cc -std=c99 embed.c main.c -o forth

## Project Organization

* [embed.c][]: The Embed Virtual Machine
* [embed.h][]: The Embed Virtual Machine library interface
* [main.c][]: An example driver for the Embed Virtual Machine
* [eforth.blk][]: A Forth interpreter image
* [meta.fth][]: A meta compiler and a Forth interpreter

[MIT License]: LICENSE
[embed.c]: embed.c
[embed.h]: embed.h
[main.c]: main.c
[eforth.blk]: eforth.blk
[meta.fth]: eforth.fth
[C compiler]: https://gcc.gnu.org/
[make]: https://www.gnu.org/software/make/
[Windows]: https://en.wikipedia.org/wiki/Microsoft_Windows
[Linux]: https://en.wikipedia.org/wiki/Linux
[C99]: https://en.wikipedia.org/wiki/C99
[meta.fth]: meta.fth
[forth]: https://en.wikipedia.org/wiki/Forth_(programming_language)
