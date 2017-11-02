0 ok! ( Turn off 'ok' prompt )
\ @file meta.fth
\ @author Richard James Howe
\ @license MIT
\ @copyright Richard James Howe, 2017
\ @brief A Meta-compiler, an implementation of eForth and a tutorial on both.
\ Project site: <https://github.com/howerj/embed>

only forth definitions hex
\ This file contains a metacompiler (also more commonly know as a cross-
\ compiler) and a program to be cross compiled. The cross compiler targets
\ a stack based virtual machine designed to run Forth. The cross compiled
\ program is a Forth interpreter. The file also contains a tutorial about
\ how to make a cross compiler in Forth, as well as how to make a working
\ Forth interpreter.

\ The workings of a metacompiler may seem complex, and to understand
\ this tutorial a reasonable understanding of Forth is required, but in
\ actuality the cross compiler is quite simple. The cross compiled program
\ itself is more complex. An understanding of Forth vocabularies is required,
\ which are often glossed over in tutorials, Forth vocabularies are how
\ Forth programmers manage which words go into which namespaces and allow
\ words that are no longer needed to be hidden.

\ The virtual machine that is targeted is suited to building a Forth
\ system but not much else, a more practical Forth virtual machine would
\ concentrate on efficiency and functionality (providing a Foreign Function
\ Interface, and file access words, for example). It is meant to be as
\ simple as possible and no simpler. It will be refered to as the 'Embed
\ virtual machine', or as 'the virtual machine'.

\ The metacompiler is based upon one targeting the J1 CPU, available
\ here <https://github.com/samawati/j1eforth>. The J1 CPU is a "Soft Core"
\ CPU written in Verilog, designed to be run on an FPGA. The J1 CPU is
\ well known in the Forth community, I have made my version written in
\ VHDL called the H2, available at <https://github.com/howerj/forth-cpu>.
\ The original cross compiler, written in C, targeting the Embed
\ virtual machine, was taken and modified from the H2 Project.

\ NOTES/TO DO:
\ * Instead of having a bit for whether a word is an inlineable word,
\ inlineable words could instead be part of a special vocabulary.
\ * Add more references, and turn this program into a literate file.
\    - Add references to eForth implementation guide
\    - Add references to my project
\    - Move diagrams describing the CPU architecture from the
\    'readme.md' file to this one.
\    - Document the Forth virtual machine, moving diagrams
\    from the 'readme.md' file to here.
\    - Add meta-compile time checking (eg. balanced 't:' and ';t')

\ Document plan
\ This program and document are a work in progress, it has been written
\ as if the program has been complete, although it is far from it.
\ The outline of the program/document is:
\ * Introduction
\ * Introduction to Forth
\ * Design trade offs, philosophy of Forth
\ * Dictionary layout
\ * Reference virtual machine
\ * The metacompiler, assembler
\ * The eForth program
\ * Conclusion

( ===                    Metacompilation wordset                    === )      
\ This section defines the metacompilation wordset as well as the
\ assembler. The cross compiler requires a few assembly instructions
\ to be defined before it can be completed so the metacompiler and
\ assembler are not completely separate modules

variable meta.1       ( Metacompilation vocabulary )
meta.1 +order definitions

variable assembler.1  ( Target assembler vocabulary )
variable target.1     ( Target dictionary )
variable tcp          ( Target dictionary pointer )
variable tlast        ( Last defined word in target )
5000 constant #target ( Memory location where the target image will be built )
2000 constant #max     ( Max number of cells in generated image )
2    constant =cell    ( Target cell size )
0    constant optimize ( Turn optimizations on [-1] or off [0] )
#target #max 0 fill   ( Erase the target memory location )

\ $601c constant =exit       ( op code for exit )
\ $6a00 constant =invert     ( op code for invert )
\ $6147 constant =>r         ( op code for >r )
\ 32    constant =bl         ( blank, or space )
\ 13    constant =cr         ( carriage return )
\ 10    constant =lf         ( line feed )
\ 8     constant =bs         ( back space )
\ 27    constant =escape     ( escape character )
\ -1    constant eof         ( end of file )

\ 16    constant dump-width  ( number of columns for 'dump' )
\ 80    constant tib-length  ( size of terminal input buffer )
\ 80    constant pad-length  ( pad area begins HERE + pad-length )
\ 31    constant word-length ( maximum length of a word )

\ 64    constant c/l         ( characters per line in a block )
\ 16    constant l/b         ( lines in a block )
\ $4400 constant sp0         ( start of variable stack )
\ $7fff constant rp0         ( start of return stack )

