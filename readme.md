# embed: A tiny embeddable Forth interpreter

| Project   | Forth SoC written in VHDL |
| --------- | ------------------------- |
| Author    | Richard James Howe        |
| Copyright | 2017 Richard James Howe   |
| License   | MIT                       |
| Email     | howe.r.j.89@gmail.com     |

Available at <https://github.com/howerj/embed>

This project was derived from a simulator for a Forth CPU available from here:
<https://github.com/howerj/forth-cpu>. The simulator and compiler have been
modified so they can be used as a C like Forth for the PC.

The project is a word in progress, but most of the system is in place. It is
currently being code golfed so the Forth program running on the machine is as
small as possible, Forth is Sudoku for programmers after all.

## The Virtual Machine

The Virtual Machine is a 16-bit stack machine based on the [H2 CPU][], a
derivative of the [J1 CPU][], but adapted for use on a computer.

Its instruction set allows for a fairly dense encoding, and the project
goal is to be fairly small whilst still being useful.  It is small enough
that is should be easily understandable with little explanation, and it
is hackable and extensible by modification of the source code.

## Memory Map

There is 64KiB of memory available to the Forth virtual machine, of which only
the first 16KiB can contain program instructions (or more accurately branch
locations can only be in the first 16KiB of memory). The virtual machine memory
can divided into three regions of memory, the applications further divide the
memory into different sections.

| Block   |  Region          |
| ------- | ---------------- |
| 0 - 15  | Program Storage  |
| 16      | Stack Storage    |
| 17 - 63 | User data        |

Program execution begins at address zero. The return and variable stacks start
in block 16, but they are not restricted to those blocks.

## Interaction

The outside world can be interacted with in two ways, with single character
input and output, or by saving the current Forth image. The interaction is
performed by three instructions.

## Instruction Set Encoding

For a detailed look at how the instructions are encoded the source code is the
definitive guide, available in the file [forth.c][].

A quick overview:

	+---------------------------------------------------------------+
	| F | E | D | C | B | A | 9 | 8 | 7 | 6 | 5 | 4 | 3 | 2 | 1 | 0 |
	+---------------------------------------------------------------+
	| 1 |                    LITERAL VALUE                          |
	+---------------------------------------------------------------+
	| 0 | 0 | 0 |            BRANCH TARGET ADDRESS                  |
	+---------------------------------------------------------------+
	| 0 | 0 | 1 |            CONDITIONAL BRANCH TARGET ADDRESS      |
	+---------------------------------------------------------------+
	| 0 | 1 | 0 |            CALL TARGET ADDRESS                    |
	+---------------------------------------------------------------+
	| 0 | 1 | 1 |   ALU OPERATION   |T2N|T2R|N2T|R2P| RSTACK| DSTACK|
	+---------------------------------------------------------------+
	| F | E | D | C | B | A | 9 | 8 | 7 | 6 | 5 | 4 | 3 | 2 | 1 | 0 |
	+---------------------------------------------------------------+

	T   : Top of data stack
	N   : Next on data stack
	PC  : Program Counter

	LITERAL VALUES : push a value onto the data stack
	CONDITIONAL    : BRANCHS pop and test the T
	CALLS          : PC+1 onto the return stack

	T2N : Move T to N
	T2R : Move T to top of return stack
	N2T : Move the new value of T (or D) to N
	R2P : Move top of return stack to PC

	RSTACK and DSTACK are signed values (twos compliment) that are
	the stack delta (the amount to increment or decrement the stack
	by for their respective stacks: return and data)

## To Do / Wish List

* Add error messages to generated block, as well as a simple help file
* Make short example programs
* Documentation of the project, some words, and the instruction set, as well as
the memory layout
* Make prepared images, as C code and as binary files
* Remove the compiler after a cross compiler has been made within the Forth
interpreter
* A simple run length compressor would reduce the size of the blocks, as well
as other simple memory compression techniques
* Improve the instruction set with a better choice of ALU operation, as well
as fixing the store instruction.
* One of the two stacks should grow upwards, the other downwards. One could be
located starting at the beginning of the data section, just after program
storage, the other one at the very end of the memory.
* Use
  <https://greg.blog/2013/01/26/unix-bi-grams-tri-grams-and-topic-modeling/> to
find common word sequences, then shrink the program size based on this.

[H2 CPU]: https://github.com/howerj/forth-cpu
[J1 CPU]: http://excamera.com/sphinx/fpga-j1.html
[forth.c]: forth.c
