\ From: http://wiki.c2.com/?ForthBlocks
\ @todo port this code and store it in block RAM
\ @todo Port this program
\ and altiernative Game of Life is avaialble at:
\ 	<http://turboforth.net/fun/life.html>

decimal

variable stateblk
variable lifeblk
variable statep

\ : -rot	rot rot ;

: wrapy	dup 0< if drop 15 then dup 15 > if drop 0 then ;
: wrapx	dup 0< if drop 63 then dup 63 > if drop 0 then ;
: wrap	wrapy swap wrapx swap ;
: deceased?	wrap 64 * + lifeblk @ block + c@ 32 = ;
: living?	deceased? 0= ;
: (-1,-1)	2dup 1- swap 1- swap living? 1 and ;
: (0,-1)	>r 2dup 1- living? 1 and r> + ;
: (1,-1)	>r 2dup 1- swap 1+ swap living? 1 and r> + ;
: (-1,0)	>r 2dup swap 1- swap living? 1 and r> + ;
: (1,0)	>r 2dup swap 1+ swap living? 1 and r> + ;
: (-1,1)	>r 2dup 1+ swap 1- swap living? 1 and r> + ;
: (0,1)	>r 2dup 1+ living? 1 and r> + ;
: (1,1)	>r 1+ swap 1+ swap living? 1 and r> + ;
: neighbors	(-1,-1) (0,-1) (1,-1) (-1,0) (1,0) (-1,1) (0,1) (1,1) ;
: born?	neighbors 3 = ;
: survives?	2dup living? -rot neighbors 2 = and ;
: lives?	2dup born? -rot survives? or ;
: newstate	stateblk @ block update statep ! ;
: state!	statep @ c! 1 statep +! ;
: alive	42 state! ;
: dead	32 state! ;
: iterate-cell	2dup swap lives? if alive else dead then ;
: iterate-row  0 begin dup 64 < while iterate-cell 1+ repeat drop ;
: iterate-block	0 begin dup 16 < while iterate-row 1+ repeat drop ;
: generation	lifeblk @ stateblk @ lifeblk ! stateblk ! ;
: iterate	newstate iterate-block generation ;
: done?	key [char] q = ;
: prompt	cr ." press q to exit; other key to continue" ;
: view	page lifeblk @ list prompt ;
: life	begin view iterate done? until ;