: ]asm assembler.1 +order ; immediate ( -- )
: a: get-current assembler.1 set-current : ; ( "name" -- wid link )
: a; [compile] ; set-current ; immediate ( wid link -- )

: there tcp @ ; ( -- a : target dictionary pointer value )
: tc! #target + c! ;
: tc@ #target + c@ ;
( @todo allow for configurable endianess )
: t! over ff and over tc! swap 8 rshift swap 1+ tc! ;
: t@ dup tc@ swap 1+ tc@ 8 lshift or ;
: 2/ 1 rshift ; 
: .hex base @ >r hex . cr r> base ! ;
: talign there 1 and tcp +! ;
: tc, there tc! 1 tcp +! ;
: t,  there t!  =cell tcp +! ;
: tallot tcp +! ;
: finished only forth definitions hex #target #target there + (save) ;

\ @todo Replace ." and throw with abort"
: [a] ( "name" -- : find word and compile an assembler word )
  token assembler.1 search-wordlist 0= if ." [a]?" cr -1 throw then
  cfa compile, ; immediate

\  @bug immediate cannot be placed after 'a;' because of the way linking
\ vocabularies into the dictionary works, in fact the word 'a;' should not be
\ necessary but it is a work around for another hack 
a: asm[ assembler.1 -order ( [ immediate ] ) a; ( -- )

\ ALU Operations
a: #t      0000 a;
a: #n      0100 a;
a: #r      0200 a;
a: #[t]    0300 a;
a: #n->[t] 0400 a;
a: #t+n    0500 a;
a: #t*n    0600 a;
a: #t&n    0700 a;
a: #t|n    0800 a;
a: #t^n    0900 a;
a: #~t     0a00 a;
a: #t-1    0b00 a;
a: #t==0   0c00 a;
a: #t==n   0d00 a;
a: #nu<t   0e00 a;
a: #n<t    0f00 a;
a: #n>>t   1000 a;
a: #n<<t   1100 a;
a: #sp@    1200 a;
a: #rp@    1300 a;
a: #sp!    1400 a;
a: #rp!    1500 a;
a: #save   1600 a;
a: #tx     1700 a;
a: #rx     1800 a;
a: #u/mod  1900 a;
a: #/mod   1a00 a;
a: #bye    1b00 a;

a: r->pc   0010 or a;
a: n->t    0020 or a;
a: t->r    0040 or a;
a: t->n    0080 or a;

a: d+1     0001 or a;
a: d-1     0003 or a;
a: d-2     0002 or a;
a: r-1     000c or a;
a: r-2     0008 or a;
a: r+1     0004 or a;

a: alu     6000 or t, a;
a: return [a] #t 1000 or [a] r-1 [a] alu a;
a: branch 2/ 0000 or t, a;
a: ?branch 2/ 2000 or t, a;
a: call 2/ 4000 or t, a;

a: literal
  dup 8000 and if
    invert
    [a] #~t [a] alu
  then
    8000 or t,
  a;

\ @todo Improve with fence variable set by control structures
\ @todo Use optimizer from "eforth.fth"
: lookback there =cell - t@ ;
: call? lookback e000 and 4000 = ;
: call>goto there =cell - dup t@ 1fff and swap t! ;
: safe? lookback e000 and 6000 = lookback 004c and 0= and ;
: alu>return there =cell - dup t@ [a] r->pc [a] r-1 swap t! ;
: exit,
  call? if
   call>goto else safe? if
    alu>return else
	 [a] return
   then
  then ;

( @todo refactor into multiple words )
( @todo allow the creation of words with no header )
: t: 
	>in @ >r bl parse r> >in ! 
	talign
	there #target + pack$ count nip 1+ aligned tcp +! talign
	tlast @ t, there tlast ! 
	get-current >r target.1 set-current create r> set-current
	there , does> @ [a] call ;

: t; optimize if exit, else [a] return then ; 

: literal [a] literal ;
: begin  there ;
: until  [a] ?branch ;
: if     there 0 [a] ?branch ;
: skip   there 0 [a] branch ;
: then   begin 2/ over t@ or swap t! ;
: else   skip swap then ;
: while  if swap ;
: repeat [a] branch then ;
: again  [a] branch ;
: aft    drop skip begin swap ;

\ Instructions

: nop     ]asm  #t       alu asm[ ;
: dup     ]asm  #t       t->n   d+1   alu asm[ ;
: over    ]asm  #n       t->n   d+1   alu asm[ ;
: invert  ]asm  #~t      alu asm[ ;
: um+     ]asm  #t+n     alu asm[ ;
: +       ]asm  #t+n     n->t   d-1   alu asm[ ;
: um*     ]asm  #t*n     alu asm[    ;
: *       ]asm  #t*n     n->t   d-1   alu asm[ ;
: swap    ]asm  #n       t->n   alu asm[ ;
: nip     ]asm  #t       d-1    alu asm[ ;
: drop    ]asm  #n       d-1    alu asm[ ;
: exit    ]asm  #t       r->pc  r-1   alu asm[ ;
: >r      ]asm  #n       t->r   d-1   r+1   alu asm[ ;
: r>      ]asm  #r       t->n   d+1   r-1   alu asm[ ;
: r@      ]asm  #r       t->n   d+1   alu asm[ ;
: @       ]asm  #[t]     alu asm[ ;
: !       ]asm  #n->[t]  d-1    alu asm[ ;
: rshift  ]asm  #n>>t    d-1    alu asm[ ;
: lshift  ]asm  #n<<t    d-1    alu asm[ ;
: =       ]asm  #t==n    d-1    alu asm[ ;
: u<      ]asm  #nu<t    d-1    alu asm[ ;
: <       ]asm  #n<t     d-1    alu asm[ ;
: and     ]asm  #t&n     d-1    alu asm[ ;
: xor     ]asm  #t^n     d-1    alu asm[ ;
: or      ]asm  #t|n     d-1    alu asm[ ;
: sp@     ]asm  #sp@     t->n   d+1   alu asm[ ;
: sp!     ]asm  #sp!     alu asm[ ;
: 1-      ]asm  #t-1     alu asm[ ;
: rp@     ]asm  #rp@     t->n   d+1   alu asm[ ;
: rp!     ]asm  #rp!     d-1    alu asm[ ;
: 0=      ]asm  #t==0    alu asm[ ;
: nop     ]asm  #t       alu asm[ ;
: bye     ]asm  #bye     alu asm[ ;
: rx?     ]asm  #rx      t->n   d+1   alu asm[ ;
: tx!     ]asm  #tx      n->t   d-1   alu asm[ ;
: (save)  ]asm  #save    d-1    alu asm[ ;
: u/mod   ]asm  #u/mod   t->n   alu asm[ ;
: /mod    ]asm  #u/mod   t->n   alu asm[ ;
: /       ]asm  #u/mod   d-1    alu asm[ ;
: mod     ]asm  #u/mod   n->t   d-1   alu asm[ ;
: rdrop   ]asm  #t       r-1    alu asm[ ;
\ code ;code assembler end-code

