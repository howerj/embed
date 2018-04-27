0 <ok> !
\ This is a Forth test bench for: <https://github.com/howerj/embed>
\
\ The test bench consists of a few support words, and three words that should
\ be used together, they are 'T{', '->' and '}T'.
\
\ 'T{' sets up the test, the test itself should appear on a single line, with
\ the '}T' terminating it. The arguments to a function to test and function to
\ test should appear to the left of the '->' word, and the values it returns
\ should to the right of it. The test bench must also account for any items
\ already on the stack prior to calling 'T{' which must be ignored.
\
\ A few other words are also defined, but they are not strictly needed, they
\ are 'throws?' and 'statistics'. 'throws?' parses the next word in the
\ input stream, and executes it, catching any exceptions. It empties the
\ variable stack and only returns the exception number thrown. This can be
\ used to test that words throw the correct exception in given circumstances.
\ 'statistics' is used for information about the tests; how many tests failed,
\ and how many tests were executed.
\
\ The test benches are not only used to test the internals of the Forth system,
\ and their edge cases, but also to document how the words should be used, so
\ words which this test bench relies on and trivial words are also tested. The
\ best test bench is actually the cross compilation method used to create new
\ images with the metacompiler, it tests nearly every single aspect of the
\ Forth system.
\
\ It might be worth setting up another interpreter loop until the corresponding
\ '}T' is reached so any exceptions can be caught and dealt with.
\

\ A few generic helper words will be built, to check if a word is defined, or
\ not, and to conditionally execute a line.
: undefined? token find nip 0= ; ( "name", -- f: Is word not in search order? )
: defined? undefined? 0= ;       ( "name", -- f: Is word in search order? )
: ?\ 0= if [compile] \ then ;    ( f --, <string>| : conditional compilation )

\ As a space saving measure some standard words may not be defined in the
\ core Forth image. If they are not defined, we define them here.
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
: pass passed 1+! ;                      ( -- )
: fail empty-stacks -b throw ;           ( -- )

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
    ." Expected:  " r@ ndisplay cr
    ." Got: "       r@ ndisplay cr
    fail exit
  then r> 2* ndrop ;

only forth definitions test +order

\ @todo update forth syntax highlighting file for 'T{' and '}T'
\ in the <https://github.com/howerj/forth.vim> project

