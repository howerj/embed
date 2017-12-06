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

: undefined? token find nip 0= ; ( "name", -- f: Is word not in search order? )
: defined? undefined? 0= ;       ( "name", -- f: Is word in search order? )
: ?\ 0= if [compile] \ then ;    ( f --, <string>| : conditional compilation )

undefined? 0<   ?\ : 0< 0 < ;
undefined? 1-   ?\ : 1- 1 - ;
undefined? 2*   ?\ : 2* 1 lshift ;
undefined? rdup ?\ : rdup r> r> dup >r >r >r ; 
undefined? 1+!  ?\ : 1+! 1 swap +! ;

variable test
test +order definitions hex

variable total    ( total number of tests )
variable passed   ( number of tests that passed )
variable vsp      ( stack depth at execution of '->' )
variable vsp0     ( stack depth at execution of 'T{' )
variable n        ( temporary store for 'equal' )

: quine source type cr ;                 ( -- : print out current input line )
: ndrop for aft drop then next ;         ( a0...an n -- )
: ndisplay for aft . then next ;         ( a0...an n -- )
: empty-stacks depth ndrop ;             ( a0...an -- )
: .pass   ."   ok: " space quine ;       ( -- )
: .failed ." fail: " space quine ;       ( -- )
: pass  passed 1+! total 1+! ;           ( -- )
: fail total 1+! empty-stacks -b throw ; ( -- )

\ 'equal' is the most complex word in this test bench, it tests whether two
\ groups of numbers of the same length are equal, the length of the numbers
\ is specified by the first argument to 'equal'. 
: equal ( a0...an b0...bn n -- a0...an b0...bn n f )
  dup n !
  for aft 
    r@ pick r@ n @ 1+ + pick xor if rdrop n @ 0 exit then 
  then next n @ -1 ;


\ '?stacks' is given two numbers representing stack depths, if they are
\ not equal it prints out an error message, and calls 'abort'.
: ?stacks ( u u -- )
  2dup xor 
  if 
    .failed ." Too Few/Many Arguments Provided" cr
    ." Expected:  " u. cr
    ." Got: "       u. cr 
    ." Full Stack:" .s cr
    fail exit
  else 2drop then ;

\ 'equal?' takes two lists of numbers of the same length and checks if they
\ are equal, if they are not then an error message is printed and 'abort'
\ is called.
: ?equal ( a0...an b0...bn n -- )
  dup >r
  equal nip 0= if
    .failed ." Argument Value Mismatch" cr 
    ." expected:  " r@ ndisplay cr
    ." got: "       r@ ndisplay cr
    fail exit
  then r> 2* ndrop ;

only forth definitions test +order

\ @todo update forth syntax highlighting file for 'T{' and '}T' 
\ in the <https://github.com/howerj/forth.vim> project

