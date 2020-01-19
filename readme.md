# embed: A tiny embeddable Forth interpreter

| Project   | Embed Forth VM and eForth Image   |
| --------- | --------------------------------- |
| Author    | Richard James Howe                |
| Copyright | 2017-2018 Richard James Howe      |
| License   | MIT                               |
| Email     | howe.r.j.89@gmail.com             |
| Website   | <https://github.com/howerj/embed> |

	  ______           _              _ 
	 |  ____|         | |            | |
	 | |__   _ __ ___ | |__   ___  __| |
	 |  __| | '_ ` _ \| '_ \ / _ \/ _` |
	 | |____| | | | | | |_) |  __/ (_| |
	 |______|_| |_| |_|_.__/ \___|\__,_|
	     ______         _   _           
	    |  ____|       | | | |          
	    | |__ ___  _ __| |_| |__        
	    |  __/ _ \| '__| __| '_ \       
	    | | | (_) | |  | |_| | | |      
	    |_|  \___/|_|   \__|_| |_|      
					    
					
This project contains a tiny 16-bit Virtual Machine (VM) optimized to execute 
[Forth][]. It is powerful and well developed enough to be self hosted, 
the VM and Forth interpreter image can be used to recreate a new image from
source (which is in [embed.fth][]). [embed.fth][] contains a more complete
description of the Forth interpreter, the virtual machine (which is only ~400
Lines of C code) and how a Forth "meta-compiler" works.

The virtual machine is available as a library, as well, so it can be
**embedded** into another project, hence the project name. The virtual machine
([embed.c][] and [embed.h][]), the eForth image ([image.c][]), and the metacompiler 
([embed.fth][]) are all licensed under the [MIT License][].

Feel free to [email me][] about any problems, or [open up an issue on GitHub][].

## Program Operation

To build the project you will need a [C compiler][], and [make][]. The
system should build under [Linux][] and [Windows][] (MinGW). After installing
[make][] and a [C99][] compiler, simply type "make" to build the
Forth virtual machine. An image containing a working Forth
implementation is contained within [image.c][], which is built into
the executable.

Linux/Unixen:

	./embed

Windows:

	embed.exe

To exit the virtual machine cleanly either type **bye** and then hit
return, or press *CTRL+D* (on Linux) / *CTRL+Z* (on Windows) and then return.

The source code for [image.c][] is provided in [embed.fth][], which contains
an explanation on how a Forth cross compiler works (know as a *metacompiler* in
Forth terminology) as well as a specification for the virtual machine and a
little about [Forth][] itself.

If you do not have a copy of [make][], but do have a [C99][] compiler, the
following command should build the project:

	cc -std=c99 main.c embed.c image.c util.c -o embed

Generating a new image is easy as well (using the built in image):

	./embed -o new.blk embed.fth

We can then use the new image to generate a further image:

	./embed -o new2.blk -i new.blk embed.fth

Ad infinitum, the two newly generated images should be byte for byte equal.

Unit tests can be ran typing:

	make test                      # Using make
	./embed -o unit.blk t/unit.fth # manual invocation

## Project Organization

* [embed.c][]: The Embed Virtual Machine
* [embed.h][]: The Embed Virtual Machine library interface
* [main.c][]: Test driver for the Virtual Machine Library
* [image.c][]: A Forth interpreter image, C code
* [embed.fth][]: A meta compiler and a Forth interpreter
* [unit.fth][]: Unit tests for the eForth image

## Example Programs and Tests

Example programs and tests exist under the 't/' directory, these include test
programs written in C that can extend the virtual machine with new
functionality or change the input and out mechanisms to the virtual machine.

* [call.c][]:  Extends the virtual machine with floating point operations
* [unix.c][]:  Unix non-blocking and raw terminal I/O handling test
* [win.c][]:   Windows equivalent of [unix.c][].

## Project Goals

The goal of the project is to create a VM which is tiny, embeddable, 
customizable through callbacks and most importantly self-hosting. It achieves
all of these goals, but might fall short.

* [x] Self-Hosting Metacompiler
* [x] Man pages
* [x] Document project
* [x] Forth Unit tests
* [x] C Unit tests, to test the library API
* [x] C Test programs
  * [x] Test applications for Windows/Unix non-block I/O, and callback
    extensions.
* [x] Port the library to a small microcontroller (see <https://github.com/howerj/arduino>)
* [x] Create a cross compiler for the H2 Forth CPU (see the 'h2' branch of this
  project and <https://github.com/howerj/forth-cpu>).
* [ ] Change the 'embed' virtual machine so it more closely resembles the 'H2
  CPU' (see the 'h2' branch for this here <https://github.com/howerj/embed/tree/h2>). There
  are some problems with this branch, like the fact that it gets rid of most of
  the documentation, which should have been reworked instead.
* [ ] Restructure the dictionary so that word names/code are kept separately 
  like in most traditional Forth systems. This should make code reused easier
  and the implementation of 'FORGET' easier as well. This may also require
  Run Length Encoding of the image to keep its size down as the code and
  dictionary would be stored in non-contiguous memory locations.
* [ ] Virtual Machine and eForth Image/Metacompiler that uses 'uintptr\_t'
* [ ] Simplify the API. Currently the API is too complex and needs rethinking,
  it is flexible, but complex, and the user has to think too much about the
  implementation details.

[MIT License]: LICENSE
[embed.c]: embed.c
[main.c]: main.c
[embed.h]: embed.h
[image.c]: image.c
[unit.fth]: t/unit.fth
[embed.fth]: embed.fth
[call.c]: t/call.c
[unix.c]: t/unix.c
[win.c]: t/win.c
[C compiler]: https://gcc.gnu.org/
[make]: https://www.gnu.org/software/make/
[Windows]: https://en.wikipedia.org/wiki/Microsoft_Windows
[Linux]: https://en.wikipedia.org/wiki/Linux
[C99]: https://en.wikipedia.org/wiki/C99
[forth]: https://en.wikipedia.org/wiki/Forth_(programming_language)
[open up an issue on GitHub]: https://github.com/howerj/embed/issues
[email me]: mailto:howe.r.j.89@gmail.com
