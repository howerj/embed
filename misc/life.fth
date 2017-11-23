0 ok!

\ Conways Game of Life 
\ https://en.wikipedia.org/wiki/Conway%27s_Game_of_Life
\ Adapted From: http://wiki.c2.com/?ForthBlocks

\ To use:
\ ./forth eforth.blk ansi.fth life.fth /dev/stdin
\ This requires an ANSI compliant terminal emulator

only forth anonymous definitions
( Add words to anonymous vocabulary )

variable stateblk
variable lifeblk
variable statep

: wrapy  dup 0< if drop $f then dup $f > if drop 0 then ;
: wrapx  dup 0< if drop $3f then dup $3f > if drop 0 then ;
: wrap   wrapy swap wrapx swap ;
: deceased?  wrap $40 * + lifeblk @ block + c@ bl = ;
: living?  deceased? 0= ;
: (-1,-1)  2dup 1- swap 1- swap living? 1 and ;
: (0,-1)  >r 2dup 1- living? 1 and r> + ;
: (1,-1)  >r 2dup 1- swap 1+ swap living? 1 and r> + ;
: (-1,0)  >r 2dup swap 1- swap living? 1 and r> + ;
: (1,0)   >r 2dup swap 1+ swap living? 1 and r> + ;
: (-1,1)  >r 2dup 1+ swap 1- swap living? 1 and r> + ;
: (0,1)   >r 2dup 1+ living? 1 and r> + ;
: (1,1)   >r 1+ swap 1+ swap living? 1 and r> + ;
: neighbors  (-1,-1) (0,-1) (1,-1) (-1,0) (1,0) (-1,1) (0,1) (1,1) ;
: born?  neighbors 3 = ;
: survives?  2dup living? -rot neighbors 2 = and ;
: lives?  2dup born? -rot survives? or ;
: newstate  stateblk @ block update statep ! ;
: state!  statep @ c! 1 statep +! ;
: alive [char] * state! ; ( * )
: dead  bl state! ;  ( space )
: iterate-cell  2dup swap lives? if alive else dead then ;
: iterate-row  0 begin dup $40 < while iterate-cell 1+ repeat drop ;
: iterate-block  0 begin dup $10 < while iterate-row 1+ repeat drop ;
: generation  lifeblk @ stateblk @ lifeblk ! stateblk ! ;
: iterate  newstate iterate-block generation ;
: done?  key [char] q = ;
: prompt  cr  ." press q to exit" cr ;
: view ( page ) lifeblk @ list prompt ;
: initialize
  b/buf for aft lifeblk @ block r@ + random 1 and 
  if bl else [char] * then swap c! then next ;

get-order -rot swap rot set-order definitions

\ life uses two blocks, k and k+1, k contains the Game of Life,
\ '*' are alive cells, spaces are dead cells, if 'f' is true
\ then the block will be initialized with a random values

: life  ( k f -- )
  swap dup 1+ stateblk ! lifeblk !
  if initialize then 
  begin view iterate done? until ;

: demo $20 -1 life ;

only forth definitions

