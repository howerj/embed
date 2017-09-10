# embed: A tiny embeddable Forth interpreter 

| Project   | Forth SoC written in VHDL |
| --------- | ------------------------- |
| Author    | Richard James Howe        |
| Copyright | 2017 Richard James Howe   |
| License   | MIT                       |
| Email     | howe.r.j.89@gmail.com     |


This is a placeholder project for the moment, the idea is to take the H2
emulator available as part of a hardware Forth CPU project (written in VHDL,
targeting an FPGA, available at <https://github.com/howerj/forth-cpu>) and 
make a C Forth from it. The Forth Virtual machine can be
made to be very small, so it should be easy to embed and hide in other
programs.

The idea would be to start with the Forth, and the Pseudo Forth compiler, from the
original project and make itself hosting (apart from the C run time, which
should be easy to port). The project will start out large and be cut down from
their, become just a small C virtual machine and a block file.

# To Do

* Remove the SRAM peripheral and make the first 65536 words non-volatile
* Change size of a CPU word from a 16-bit value to a "uintptr\_t" type
* Make a cross compiler with the Forth


