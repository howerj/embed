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

variable meta    ( Metacompilation vocabulary )

meta +order definitions

variable asm      ( Target assembler vocabulary )
variable target   ( Target dictionary )
variable headless ( Target dictionary for words without a header )
variable tcp      ( Target dictionary pointer )

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

5000 constant #target 

\ ALU Operations
\ a: #t      0000 ;
\ a: #n      0100 ;
\ a: #r      0200 ;
\ a: #[t]    0300 ;
\ a: #n->[t] 0400 ;
\ a: #t+n    0500 ;
\ a: #t*n    0600 ;
\ a: #t&n    0700 ;
\ a: #t|n    0800 ;
\ a: #t^n    0900 ;
\ a: #~t     0a00 ;
\ a: #t-1    0b00 ;
\ a: #t==0   0c00 ;
\ a: #t==n   0d00 ;
\ a: #nu<t   0e00 ;
\ a: #n<t    0f00 ;
\ a: #n>>t   1100 ;
\ a: #n<<t   1200 ;
\ a: #sp@    1300 ;
\ a: #rp@    1400 ;
\ a: #sp!    1500 ;
\ a: #rp!    1600 ;
\ a: #save   1700 ;
\ a: #tx     1800 ;
\ a: #rx     1900 ;
\ a: #u/mod  1a00 ;
\ a: #/mod   1b00 ;
\ a: #bye    1c00 ;

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
\ (save) SAVE
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
: inline target @ @ $8000 or target @ ! ;
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


