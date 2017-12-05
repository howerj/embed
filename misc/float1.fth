\ Adapted from:
\ Floating Point routines by Michael Jesch 
\ From Forth Dimensions, Volume 4, Number I

\ @todo Complete this, and test it, add comments, and implement do...loop
\ @todo find out which version of rot '<rot' is
\ @todo implement m*/

hex
: d0= 0= swap 0= and ;
: dabs abs swap abs swap ;
: 2swap >r -rot r> -rot ;
: dnegate invert >r invert 1 um+ r> + ; ( d -- d )
: 0< 0 < ;
: dabs  dup 0< if dnegate then ;
: s>d dup 0< ; 
$f constant #bits
: um/mod ( ud u -- ur uq )
 ?dup 0= if -a throw then
 2dup u<
 if negate #bits
   for >r dup um+ >r >r dup um+ r> + dup
     r> r@ swap >r um+ r> or
     if >r drop 1+ r> else drop then r>
   next
   drop swap exit
 then drop 2drop -1 dup ;

: m*/  
  >r s>d >r abs -rot s>d r> xor r> swap >r >r dabs rot tuck um* 2swap um* swap
  >r 0 d+ r> -rot i um/mod -rot r> um/mod -rot r> 
  if if 1 0 d+ then dnegate else drop then ; 

variable fpsw
fpsw 1 + constant fbase

: freset 0 fpsw c! ;
: finit  base @ fbase ! ;
: fer fpsw c@ ;
: fze fer 1 and 0= invert ;
: fne fer 2 and 0= invert ;
: fov fer 4 and 0= invert ;
hex
: sfz fer $fffe and fpsw c!
  2dup $00ff and d0= fer or fpsw c! ;
: sfn fer $fffd and fpsw c!
  dup $0080 and $40 / fer or fpsw c! ;
: @exponent 
  freset sfz sfn 
  dup $ff00 and $100 / >r
  fne if
    $ff00 or
  else
    $00ff and
  then r> ;
: !exponent
  dup $100 * dup $100 / rot <> if
   4 fpsw c!
  then
  swap dup $ff00 and dup if
    dup $ff00 <> if 
     4 fpsw c!
    then
  then drop
  $00ff and or
  sfz sfn ;
: f.
  @exponent >r
  swap over dabs
  <# r@ 0< if
   r@ abs 0 do * loop [char] . hold
  else
   [char] . hold r@ if
     r@ 0 do [char] 0 hold loop 
   then
  then rdrop
  #s sign #> type space ;
\ : e. @exponent rot (d.) type ." . e" . ;

: f*
  2swap @exponent >r
  2swap @exponent >r
  drop 1 m*/
  r> r> + !exponent ;

: f/
  2swap @exponent >r
  2swap @exponent >r
  drop 1 swap m*/
  r> r> + !exponent ;

