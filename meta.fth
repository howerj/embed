\ The meta-compiler (or cross-compiler) word set  
\ will go in this file, the plan is to make a meta compiler
\ and get rid of the Forth compiler written in C.
\ The https://github.com/samawati/j1eforth project should
\ be used as a template for this metacompiler

only forth ( definitions ) hex

variable meta
variable target
variable t.assembler
variable tcp 

400 constant #target 

create target-memory #target cells allot
target-memory #target 0 fill

: there tcp @ ;
: tc! target-memory + c! ;
: tc@ target-memory + c@ ;
: talign there 1 and tcp +! ;
: tc, there tc! 1 tcp +! ;