: for >r begin ;
\ @todo make a more compact 'next' construct
: next r@ while r> 1- >r repeat r> drop ; 

\ : inline target.1 @ @ 8000 or target.1 @ ! ;
\ : immediate target.1 @ @ 4000 or target.1 @ ! ;

( ===                        Target Words                           === )
\ With the assembler and meta compiler complete, we can now make our target
\ application, a Forth interpreter which will be able to read in this file
\ and create new, possibly modified, images for the Forth virtual machine
\ to run.

target.1 +order
\ t: doVar r> t;
\ t: doConst r> @ t;
\ t: r1- r> r> 1- >r >r t;

\ @todo add data to the beginning of the image that would allow the binary 
\ format to be identified by an external program, this should include:
\ - A Magic number format identifier
\ - Endianess of format
\ - Version number
\ - Length and CRC checks
\ The first two 16-bit cells contain the start vector and the trap
\ handler

4 tallot 

t: xx begin there 2/ 0 t! 6a literal tx! again t;
t: yy xx xx t;

( ===                        Target Words                           === )


( ===                           Finishing                           === )

\ @warning This section will need rewriting or the search order priority
\ will need changing once words in the target dictionary are defined which
\ conflict with the ones used here. Perhaps 't:' could add 'target.1' to
\ the search order and 't;' could remove it.
 
.( META COMPILER WORDS: ) cr
.( TARGET:    ) target.1 .hex
.( ASSEMBLER: ) assembler.1 .hex
.( META:      ) meta.1 .hex
assembler.1 +order
words
target.1 -order assembler.1 -order
.( META COMPILATION COMPLETE ) cr
.( SPACE USED: ) here .hex
\ .( TARGET SPACE USED: ) tcp @ .hex
finished ( restore system )
( ===                           Finishing                           === )
