0 <ok> !
only forth definitions hex
\ @todo improve drawing routine instead of using 'list', colorize as well
\ @todo Complete this program, it is a word in progress

variable sokoban-wordlist
sokoban-wordlist +order definitions

\ @todo change character set
$20    constant maze
char X constant wall
char * constant bolder
char . constant off
char & constant on
char @ constant player
$10    constant l/b    ( lines   per block )
$40    constant c/b    ( columns per block )

variable position
variable moves

\ Transform rules
\ ~ = player + pad
\ S = space
\ ? = do not care
\ 
\ @S? S@?
\ @.? S~?
\ @*S S@*
\ @*. S@&
\ @&. S~&
\ @&S S~*
\ 
\ ~S? .@?
\ ~.? .~?
\ ~*S .@*
\ ~*. .@&
\ ~&. .~&
\ ~&S .~*
\ 
\ Else do nothing

: n1+ swap 1+ swap ; ( n n -- n n )
: match ( a a -- )
  n1+ ( replace with umin of both counts? )
  count 
  for aft  
    count rot count rot <> if 2drop 0 exit then
  then next 2drop -1 ;

: ?apply ( a a a -- a, R: ? -- ?| )
  >r over swap match if r> cr count type cr rdrop exit then r> ;

: apply ( a -- a )
 $" @ "  $"  @"  ?apply
 $" @."  $"  ~"  ?apply
 $" @* " $"  @*" ?apply
 $" @*." $"  @&" ?apply
 $" @&." $"  ~&" ?apply
 $" @& " $"  ~*" ?apply
 $" ~ ?" $" .@?" ?apply
 $" ~.?" $" .~?" ?apply
 $" ~* " $" .@*" ?apply
 $" ~*." $" .@&" ?apply
 $" ~&." $" .~&" ?apply
 $" ~& " $" .~*" ?apply ;

\ : pack ;  ( u0...un b n -- )
\ : apply ; ( a -- a )

: locate ( b u c -- u f )
  >r
  begin
    ?dup
  while
    1- 2dup + c@ r@ = if nip rdrop -1 exit then
  repeat
  rdrop
  drop
  0 0 ; 

: 2* 1 lshift ;
: relative swap c/b * + + ( $3ff and ) ; ( +x +y pos -- pos )
: +position position @ relative ; ( +x +y -- pos )
: double 2* swap 2* swap ;
: arena blk @ block b/buf ; ( -- b u )
: >arena arena drop + ; ( pos -- a )
: fetch ( +x +y -- a a a )
  2dup   +position >arena >r
  double +position >arena r> swap
  position @ >arena -rot ;

: ./ [char] / emit ; ( -- )
: xy position @ dup c/b mod swap c/b / ; ( -- x y )
: .xy swap 3 u.r ./ 0 u.r ; ( -- x y )
\ @todo turn into arbitrary character count
: #bolders ( -- n )
   0 arena 
   for aft 
     dup c@ bolder = if n1+ then 
     1+ 
   then next drop ; 
: .bolders  ." BOLDERS: " #bolders u. cr ;
: .position ." X/Y:" xy .xy cr ;
: .moves    ." MOVES: " moves    @ u. cr ;
: .help     ." WASD - MOVEMENT" cr ." H    - HELP" cr ;
: .maze blk @ list ;
: show ( page cr ) .maze .position .bolders .moves .help ; ( -- )
: solved? #bolders 0= ;             ( -- )
: finished? solved? if 1 throw then ; ( -- )
: instructions ; ( -- )
: player! arena player locate 0= throw position ! ;
: start player! 0 moves ! ;
: cswap 2dup swap c@ swap c@ >r swap c! r> swap c! ; ( a a -- )
: aposition position @ >arena ; ( -- a )
: rules +position >arena aposition cswap player! ; ( +x +y -- )
: +move 1 moves +! ;
: ?ignore over <> if rdrop then ; ( c1 c2 --, R: x -- | x : exit caller <> )
: left  [char] a ?ignore -1  0 rules +move ; ( c -- c )
: right [char] d ?ignore  1  0 rules +move ; ( c -- c )
: up    [char] w ?ignore  0 -1 rules +move ; ( c -- c )
: down  [char] s ?ignore  0  1 rules +move ; ( c -- c )
: help  [char] h ?ignore instructions ; ( c -- c )
: end   [char] q ?ignore drop 2 throw ; ( c -- | c, R ? -- | ? )
: default drop ;  ( c -- )
: command up down left right help end default finished? ;
: maze! maze block drop ;
: input key ; ( -- c )

sokoban-wordlist -order definitions
sokoban-wordlist +order

: sokoban 
  maze! start 
  begin 
    show input ' command catch ?dup 
  until u. cr ;


maze!
editor x
 1 i            XXXXX             
 2 i            X   X             
 3 i            X*  X             
 4 i          XXX  *XXX           
 5 i          X  *  * X           
 6 i        XXX X XXX X     XXXXXX
 7 i        X   X XXX XXXXXXX  ..X
 8 i        X *  *             ..X
 9 i        XXXXX XXXX X@XXXX  ..X
10 i            X      XXX  XXXXXX
11 i            XXXXXXXX          
12 i        
q hex
\ forth hex

bye
