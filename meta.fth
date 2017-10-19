0 ok!

\ The meta-compiler (or cross-compiler) word set  
\ will go in this file, the plan is to make a meta compiler
\ and get rid of the Forth compiler written in C.
\ The https://github.com/samawati/j1eforth project should
\ be used as a template for this metacompiler
\ 
\ This is a work in progress, and more of an idea than a
\ working implementation of anything.

only forth ( definitions )

variable meta    ( Metacompilation vocabulary )

: target get-order 1+ meta swap set-order ;
get-order 1+ meta swap set-order

variable asm      ( Target assembler vocabulary )
variable target   ( Target dictionary )
variable headless ( Target dictionary for words without a header )
variable tcp      ( Target dictionary pointer )

$601c constant =exit       ( op code for exit )
$6800 constant =invert     ( op code for invert )
$6147 constant =>r         ( op code for >r )
32    constant =bl         ( blank, or space )
13    constant =cr         ( carriage return )
10    constant =lf         ( line feed )
8     constant =bs         ( back space )
27    constant =escape     ( escape character )
-1    constant eof         ( end of file )

16    constant dump-width  ( number of columns for 'dump' )
80    constant tib-length  ( size of terminal input buffer )
80    constant pad-length  ( pad area begins HERE + pad-length )
31    constant word-length ( maximum length of a word )

64    constant c/l         ( characters per line in a block )
16    constant l/b         ( lines in a block )
$4400 constant sp0         ( start of variable stack )
$7fff constant rp0         ( start of return stack )

400 constant #target 

create target-memory #target cells allot
target-memory #target 0 fill

: there tcp @ ;
: tc! target-memory + c! ;
: tc@ target-memory + c@ ;
: talign there 1 and tcp +! ;
: tc, there tc! 1 tcp +! ;
: tallot tcp +! ;
: inline target @ @ $8000 or target @ ! ;
: t: get-order 1+ target swap set-order : ;
: t; ' ; execute get-order 1- nip set-order ; immediate

\ t: doVar >r t;
\ t: doConst >r @ t;

\ here there !

\ @todo make a proper assembler, and also locate the new 
\ dictionary in the correct location of memory 

t: rdrop   rdrop   t;  inline
t: mod     mod     t;  inline
t: /       /       t;  inline
t: /mod    /mod    t;  inline
t: u/mod   u/mod   t;  inline
t: (save)  (save)  t;  inline
t: tx!     tx!     t;  inline
t: rx?     rx?     t;  inline
t: (bye)   (bye)   t;  inline
t: nop     nop     t;  inline
t: 0=      0=      t;  inline
t: rp!     rp!     t;  inline
t: rp@     rp@     t;  inline
t: 1-      1-      t;  inline
t: sp!     sp!     t;  inline
t: sp@     sp@     t;  inline
t: or      or      t;  inline
t: xor     xor     t;  inline
t: and     and     t;  inline
t: <       <       t;  inline
t: u<      u<      t;  inline
t: =       =       t;  inline
t: lshift  lshift  t;  inline
t: rshift  rshift  t;  inline
t: !       !       t;  inline
t: @       @       t;  inline
t: r@      r@      t;  inline
t: r>      r>      t;  inline
t: >r      >r      t;  inline
t: exit    exit    t;  inline
t: drop    drop    t;  inline
t: nip     nip     t;  inline
t: swap    swap    t;  inline
t: *       *       t;  inline
t: um*     um*     t;  inline
t: +       +       t;  inline
t: um+     um+     t;  inline
t: invert  invert  t;  inline
t: over    over    t;  inline
t: dup     dup     t;  inline

\ code ;code assembler end-code

target @ asm !

