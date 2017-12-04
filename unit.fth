0 ok!
\ This is a test bench for the Forth available at:
\ <https://github.com/howerj/embed>
\ It creates a new vocabulary for the support words for the test bench to live 
\ in, called 'test', and defines three words needed to implement a useful test 
\ bench, which are 'T{', '->' and '}T', the three words should always appear 
\ together as a matching set. 
\ 
\ 'T{' sets up the test, the test itself should appear on a single line, with 
\ the '}T' terminating it. The arguments to a function to test and function to 
\ test should appear to the left of the '->' word, and the values it returns 
\ should to the right of it. The test bench must also account for any items 
\ already on the stack prior to calling 'T{' which must be ignored. 
\ 
\ The test benches are not only used to test the internals of the Forth system,
\ and their edge cases, but also to document how the words should be used, so
\ words which this test bench relies on and trivial words are also tested.
\ 

variable test
test +order definitions

variable vsp
variable vsp0
variable n 

: 2* 1 lshift ;                   ( u -- u )
: ndrop for aft drop then next ;  ( a0...an n -- )
: ndisplay for aft u. then next ; ( a0...an n -- )
: empty-stacks depth ndrop ;      ( a0...an -- )
: pass ."   ok: " space source type cr ;

\ 'equal' is the most complex word in this test bench, it tests whether two
\ groups of numbers of the same length are equal, the length of the numbers
\ is specified by the first argument to 'equal'. 
: equal ( a0...an b0...bn n -- a0...an b0...bn n f )
  dup n !
  for aft 
    r@ pick r@ n @ 1+ + pick xor if rdrop n @ 0 exit then 
  then next n @ -1 ;

\ '.failed' prints out a message and the offending line which caused a test to 
\ fail, the simple mechanism is used to do this, 'source type' is the
\ cause of the requirement that a test sit on a single line.
: .failed ." Test Failed: " space source type cr ;

\ '?stacks' is given two numbers representing stack depths, if they are
\ not equal it prints out an error message, and calls 'abort'.
: ?stacks ( u u -- )
  2dup xor 
  if 
    .failed ." too few items" 
    ." expected:  " u. cr
    ." got: "       u. cr 
    ." full stack:" .s cr
    abort 
  else 2drop then ;

\ 'equal?' takes two lists of numbers of the same length and checks if they
\ are equal, if they are not then an error message is printed and 'abort'
\ is called.
: ?equal ( a0...an b0...bn n -- )
  dup >r
  equal nip 0= if
    .failed ." stack items differ" cr 
    ." expected:  " r@ ndisplay cr
    ." got: "       r@ ndisplay cr
    abort
  then r> 2* ndrop ;

only forth definitions test +order

: }T depth vsp0 @ - vsp @ 2* ?stacks vsp @ ?equal pass ;
: -> depth vsp0 @ - vsp ! ;
: T{ depth vsp0 ! ;

hide test
only forth definitions

.( BEGIN FORTH TEST SUITE ) cr

\ @todo update forth syntax highlighting file for T{ and }T

: defined? token find nip 0= 0= ; ( "name", -- b )
: ?\ 0= if [compile] \ then ; ( b -- )

T{ -> }T
T{ 1 -> 1 }T
T{ 1 2 3 -> 1 2 3 }T
T{ 2 2 + -> 4 }T
T{ 3 2 4 within -> -1 }T
T{ 2 2 4 within -> -1 }T
T{ 4 2 4 within ->  0 }T
T{ 98 4 min -> 4 }T
T{ 1  5 min -> 1 }T
T{ -1  5 min -> -1 }T
T{ 55 3 max -> 55 }T
T{ -55 3 max -> 3 }T
T{ 3 10 max -> 10 }T
T{ -2 negate -> 2 }T
T{ 0  negate -> 0 }T
T{ 2  negate -> -2 }T
T{ char 0 -> $30 }T
defined? x ?\ T{ 5 -> 4 }T

0 ok!

.( TESTS COMPLETE: ALL PASSED ) cr

bye

