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

The project is a work in progress, but most of the system is in place. It is
currently being code golfed so the Forth program running on the machine is as
small as possible, Forth is Sudoku for programmers after all.

## Program Operation

To build the project you will need a [C compiler][], and [make][]. The
system should build under [Linux][] and [Windows][]. After installing
[make][] and a [C99][] compiler, simply type "make" to build the
Forth virtual machine (from [forth.c][]), a compiler for the virtual
machine (from [compiler.c][]), and an image usable by the Forth Virtual
machine (from [eforth.fth][]).

Compiler operation (taking a Forth file [eforth.fth][] and compiling
the code into a virtual machine image "eforth.blk"):

	Linux:
	./compiler   eforth.fth eforth.blk
	Windows:
	compiler.exe eforth.fth eforth.blk

Virtual machine operation (running the virtual machine image "eforth.blk":

	Linux:
	./forth    eforth.blk
	Windows:
	forth.exe  eforth.blk

To exit the virtual machine cleanly either type "bye" and then hit
return, or press CTRL+D (on Linux) or CTRL+Z and then return (on Windows).

## The Virtual Machine

The Virtual Machine is a 16-bit stack machine based on the [H2 CPU][], a
derivative of the [J1 CPU][], but adapted for use on a computer.

Its instruction set allows for a fairly dense encoding, and the project
goal is to be fairly small whilst still being useful.  It is small enough
that is should be easily understandable with little explanation, and it
is hackable and extensible by modification of the source code.

## Virtual Machine Memory Map

There is 64KiB of memory available to the Forth virtual machine, of which only
the first 16KiB can contain program instructions (or more accurately branch
locations can only be in the first 16KiB of memory). The virtual machine memory
can divided into three regions of memory, the applications further divide the
memory into different sections.

| Block   |  Region          |
| ------- | ---------------- |
| 0 - 15  | Program Storage  |
| 16      | User Data        |
| 17      | Variable Stack   |
| 18 - 62 | User data        |
| 63      | Return Stack     |

Program execution begins at address zero. The variable stack starts at the
beginning of block 17 and grows upwards, the return stack starts at the end of
block 63 and grows downward.

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

### ALU Operations

The ALU can be programmed to do the following operations on an ALU instruction,
some operations trap on error (U/MOD, /MOD).

|  #  | Mnemonic | Description          |
| --- | -------- | -------------------- |
|  0  | T        | Top of Stack         |
|  1  | N        | Copy T to N          |
|  2  | R        | Top of return stack  |
|  3  | T@       | Load from address    |
|  4  | NtoT     | Store to address     |
|  5  | T+N      | Double cell addition |
|  6  | T\*N     | Double cell multiply |
|  7  | T&N      | Bitwise AND          |
|  8  | TorN     | Bitwise OR           |
|  9  | T^N      | Bitwise XOR          |
| 10  | ~T       | Bitwise Inversion    |
| 11  | T--      | Decrement            |
| 12  | T=0      | Equal to zero        |
| 13  | T=N      | Equality test        |
| 14  | Nu&lt;T  | Unsigned comparison  |
| 15  | N&lt;T   | Signed comparison    |
| 16  | NrshiftT | Logical Right Shift  |
| 17  | NlshiftT | Logical Left Shift   |
| 18  | SP@      | Depth of stack       |
| 19  | RP@      | R Stack Depth        |
| 20  | SP!      | Set Stack Depth      |
| 21  | RP!      | Set R Stack Depth    |
| 22  | SAVE     | Save Image           |
| 23  | TX       | Get byte             |
| 24  | RX       | Send byte            |
| 25  | U/MOD    | u/mod                |
| 26  | /MOD     | /mod                 |
| 27  | BYE      | Return               |

### Encoding of Forth Words

Many Forth words can be encoded directly in the instruction set, some of the
ALU operations have extra stack and register effects as well, which although
would be difficult to achieve in hardware is easy enough to do in software.

| Word   | Mnemonic | T2N | T2R | N2T | R2P |  RP |  SP |
| ------ | -------- | --- | --- | --- | --- | --- | --- |
| dup    | T        | T2N |     |     |     |     | +1  |
| over   | N        | T2N |     |     |     |     | +1  |
| invert | ~T       |     |     |     |     |     |     |
| um+    | T+N      |     |     |     |     |     |     |
| \+     | T+N      |     |     | N2T |     |     | -1  |
| um\*   | T\*N     |     |     |     |     |     |     |
| \*     | T\*N     |     |     | N2T |     |     | -1  |
| swap   | N        | T2N |     |     |     |     |     |
| nip    | T        |     |     |     |     |     | -1  |
| drop   | N        |     |     |     |     |     | -1  |
| exit   | T        |     |     |     | R2P |  -1 |     |
| &gt;r  | N        |     | T2R |     |     |   1 | -1  |
| r&gt;  | R        | T2N |     |     |     |  -1 |  1  |
| r@     | R        | T2N |     |     |     |     |  1  |
| @      | T@       |     |     |     |     |     |     |
| !      | NtoT     |     |     |     |     |     | -1  |
| rshift | NrshiftT |     |     |     |     |     | -1  |
| lshift | NlshiftT |     |     |     |     |     | -1  |
| =      | T=N      |     |     |     |     |     | -1  |
| u&lt;  | Nu&lt;T  |     |     |     |     |     | -1  |
| &lt;   | N&lt;T   |     |     |     |     |     | -1  |
| and    | T&N      |     |     |     |     |     | -1  |
| xor    | T^N      |     |     |     |     |     | -1  |
| or     | T|N      |     |     |     |     |     | -1  |
| sp@    | SP@      | T2N |     |     |     |     |  1  |
| sp!    | SP!      |     |     |     |     |     |     |
| 1-     | T--      |     |     |     |     |     |     |
| rp@    | RP@      | T2N |     |     |     |     |  1  |
| rp!    | RP!      |     |     |     |     |     | -1  |
| 0=     | T=0      |     |     |     |     |     |     |
| nop    | T        |     |     |     |     |     |     |
| (bye)  | BYE      |     |     |     |     |     |     |
| rx?    | RX       | T2N |     |     |     |     |  1  |
| tx!    | TX       |     |     | N2T |     |     | -1  |
| (save) | SAVE     |     |     |     |     |     | -1  |
| u/mod  | U/MOD    | T2N |     |     |     |     |     |
| /mod   | /MOD     | T2N |     |     |     |     |     |
| /      | /MOD     |     |     |     |     |     | -1  |
| mod    | /MOD     |     |     | N2T |     |     | -1  |
| rdrop  | T        |     |     |     |     |  -1 |     |

## Interaction

The outside world can be interacted with in two ways, with single character
input and output, or by saving the current Forth image. The interaction is
performed by three instructions.

## eForth

The interpreter is based on eForth by C. H. Ting, with some modifications
to the model.


## eForth Memory model

The eForth model imposes extra semantics to certain areas of memory.

| Address       | Block  | Meaning                        |
| ------------- | ------ | ------------------------------ |
| $0000         |   0    | Start of execution             |
| $0002         |   0    | Trap Handler                   |
| $0004-EOD     |   0    | The dictionary                 |
| EOD-PAD1      |   ?    | Compilation and Numeric Output |
| PAD1-PAD2     |   ?    | Pad Area                       |
| PAD2-$3FFF    |   15   | End of dictionary              |
| $4000         |   16   | Interpreter variable storage   |
| $4400         |   17   | Start of variable stack        |
| $4800-$FBFF   | 18-63  | Empty blocks for user data     |
| $FC00-$FFFF   |   0    | Return stack block             |

## Error Codes

This is a list of Error codes, not all of which are used by the application.


| Code |  Message                                      |
| ---- | --------------------------------------------- |
|  -1  | ABORT                                         |
|  -2  | ABORT"                                        |
|  -3  | stack overflow                                |
|  -4  | stack underflow                               |
|  -5  | return stack overflow                         |
|  -6  | return stack underflow                        |
|  -7  | do-loops nested too deeply during execution   |
|  -8  | dictionary overflow                           |
|  -9  | invalid memory address                        |
| -10  | division by zero                              |
| -11  | result out of range                           |
| -12  | argument type mismatch                        |
| -13  | undefined word                                |
| -14  | interpreting a compile-only word              |
| -15  | invalid FORGET                                |
| -16  | attempt to use zero-length string as a name   |
| -17  | pictured numeric output string overflow       |
| -18  | parsed string overflow                        |
| -19  | definition name too long                      |
| -20  | write to a read-only location                 |
| -21  | unsupported operation                         |
| -22  | control structure mismatch                    |
| -23  | address alignment exception                   |
| -24  | invalid numeric argument                      |
| -25  | return stack imbalance                        |
| -26  | loop parameters unavailable                   |
| -27  | invalid recursion                             |
| -28  | user interrupt                                |
| -29  | compiler nesting                              |
| -30  | obsolescent feature                           |
| -31  | &gt;BODY used on non-CREATEd definition       |
| -32  | invalid name argument (e.g., TO xxx)          |
| -33  | block read exception                          |
| -34  | block write exception                         |
| -35  | invalid block number                          |
| -36  | invalid file position                         |
| -37  | file I/O exception                            |
| -38  | non-existent file                             |
| -39  | unexpected end of file                        |
| -40  | invalid BASE for floating point conversion    |
| -41  | loss of precision                             |
| -42  | floating-point divide by zero                 |
| -43  | floating-point result out of range            |
| -44  | floating-point stack overflow                 |
| -45  | floating-point stack underflow                |
| -46  | floating-point invalid argument               |
| -47  | compilation word list deleted                 |
| -48  | invalid POSTPONE                              |
| -49  | search-order overflow                         |
| -50  | search-order underflow                        |
| -51  | compilation word list changed                 |
| -52  | control-flow stack overflow                   |
| -53  | exception stack overflow                      |
| -54  | floating-point underflow                      |
| -55  | floating-point unidentified fault             |
| -56  | QUIT                                          |
| -57  | exception in sending or receiving a character |
| -58  | [IF], [ELSE], or [THEN] exception             |

## To Do / Wish List

* Documentation of the project, some words, and the instruction set, as well as
the memory layout
* Remove the compiler after a cross compiler has been made within the Forth
interpreter, prepared images and the metacompiler would be provided instead.
* To facilitate porting to microcontrollers the Forth could be made to be
stored in a ROM, with initial variable values copied to RAM, the virtual
machine would also have to be modified to map different parts of the address
space into RAM and ROM. This would allow the system to require very little
(~2-4KiB) of RAM for a usable system, with a 6KiB ROM.
* Relative jumps could be used instead of absolute jumps in the code, this
would make relocation easier.
* Save and load all state to disk, not just the core. The current system also
does not embed format information into the binary files, which means the
generated object files is indistinguishable from other binary formats.
Magic numbers to identify the format, and Endianess information could be
included in the file format, the metacompiler could insert this information
into the generated object. Other information to include would be a CRC and
length information. See <http://www.fadden.com/tech/file-formats.html>,
and <https://stackoverflow.com/questions/323604>.
* Improve the command line argument passing in [forth.c][].
* On the Windows platform the input and output streams should be reopened in
binary mode.
* More assertions and range checks should be added to the interpreter, for
example the **save** function needs checks for bounds.
* The forth virtual machine in [forth.c][] should be made to be crash proof,
with checks to make sure indices never go out of bounds.
* Documentation could be extracted from the [meta.fth][] file, which should
describe the entire system: The metacompiler, the target virtual machine,
and how Forth works.

[H2 CPU]: https://github.com/howerj/forth-cpu
[J1 CPU]: http://excamera.com/sphinx/fpga-j1.html
[forth.c]: forth.c
[compiler.c]: compiler.c
[eforth.fth]: eforth.fth
[C compiler]: https://gcc.gnu.org/
[make]: https://www.gnu.org/software/make/
[Windows]: https://en.wikipedia.org/wiki/Microsoft_Windows
[Linux]: https://en.wikipedia.org/wiki/Linux
[C99]: https://en.wikipedia.org/wiki/C99
[meta.fth]: meta.fth
[DOS]: https://en.wikipedia.org/wiki/DOS
[8086]: https://en.wikipedia.org/wiki/Intel_8086
