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
small as possible.

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
locations can only be in the first 16KiB of memory).

## Interaction

The outside world can be interacted with in two ways, with single character
input and output, or by saving the current Forth image. The interaction is
performed by three instructions.

## Instruction Set Encoding

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

[H2 CPU]: https://github.com/howerj/forth-cpu
[J1 CPU]: http://excamera.com/sphinx/fpga-j1.html