: }T depth vsp0 @ - vsp @ 2* ?stacks vsp @ ?equal pass .pass ;
: -> depth vsp0 @ - vsp ! ;
: T{ depth vsp0 ! total 1+! ;
: statistics total @ passed @ ;
: throws? [compile] ' catch >r empty-stacks r> ; ( "name" -- n  )

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
T{ -6  0 min     -> -6 }T
T{  55 3 max     -> 55 }T
T{ -55 3 max     ->  3 }T
T{  3 10 max     -> 10 }T
T{ -2 negate     ->  2 }T
T{  0 negate     ->  0 }T
T{  2 negate     -> -2 }T
T{ $8000 negate  -> $8000 }T
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

: s1 $" xxx"   count ;
: s2 $" hello" count ;
: s3 $" 123"   count ;
: <#> 0 <# #s #> ; ( n -- b u )

.( Test Strings: ) cr
.( s1:  ) space s1 type cr
.( s2:  ) space s2 type cr
.( s3:  ) space s3 type cr

T{ s1 crc -> $C35A }T
T{ s2 crc -> $D26E }T

T{ s1 s1 =string -> -1 }T
T{ s1 s2 =string ->  0 }T
T{ s2 s1 =string ->  0 }T
T{ s2 s2 =string -> -1 }T

T{ s3  123 <#> =string -> -1 }T
T{ s3 -123 <#> =string ->  0 }T
T{ s3   99 <#> =string ->  0 }T

hide s1 hide s2 hide s3

T{ 0 ?dup -> 0 }T
T{ 3 ?dup -> 3 3 }T

T{ 1 2 3  rot -> 2 3 1 }T
T{ 1 2 3 -rot -> 3 1 2 }T

T{ 2 3 ' + execute -> 5 }T
T{ : test-1 [ $5 $3 * ] literal ; test-1 -> $f }T

.( Defined variable 'x' ) cr
variable x
T{ 9 x  ! x @ ->  9 }T
T{ 1 x +! x @ -> $a }T
hide x

T{     0 invert -> -1 }T
T{    -1 invert -> 0 }T
T{       $5555 invert -> $aaaa }T

T{     0     0 and ->     0 }T
T{     0    -1 and ->     0 }T
T{    -1     0 and ->     0 }T
T{    -1    -1 and ->    -1 }T
T{ $fa50 $05af and -> $0000 }T
T{ $fa50 $fa00 and -> $fa00 }T

T{     0     0  or ->     0 }T
T{     0    -1  or ->    -1 }T
T{    -1     0  or ->    -1 }T
T{    -1    -1  or ->    -1 }T
T{ $fa50 $05af  or -> $ffff }T
T{ $fa50 $fa00  or -> $fa50 }T

T{     0     0 xor ->     0 }T
T{     0    -1 xor ->    -1 }T
T{    -1     0 xor ->    -1 }T
T{    -1    -1 xor ->     0 }T
T{ $fa50 $05af xor -> $ffff }T
T{ $fa50 $fa00 xor -> $0050 }T

T{ $ffff     1 um+ -> 0 1  }T
T{ $40   $ffff um+ -> $3f 1  }T
T{ 4         5 um+ -> 9 0  }T

T{ $ffff     1 um* -> $ffff     0 }T
T{ $ffff     2 um* -> $fffe     1 }T
T{ $1004  $100 um* ->  $400   $10 }T
T{     3     4 um* ->    $c     0 }T


T{     1     1   < ->  0 }T
T{     1     2   < -> -1 }T
T{    -1     2   < -> -1 }T
T{    -2     0   < -> -1 }T
T{ $8000     5   < -> -1 }T
T{     5    -1   < -> 0 }T

T{     1     1  u< ->  0 }T
T{     1     2  u< -> -1 }T
T{    -1     2  u< ->  0 }T
T{    -2     0  u< ->  0 }T
T{ $8000     5  u< ->  0 }T
T{     5    -1  u< -> -1 }T

T{     1     1   = ->  -1 }T
T{    -1     1   = ->   0 }T
T{     1     0   = ->   0 }T

T{   2 dup -> 2 2 }T
T{ 1 2 nip -> 2 }T
T{ 1 2 over -> 1 2 1 }T
T{ 1 2 tuck -> 2 1 2 }T
T{ 1 negate -> -1 }T
T{ 3 4 swap -> 4 3 }T
T{ 0 0= -> -1 }T
T{ 3 0= ->  0 }T
T{ -5 0< -> -1 }T
T{ 1 2 3 2drop -> 1 }T

T{ 1 2 lshift -> 4 }T
T{ 1 $10 lshift -> 0 }T
T{ $4001 4 lshift -> $0010 }T

T{ 8     2 rshift -> 2 }T
T{ $4001 4 rshift -> $0400 }T
T{ $8000 1 rshift -> $4000 }T

T{ 99 throws? throw -> 99 }T

\ @todo u/mod tests, and more sign related tests
T{ 50 10 /mod ->  0  5 }T
T{ -4 3  /mod -> -1 -1 }T
T{ -8 3  /mod -> -2 -2 }T

.( Created word 'y' 0 , 0 , ) cr
create y 0 , 0 ,
T{ 4 5 y 2! -> }T
T{ y 2@ -> 4 5 }T
hide y

: e1 $" 2 5 + " count ;
: e2 $" 4 0 / " count ;
: e3 $" : z [ 4 dup * ] literal ; " count ;
.( e1: ) space e1 type cr
.( e2: ) space e2 type cr
.( e3: ) space e3 type cr
T{ e1 evaluate -> 7 }T
T{ e2 throws? evaluate -> $a negate }T
T{ e3 evaluate z -> $10 }T
hide e1 hide e2 hide e3 hide z

T{ here 4 , @ -> 4 }T
T{ here 0 , here swap cell+ = -> -1 }T

T{ depth depth depth -> 0 1 2 }T

T{ char 0     -> $30 }T
T{ char 1     -> $31 }T
T{ char g     -> $67 }T
T{ char ghijk -> $67 }T

T{ #vocs 8 min -> 8 }T    \ minimum number of vocabularies is 8
T{ b/buf      -> $400 }T  \ b/buf should always be 1024
defined? sp@ ?\ T{ sp@ 2 3 4 sp@ nip nip nip - abs chars -> 4 }T
T{ here 4 allot -4 allot here = -> -1 }T

\  T{ random random <> -> -1 }T

.( TESTS COMPLETE ) cr
decimal
.( passed: ) statistics u. .( / ) 0 u.r cr
.( here:   ) here . cr
statistics  = ?\ .( [ALL PASSED] ) cr     bye
statistics <> ?\ .( [FAILED]     ) cr -4 (bye)

