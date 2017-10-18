0 ok!

\ The meta-compiler (or cross-compiler) word set  
\ will go in this file, the plan is to make a meta compiler
\ and get rid of the Forth compiler written in C.
\ The https://github.com/samawati/j1eforth project should
\ be used as a template for this metacompiler

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

: t: get-order 1+ target swap set-order : ;
: t; get-order 1- nip set-order ' ; execute ; immediate

\ t: doVar >r t;
\ t: doConst >r @ t;

\ here there !

\ code ;code assembler end-code rdrop mod / /mod u/mod (save) tx! rx? (bye)
\ nop 0= rp! rp@ 1- sp! sp@ or xor and < u< = lshift rshift ! @ r@ r> >r exit
\ drop nip swap * um* + um+ invert over dup



