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

#target tcp !
: there tcp @ ;
: t! #target + ! ;
: t@ #target + @ ;
: tc! #target + c! ;
: tc@ #target + c@ ;
: talign there 1 and tcp +! ;
: tc, there tc! 1 tcp +! ;
: t,  there t!  2 tcp +! ;
: tallot tcp +! ;
: inline target.1 @ @ 8000 or target.1 @ ! ;

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
a: #n>>t   1100 a;
a: #n<<t   1200 a;
a: #sp@    1300 a;
a: #rp@    1400 a;
a: #sp!    1500 a;
a: #rp!    1600 a;
a: #save   1700 a;
a: #tx     1800 a;
a: #rx     1900 a;
a: #u/mod  1a00 a;
a: #/mod   1b00 a;
a: #bye    1c00 a;

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
a: branch 1 rshift 0000 or t, a;
a: ?branch 1 rshift 2000 or t, a;
a: call 1 rshift 4000 or t, a;

a: literal
  dup 8000 and if
    ffff xor recurse
    [a] #~t [a] alu
  else
    8000 or t,
  then a;

( @todo refactor and get this working! )
: t: 
	>in @ >r bl parse r> >in ! 
	there pack$ count nip aligned tcp +!
	tlast @ t, there tlast ! 
	get-current >r target.1 set-current create r> set-current
	there , does> @ [a] call ;

: t; [a] return ; ( @todo optimizations )

\ Instructions

: dup     ]asm  #t       t->n   d+1   asm[  ;
: over    ]asm  #n       t->n   d+1   asm[  ;
: invert  ]asm  #~t      asm[   ;
: um+     ]asm  #t+n     asm[   ;
: +       ]asm  #t+n     n->t   d-1   asm[  ;
: um*     ]asm  #t*n     asm[   ;
: *       ]asm  #t*n     n->t   d-1   asm[  ;
: swap    ]asm  #n       t->n   asm[  ;
: nip     ]asm  #t       d-1    asm[  ;
: drop    ]asm  #n       d-1    asm[  ;
: exit    ]asm  #t       r->pc  r-1   asm[  ;
: >r      ]asm  #n       t->r   d-1   r+1   asm[  ;
: r>      ]asm  #r       t->n   d+1   r-1   asm[  ;
: r@      ]asm  #r       t->n   d+1   asm[  ;
: @       ]asm  #[t]     asm[   ;
: !       ]asm  #n->[t]  d-1    asm[  ;
: rshift  ]asm  #n>>t    d-1    asm[  ;
: lshift  ]asm  #n<<t    d-1    asm[  ;
: =       ]asm  #t==n    d-1    asm[  ;
: u<      ]asm  #nu<t    d-1    asm[  ;
: <       ]asm  #n<t     d-1    asm[  ;
: and     ]asm  #t&n     d-1    asm[  ;
: xor     ]asm  #t^n     d-1    asm[  ;
: or      ]asm  #t|n     d-1    asm[  ;
: sp@     ]asm  #sp@     t->n   d+1   asm[  ;
: sp!     ]asm  #sp!     asm[   ;
: 1-      ]asm  #t-1     asm[   ;
: rp@     ]asm  #rp@     t->n   d+1   asm[  ;
: rp!     ]asm  #rp!     d-1    asm[  ;
: 0=      ]asm  #t==0    asm[   ;
: nop     ]asm  #t       asm[   ;
: bye     ]asm  #bye     asm[   ;
: rx?     ]asm  #rx      t->n   d+1   asm[  ;
: tx!     ]asm  #tx      n->t   d-1   asm[  ;
: (save)  ]asm  #save    d-1    asm[  ;
: u/mod   ]asm  #u/mod   t->n   asm[  ;
: /mod    ]asm  #u/mod   t->n   asm[  ;
: /       ]asm  #u/mod   d-1    asm[  ;
: mod     ]asm  #u/mod   n->t   d-1   asm[  ;
: rdrop   ]asm  #t       r-1    asm[  ;

\ t: doVar >r t;
\ t: doConst >r @ t;

t: xx 6a literal tx! 0 [a] branch t;
t: yy xx xx t;
 
\ code ;code assembler end-code


\ only forth definitions hex
meta.1 -order
5000 7000 (save)

cr
