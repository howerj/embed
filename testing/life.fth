0 <ok> !

\ Adapted from: http://wiki.c2.com/?ForthBlocks
\ @todo port this code and store it in block RAM

only forth definitions hex
variable life-vocabulary
life-vocabulary +order definitions

   $40 constant c/b
   $10 constant l/b
c/b 1- constant c/b>
l/b 1- constant l/b>
    bl constant off
char * constant on

variable state-blk
variable life-blk
variable statep

: wrapy dup 0< if drop l/b> then dup l/b> > if drop 0 then ;
: wrapx dup 0< if drop c/b> then dup c/b> > if drop 0 then ;
: wrap  wrapy swap wrapx swap ;
: deceased? wrap c/b * + life-blk @ block + c@ off = ;
: living?  deceased? 0= ;
: (-1,-1) 2dup 1- swap 1- swap living? 1 and ;
: (0,-1)  >r 2dup 1- living? 1 and r> + ;
: (1,-1)  >r 2dup 1- swap 1+ swap living? 1 and r> + ;
: (-1,0)  >r 2dup swap 1- swap living? 1 and r> + ;
: (1,0)   >r 2dup swap 1+ swap living? 1 and r> + ;
: (-1,1)  >r 2dup 1+ swap 1- swap living? 1 and r> + ;
: (0,1)   >r 2dup 1+ living? 1 and r> + ;
: (1,1)   >r 1+ swap 1+ swap living? 1 and r> + ;
: mates (-1,-1) (0,-1) (1,-1) (-1,0) (1,0) (-1,1) (0,1) (1,1) ;
: born?  mates 3 = ;
: survives?  2dup living? -rot mates 2 = and ;
: lives?  2dup born? -rot survives? or ;        ( u u -- )
: newstate  state-blk @ block update statep ! ; ( -- )
: state!  statep @ c! 1 statep +! ;             ( c -- )
: alive  on state! ;                            ( -- )
: dead  off state! ;                            ( -- )
: cell?  2dup swap lives? if alive else dead then ; ( u u -- )
: rows   0 begin dup c/b < while cell? 1+ repeat drop ;
: iterate-block 0 begin dup l/b < while rows 1+ repeat drop ;
: generation  life-blk @ state-blk @ life-blk ! state-blk ! ;
: iterate  newstate iterate-block generation ;
: done?  key [char] q = ;                      ( -- f )
: prompt  cr ." q to quit" cr ;                ( -- )
: view (  page ) life-blk @ list prompt ;      ( -- )
: game  begin view iterate done? until ;       ( -- )

variable seed here seed !
: random seed 1 cells crc ?dup 0= if here then dup seed ! ;

: randomize ( k -- )
  block b/buf 
  for aft 
    random 1 and if on else off then over c! 1+ 
  then next
  drop ;

life-vocabulary -order definitions
life-vocabulary +order

: life life-blk ! state-blk ! game ;       ( k1 k2 -- )
: random-life $20 randomize $21 $20 life ; ( -- )

only forth definitions hex

editor $20 b x
3 i      ***   
4 i      *     
5 i       *    
q
hex

.( Usage: $21 $20 life ) cr

bye

