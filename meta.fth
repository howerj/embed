0 ok!

\ The meta-compiler (or cross-compiler) word set  
\ will go in this file, the plan is to make a meta compiler
\ and get rid of the Forth compiler written in C.
\ The https://github.com/samawati/j1eforth project should
\ be used as a template for this metacompiler
\ 
\ This is a work in progress, and more of an idea than a
\ working implementation of anything.

\ see also:
\ http://www.ultratechnology.com/meta.html>
\ http://retroforth.org/pages/?MetaCompiler>
\ http://www.ultratechnology.com/meta1.html>
\ https://wiki.forth-ev.de/doku.php/projects:building_a_remote_target_compiler

only forth definitions hex

variable meta.1      ( Metacompilation vocabulary )

meta.1 +order definitions

variable assembler.1 ( Target assembler vocabulary )
variable target.1    ( Target dictionary )
variable tcp         ( Target dictionary pointer )
variable tlast       ( Last defined word in target )
5000 constant #target 

\ $601c constant =exit       ( op code for exit )
\ $6800 constant =invert     ( op code for invert )
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

: ]asm ( -- ) assembler.1 +order ; immediate

\ : [a] 
\	parse-word assembler.1 search-wordlist 
\	0= abort" [a]?" compile, ; immediate ( "name" -- )

: a: get-current assembler.1 set-current : ; ( "name" -- wid link )
: a; [compile] ; set-current ; immediate ( wid link -- )

target.1 +order meta.1 +order

\ #target tcp !
: there tcp @ ;
: tc! #target + c! ;
: tc@ #target + c@ ;
: t! over ff and over tc! swap 8 rshift swap 1+ tc! ;
: t@ dup tc@ swap 1+ tc@ 8 lshift or ;
: 2/ 1 rshift ; 

\ : t! #target + ! ;
\ : t@ #target + @ ;
\ : tc! #target + c! ;
\ : tc@ #target + c@ ;
: talign there 1 and tcp +! ;
: tc, there tc! 1 tcp +! ;
: t,  there t!  2 tcp +! ;
: tallot tcp +! ;
: finished only forth definitions hex 5000 7000 (save) ;

: [a] ( "name" -- )
  token assembler.1 search-wordlist 0= if -1 throw then
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
: for >r begin ;
\ @todo make a more compact 'next' construct
: next r@ while r> 1- >r repeat r> drop ; 
: literal [a] literal ;

( @todo refactor and get this working! )
: t: 
	>in @ >r bl parse r> >in ! 
	talign
	there #target + pack$ count nip 1+ aligned tcp +! talign
	tlast @ t, there tlast ! 
	get-current >r target.1 set-current create r> set-current
	there , does> @ [a] call ;

: t; [a] return ; ( @todo optimizations )

\ Instructions

: noop    ]asm  #t       alu asm[ ;
: dup     ]asm  #t       t->n   d+1   alu asm[   ;
: over    ]asm  #n       t->n   d+1   alu asm[   ;
: invert  ]asm  #~t      alu asm[    ;
: um+     ]asm  #t+n     alu asm[    ;
: +       ]asm  #t+n     n->t   d-1   alu asm[   ;
: um*     ]asm  #t*n     alu asm[    ;
: *       ]asm  #t*n     n->t   d-1   alu asm[   ;
: swap    ]asm  #n       t->n   alu asm[   ;
: nip     ]asm  #t       d-1    alu asm[   ;
: drop    ]asm  #n       d-1    alu asm[   ;
: exit    ]asm  #t       r->pc  r-1   alu asm[   ;
: >r      ]asm  #n       t->r   d-1   r+1   alu asm[   ;
: r>      ]asm  #r       t->n   d+1   r-1   alu asm[   ;
: r@      ]asm  #r       t->n   d+1   alu asm[   ;
: @       ]asm  #[t]     alu asm[    ;
: !       ]asm  #n->[t]  d-1    alu asm[   ;
: rshift  ]asm  #n>>t    d-1    alu asm[   ;
: lshift  ]asm  #n<<t    d-1    alu asm[   ;
: =       ]asm  #t==n    d-1    alu asm[   ;
: u<      ]asm  #nu<t    d-1    alu asm[   ;
: <       ]asm  #n<t     d-1    alu asm[   ;
: and     ]asm  #t&n     d-1    alu asm[   ;
: xor     ]asm  #t^n     d-1    alu asm[   ;
: or      ]asm  #t|n     d-1    alu asm[   ;
: sp@     ]asm  #sp@     t->n   d+1   alu asm[   ;
: sp!     ]asm  #sp!     alu asm[    ;
: 1-      ]asm  #t-1     alu asm[    ;
: rp@     ]asm  #rp@     t->n   d+1   alu asm[   ;
: rp!     ]asm  #rp!     d-1    alu asm[   ;
: 0=      ]asm  #t==0    alu asm[    ;
: nop     ]asm  #t       alu asm[    ;
: bye     ]asm  #bye     alu asm[    ;
: rx?     ]asm  #rx      t->n   d+1   alu asm[   ;
: tx!     ]asm  #tx      n->t   d-1  .s alu asm[   ;
: (save)  ]asm  #save    d-1    alu asm[   ;
: u/mod   ]asm  #u/mod   t->n   alu asm[   ;
: /mod    ]asm  #u/mod   t->n   alu asm[   ;
: /       ]asm  #u/mod   d-1    alu asm[   ;
: mod     ]asm  #u/mod   n->t   d-1   alu asm[   ;
: rdrop   ]asm  #t       r-1    alu asm[   ;

\ t: doVar r> t;
\ t: doConst r> @ t;
\ t: r1- r> r> 1- >r >r t;
\ : inline target.1 @ @ 8000 or target.1 @ ! ;
\ : immediate target.1 @ @ 4000 or target.1 @ ! ;

4 tallot
t: xx begin there 2/ 0 t! 6a literal tx! again t;
t: yy xx xx t;
 
\ code ;code assembler end-code


\ only forth definitions hex
assembler.1 +order
words
finished
.( META COMPILATION COMPLETE ) cr
here . cr
