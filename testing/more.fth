0 <ok> !
\ This file contains utility functions, more of the core Forth word set,
\ a soft floating point library and allocation functions. Different sections
\ of the file come from different sources and are clearly marked.
\ 
\ This file contains experimental code, which may not work.
\ 

\ @todo Adapt the pattern matcher from <http://c-faq.com/lib/regex.html>
\ int match(char *pat, char *str)
\ {
\ 	switch(*pat) {
\ 	case '\0':  return !*str;
\ 	case '*':   return match(pat+1, str) ||
\ 				*str && match(pat, str+1);
\ 	case '?':   return *str && match(pat+1, str+1);
\ 	default:    return *pat == *str && match(pat+1, str+1);
\ 	}
\ }
 
\ variable hidden hidden +order
\ : hidden: get-current >r hidden set-current : r> set-current ;
only forth definitions
variable more
more +order definitions
: m: get-current >r [compile] : r> set-current ;

\ @todo Hide internal words in a separate vocabulary
\ @todo Document all the new words, including stack comments
: dnegate invert >r invert 1 um+ r> + ; ( d -- d )
: 2* 1 lshift  ;
: 2/ 1 rshift ;
: d2* over $8000 and >r 2* swap 2* swap r> if 1 or then ;
: d2/ dup      1 and >r 2/ swap 2/ r> if $8000 or then swap ;
: arshift ( n u -- n : arithmetic right shift )
  2dup rshift >r swap $8000 and
  if $10 swap - -1 swap lshift else drop 0 then r> or ;
: d+ rot + -rot um+ rot + ;
: d- dnegate d+ ;
: not invert ;
: d= rot = -rot = and ;
: 2swap >r -rot r> -rot ;
: dabs  dup 0< if dnegate then ;
: s>d dup 0< ; 
: 2over ( n1 n2 n3 n4 -- n1 n2 n3 n4 n1 n2 )
  >r >r 2dup r> swap >r swap r> r> -rot ;

\ $fffe constant rp0
\ : rdepth rp0 rp@ - chars ;
\ @todo 'rpick' picks the wrong way around
\ : rpick cells cell+ rp0 swap - @ ; 

\ @todo do not print out 'r.s' on its loop counter when 'r.s' runs
\ : r.s ( -- print out the return stack )
\  [char] < emit rdepth 0 u.r [char] > emit
\  rdepth for aft r@ rpick then next 
\  rdepth for aft u. then next ;

: +leading ( b u -- b u: skip leading space )
    begin over c@ dup bl = swap 9 = or while 1 /string repeat ;

\ @todo fix >number and numeric input to work with doubles...
: >d ( a u -- d|ud )
  0 0 2swap +leading
  ?dup if
    0 >r ( sign )
    over c@
    dup  [char] - = if drop rdrop -1 >r 1 /string 
    else [char] + = if 1 /string then then
    >number 2drop
    r> if dnegate then ( retrieve sign )
  else drop then ;
: 2, , , ;
: 2constant create 2, does> 2@ ;
: 2variable create 2, does> ;
: rdup r> r> dup >r >r >r ;  ( --, R: u -- u u )

: log ( u base -- u : command the integer logarithm of u in base )
  >r dup 0= if -$b throw then ( logarithm of zero is an error )
  0 swap begin
    swap 1+ swap r@ / dup 0= ( keep dividing until 'u' is zero )
  until
  drop 1- rdrop ;

: log2 2 log ; ( u -- u : binary integer logarithm )

: #digits ( u -- u : characters needed to represent 'u' in base )
  dup 0= if 1+ exit then base @ log 1+ ;

: digits ( -- u : characters needed to represent largest number in base )
 -1 #digits ;

\ ## DO LOOP

\ : (do)  r> dup >r swap rot >r >r cell+ >r ;  compile-only 
\ : do compile (do) 0 , here ;  compile-only  immediate
\ : (leave) r> drop r> drop r> drop ;  compile-only 
\ : leave compile (leave) ;  compile-only  immediate
\ : (loop)
\    r> r> 1+ r> 2dup <> if
\     >r >r @ >r exit
\    then >r 1- >r cell+ >r ;  compile-only 
\ : (unloop) r> r> drop r> drop r> drop >r ;  compile-only 
\ : unloop compile (unloop) ;  compile-only  immediate
\ : (?do)
\    2dup <> if
\      r> dup >r swap rot >r >r cell+ >r exit
\    then 2drop exit ;   compile-only  
\ : ?do  compile (?do) 0 , here ;  compile-only  immediate
\ : loop  
\   compile (loop) dup , compile (unloop) cell- here 1 rshift swap ! ; 
\     compile-only  immediate

\ ## Dynamic Memory Allocation
\ alloc.fth
\  Dynamic Memory Allocation package
\  this code is an adaptation of the routines by
\  Dreas Nielson, 1990; Dynamic Memory Allocation;
\  Forth Dimensions, V. XII, No. 3, pp. 17-27
\ @todo This could use refactoring and better error checking, 'free' could
\ check that its arguments are within bounds and on the free list

\ pointer to beginning of free space
variable freelist  0 , 

\ : cell_size ( addr -- n ) >body cell+ @ ;       \ gets array cell size

: initialize ( start_addr length -- : initialize memory pool )
  over dup freelist !  0 swap !  swap cell+ ! ;

: allocate ( u -- addr ior ) \ allocate n bytes, return pointer to block
                             \ and result flag ( 0 for success )
                             \ check to see if pool has been initialized 
  freelist @ 0= abort" pool not initialized! " 
  cell+ freelist dup
  begin
  while dup @ cell+ @ 2 pick u<
    if 
      @ @ dup   \ get new link
    else   
      dup @ cell+ @ 2 pick - 2 cells max dup 2 cells =
      if 
        drop dup @ dup @ rot !
      else  
        over over swap @ cell+ !   swap @ +
      then
      over over ! cell+ 0  \ store size, bump pointer
    then                   \ and set exit flag
  repeat
  swap drop
  dup 0= ;

: free ( ptr -- ior ) \ free space at ptr, return status ( 0 for success )
  1 cells - dup @ swap over over cell+ ! freelist dup
  begin
    dup 3 pick u< and
  while
    @ dup @
  repeat

  dup @ dup 3 pick ! ?dup
  if 
    dup 3 pick 5 pick + =
    if 
      dup cell+ @ 4 pick + 3 pick cell+ ! @ 2 pick !
    else  
      drop 
    then
  then

  dup cell+ @ over + 2 pick =
  if  
    over cell+ @ over cell+ dup @ rot + swap ! swap @ swap !
  else 
    !
  then
  drop 0 ; \ this code always returns a success flag

\ create pool  1000 allot
\ pool 1000 dynamic-mem
\ 5000 1000 initialize
\ 5000 100 dump
\ 40 allocate throw
\ 80 allocate throw .s swap free throw .s 20 allocate throw .s cr
 
