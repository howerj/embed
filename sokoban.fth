0 <ok> !
only forth definitions hex
\ @todo improve drawing routine instead of using 'list', 
\ colorize as well
\ NB. 'blk' contains the last block retrieved by 'block', not 
\ 'load' in this Forth

variable sokoban-wordlist
sokoban-wordlist +order definitions

\ @todo change character set
$20    constant maze
char X constant wall
char * constant bolder
char . constant off
char & constant on
char @ constant player
char ~ constant player+ ( player + off pad )
$10    constant l/b     ( lines   per block )
$40    constant c/b     ( columns per block )
     7 constant bell    ( bell character )

variable position  ( current player position )
variable moves     ( moves made by player )

( used to store rule being processed )
create rule 3 c, 0 c, 0 c, 0 c, 

: n1+ swap 1+ swap ; ( n n -- n n )
: match              ( a a -- f )
  n1+ ( replace with umin of both counts? )
  count 
  for aft  
    count rot count rot <> if 2drop rdrop 0 exit then
  then next 2drop -1 ;

: beep bell emit ; ( -- )
: ?apply           ( a a a -- a, R: ? -- ?| )
  >r over swap match if drop r> rdrop exit then rdrop ;

: apply ( a -- a )
 $" @ "  $"  @"  ?apply 
 $" @."  $"  ~"  ?apply
 $" @* " $"  @*" ?apply
 $" @*." $"  @&" ?apply
 $" @&." $"  ~&" ?apply
 $" @& " $"  ~*" ?apply
 $" ~ "  $" .@"  ?apply
 $" ~."  $" .~"  ?apply
 $" ~* " $" .@*" ?apply
 $" ~*." $" .@&" ?apply
 $" ~&." $" .~&" ?apply
 $" ~& " $" .~*" ?apply beep ;

: pack ( c0...cn b n -- )
  2dup swap c! for aft 1+ tuck c! then next drop ; 

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

: 2* 1 lshift ; ( u -- )
: relative swap c/b * + + ( $3ff and ) ; ( +x +y pos -- pos )
: +position position @ relative ; ( +x +y -- pos )
: double 2* swap 2* swap ;  ( u u -- u u )
: arena blk @ block b/buf ; ( -- b u )
: >arena arena drop + ;     ( pos -- a )
: fetch                     ( +x +y -- a a a )
  2dup   +position >arena >r
  double +position >arena r> swap
  position @ >arena -rot ;
: rule@ fetch c@ rot c@ rot c@ rot ; ( +x +y -- c c c )
: 3reverse -rot swap ;               ( 1 2 3 -- 3 2 1 )
: rule! rule@ 3reverse rule 3 pack ; ( +x +y -- )
: think 2dup rule! rule apply >r fetch r> ; ( +x +y --a a a a )
: count! count rot c! ;              ( a a -- )

\ 'act' could be made to be more elegant, but it works, it 
\ handles rules of length 2 and length 3
: act ( a a a a -- )
  count swap >r 2 = 
  if 
     drop swap r> count! count! 
  else 
     3reverse r> count! count! count! 
  then drop ;

: #bolders ( -- n )
   0 arena 
   for aft 
     dup c@ bolder = if n1+ then 
     1+ 
   then next drop ; 
: .bolders  ." BOLDERS: " #bolders u. cr ; ( -- )
: .moves    ." MOVES: " moves    @ u. cr ; ( -- )
: .help     ." WASD - MOVEMENT" cr ." H    - HELP" cr ; ( -- )
: .maze blk @ list ;                  ( -- )
: show ( page cr ) .maze .bolders .moves .help ; ( -- )
: solved? #bolders 0= ;               ( -- )
: finished? solved? if 1 throw then ; ( -- )
: instructions ;                      ( -- )
: where >r arena r> locate ;          ( c -- u f )
: player? player where 0= if drop player+ where else -1 then ; 
: player! player? 0= throw position ! ; ( -- )
: start player! 0 moves ! ;           ( -- )
: .winner show cr ." SOLVED!" cr ;    ( -- )
: .quit cr ." Quitter!" cr ;          ( -- )
: finish 1 = if .winner exit then .quit ; ( n -- )
: rules think act player! ;           ( +x +y -- )
: +move 1 moves +! ;                  ( -- )
: ?ignore over <> if rdrop then ;     ( c1 c2 --, R: x -- | x )
: left  [char] a ?ignore -1  0 rules +move ; ( c -- c )
: right [char] d ?ignore  1  0 rules +move ; ( c -- c )
: up    [char] w ?ignore  0 -1 rules +move ; ( c -- c )
: down  [char] s ?ignore  0  1 rules +move ; ( c -- c )
: help  [char] h ?ignore instructions ; ( c -- c )
: end  [char] q ?ignore drop 2 throw ; ( c -- | c, R ? -- | ? )
: default drop ;  ( c -- )
: command up down left right help end default finished? ;
: maze! block drop ; ( k -- )
: input key ;        ( -- c )

sokoban-wordlist -order definitions
sokoban-wordlist +order

: sokoban ( k -- )
  maze! start 
  begin 
    show input ' command catch ?dup 
  until finish ;

$20 maze!
only forth definitions

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
n x
 1 i       XXXXXXXXXXXX  
 2 i       X..  X     XXX
 3 i       X..  X *  *  X
 4 i       X..  X*XXXX  X
 5 i       X..    @ XX  X
 6 i       X..  X X  * XX
 7 i       XXXXXX XX* * X
 8 i         X *  * * * X
 9 i         X    X     X
10 i         XXXXXXXXXXXX
11 i       
n x
 1 i               XXXXXXXX 
 2 i               X     @X 
 3 i               X *X* XX 
 4 i               X *  *X  
 5 i               XX* * X  
 6 i       XXXXXXXXX * X XXX
 7 i       X....  XX *  *  X
 8 i       XX...    *  *   X
 9 i       X....  XXXXXXXXXX
10 i       XXXXXXXX         
n x
 1 i                     XXXXXXXX
 2 i                     X  ....X
 3 i          XXXXXXXXXXXX  ....X
 4 i          X    X  * *   ....X
 5 i          X ***X*  * X  ....X
 6 i          X  *     * X  ....X
 7 i          X ** X* * *XXXXXXXX
 8 i       XXXX  * X     X       
 9 i       X   X XXXXXXXXX       
10 i       X    *  XX            
11 i       X **X** @X            
12 i       X   X   XX            
13 i       XXXXXXXXX             

q hex bye