: }T depth vsp0 @ - vsp @ 2* ?stacks vsp @ ?equal pass .pass ; 
: -> depth vsp0 @ - vsp ! ;
: T{ depth vsp0 ! ;
: statistics passed total ;
: throws? [compile] ' catch >r empty-stacks r> ; ( "name", n -- f  )

hide test
only forth definitions

\ We can define some more functions to test to make sure the arithmetic
\ functions, control structures and recursion works correctly, it is
\ also handy to have these functions documented somewhere in case they come
\ in use
: factorial dup 2 u< if drop 1 exit then dup 1- recurse * ;  ( u -- u )
: permutations over swap - factorial swap factorial swap / ; ( u1 u2 -- u )
: combinations dup dup permutations >r permutations r> / ;   ( u1 u2 -- u )
: gcd dup if tuck mod tail then drop ;                       ( u1 u2 -- u )
: lcm 2dup gcd / * ;                                         ( u1 u2 -- u )
: square dup * ;                                             ( u -- u )
: limit rot min max ;                                        ( u hi lo -- u )
: sum 1- 0 $7fff limit for aft + then next ;                 ( a0...an n -- n )

\ From: https://en.wikipedia.org/wiki/Integer_square_root
\ This function computes the integer square root of a number.
: sqrt ( n -- u : integer square root )
  dup 0<  if -b throw then ( does not work for signed values )
  dup 2 < if exit then      ( return 0 or 1 )
  dup                       ( u u )
  2 rshift recurse 2*       ( u sc : 'sc' == unsigned small candidate )
  dup                       ( u sc sc )
  1+ dup square             ( u sc lc lc^2 : 'lc' == unsigned large candidate )
  >r rot r> <               ( sc lc bool )
  if drop else nip then ;   ( return small or large candidate respectively )
  
: log ( u base -- u : compute the integer logarithm of u in 'base' )
	>r
	dup 0= if -b throw then ( logarithm of zero is an error )
	0 swap
	begin
		swap 1+ swap rdup r> / dup 0= ( keep dividing until 'u' is 0 )
	until
	drop 1- rdrop ;

: log2 2 log ; ( u -- u : compute the integer logarithm of u in base )

.( BEGIN FORTH TEST SUITE ) cr

hex
T{               ->  }T
T{  1            ->  1 }T
T{  1 2 3        ->  1 2 3 }T
T{  1 1+         ->  2 }T
T{  2 2 +        ->  4 }T
T{  3 2 4 within -> -1 }T
T{  2 2 4 within -> -1 }T
T{  4 2 4 within ->  0 }T
T{ 98 4 min      ->  4 }T
T{  1  5 min     ->  1 }T
T{ -1  5 min     -> -1 }T
T{  55 3 max     -> 55 }T
T{ -55 3 max     ->  3 }T
T{  3 10 max     -> 10 }T
T{ -2 negate     ->  2 }T
T{  0 negate     ->  0 }T
T{  2 negate     -> -2 }T
T{    char 0     -> $30 }T
T{  0 aligned    ->  0 }T
T{  1 aligned    ->  2 }T
T{  2 aligned    ->  2 }T
T{  3 aligned    ->  4 }T
T{  3  4 >       ->  0 }T
T{  3 -4 >       -> -1 }T
T{  5  5 >       ->  0 }T
T{  6  6 u>      ->  0 }T
T{  9 -8 u>      ->  0 }T
T{  5  2 u>      -> -1 }T
T{ -4 abs        ->  4 }T
T{  0 abs        ->  0 }T
T{  7 abs        ->  7 }T
T{ 100 10 8  /string -> 108 8 }T
T{ 100 10 18 /string -> 110 0 }T
T{ 9 log2 -> 3 }T
T{ 8 log2 -> 3 }T
T{ 4 log2 -> 2 }T
T{ 2 log2 -> 1 }T
T{ 1 log2 -> 0 }T

decimal
.( decimal mode ) cr
T{ 50 25 gcd -> 25 }T
T{ 13 23 gcd -> 1 }T

T{ 1 2 3 4 5 1 pick -> 1 2 3 4 5 4 }T
T{ 1 2 3 4 5 0 pick -> 1 2 3 4 5 5 }T
T{ 1 2 3 4 5 3 pick -> 1 2 3 4 5 2 }T

T{ 4  square -> 16 }T
T{ -1 square -> 1 }T
T{ -9 square -> 81 }T

T{ 6 factorial -> 720  }T
T{ 0 factorial -> 1  }T
T{ 1 factorial -> 1  }T

T{ 0 sqrt -> 0 }T
T{ 1 sqrt -> 1 }T
T{ 2 sqrt -> 1 }T
T{ 3 sqrt -> 1 }T
T{ 9 sqrt -> 3 }T
T{ 10 sqrt -> 3 }T
T{ 16 sqrt -> 4 }T
T{ 36 sqrt -> 6 }T
T{ -1 throws? sqrt -> -11 }T
T{  4 throws? sqrt ->  0  }T
T{ -9 throws? sqrt -> -11 }T

T{ 10 11 lcm -> 110 }T
T{ 3   2 lcm ->   6 }T
T{ 17 12 lcm -> 204 }T

T{ 3 4 / -> 0 }T
T{ 4 4 / -> 1 }T
T{ 1   0 throws? / -> -10 }T
T{ -10 0 throws? / -> -10 }T
T{ 2 2   throws? / -> 0 }T

.( hex mode ) cr
hex

: s1 $" xxx" ;
: s2 $" hello" ;

.( Test Strings: ) cr
.( s1:  ) space s1 count type cr
.( s2:  ) space s2 count type cr

T{ s1 count crc -> $C35A }T
T{ s2 count crc -> $D26E }T

T{ s1 count s1 count =string -> -1 }T
T{ s1 count s2 count =string ->  0 }T
T{ s2 count s1 count =string ->  0 }T
T{ s2 count s2 count =string -> -1 }T
hide s1 hide s2

T{ 0 ?dup -> 0 }T
T{ 3 ?dup -> 3 3 }T

T{ 1 2 3  rot -> 2 3 1 }T
T{ 1 2 3 -rot -> 3 1 2 }T

.( Defined variable 'x' ) cr
variable x 
T{ 9 x ! x @ -> 9 }T
T{ 1 x +! x @ -> $a }T
hide x


0 ok!

.( TESTS COMPLETE ) cr
decimal
.( passed: ) statistics swap @ u. .( / ) @ 0 u.r cr
statistics @ swap @ = ?\ .( [ALL PASSED] ) cr
hex

bye

