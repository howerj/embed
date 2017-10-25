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

\ Instructions

\ dup    T         T_TO_N   d+1
\ over   N         T_TO_N   d+1
\ invert T_INVERT
\ um+    T_PLUS_N
\ +      T_PLUS_N  N_TO_T  d-1
\ um*    T_MUL_N
\ *      T_MUL_N  N_TO_T  d-1
\ swap   N         T_TO_N
\ nip    T                       d-1
\ drop   N                       d-1
\ exit   T         R_TO_PC  r-1
\ >r     N         T_TO_R   d-1  r+1
\ r>     R         T_TO_N   d+1   r-1
\ r@     R         T_TO_N   d+1
\ @      T_LOAD
\ !      N_STORE_AT_T            d-1
\ rshift N_RSHIFT_T              d-1
\ lshift N_LSHIFT_T              d-1
\ =      T_EQUAL_N               d-1
\ u<     N_ULESS_T               d-1
\ <      N_LESS_T                d-1
\ and    T_AND_N                 d-1
\ xor    T_XOR_N                 d-1
\ or     T_OR_N                  d-1
\ sp@    DEPTH    T_TO_N        d+1
\ sp!    SET_DEPTH
\ 1-     T_DECREMENT
\ rp@    RDEPTH   T_TO_N        d+1
\ rp!    SET_RDEPTH             d-1
\ 0=     T_EQUAL_0
\ nop    T
\ +bye  BYE
\ rx?    RX       T_TO_N        d+1
\ tx!    TX       N_TO_T        d-1
\ (save) SAVE                   d-1
\ u/mod  U_DMOD  T_TO_N
\ /mod   DMOD    T_TO_N
\ /      DMOD    d-1
\ mod    DMOD    N_TO_T  d-1
\ rdrop  T  r-1


: there tcp @ ;
: tc! #target + c! ;
: tc@ #target + c@ ;
: talign there 1 and tcp +! ;
: tc, there tc! 1 tcp +! ;
: tallot tcp +! ;
: inline target.1 @ @ $8000 or target.1 @ ! ;
\ : t: parse there pack$ get-order 1+ target swap set-order ;
\ : t; $601c tc, get-order 1- nip set-order ; immediate

\ t: doVar >r t;
\ t: doConst >r @ t;

\ here there !

\ @todo make a proper assembler, and also locate the new 
\ dictionary in the correct location of memory 

\ t: rdrop   rdrop   t;  inline
\ t: mod     mod     t;  inline
\ t: /       /       t;  inline
\ t: /mod    /mod    t;  inline
\ t: u/mod   u/mod   t;  inline
\ t: (save)  (save)  t;  inline
\ t: tx!     tx!     t;  inline
\ t: rx?     rx?     t;  inline
\ t: (bye)   (bye)   t;  inline
\ t: nop     nop     t;  inline
\ t: 0=      0=      t;  inline
\ t: rp!     rp!     t;  inline
\ t: rp@     rp@     t;  inline
\ t: 1-      1-      t;  inline
\ t: sp!     sp!     t;  inline
\ t: sp@     sp@     t;  inline
\ t: or      or      t;  inline
\ t: xor     xor     t;  inline
\ t: and     and     t;  inline
\ t: <       <       t;  inline
\ t: u<      u<      t;  inline
\ t: =       =       t;  inline
\ t: lshift  lshift  t;  inline
\ t: rshift  rshift  t;  inline
\ t: !       !       t;  inline
\ t: @       @       t;  inline
\ t: r@      r@      t;  inline
\ t: r>      r>      t;  inline
\ t: >r      >r      t;  inline
\ t: exit    exit    t;  inline
\ t: drop    drop    t;  inline
\ t: nip     nip     t;  inline
\ t: swap    swap    t;  inline
\ t: *       *       t;  inline
\ t: um*     um*     t;  inline
\ t: +       +       t;  inline
\ t: um+     um+     t;  inline
\ t: invert  invert  t;  inline
\ t: over    over    t;  inline
\ t: dup     dup     t;  inline
\ 
\ code ;code assembler end-code

\ 5000 2000 (save)


