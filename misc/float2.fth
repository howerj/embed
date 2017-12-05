\ FORTH-83 FLOATING POINT.
\  ----------------------------------
\  COPYRIGHT 1985 BY ROBERT F. ILLYES
\ 
\        PO BOX 2516, STA. A
\        CHAMPAIGN, IL 61820
\        PHONE: 217/826-2734       
hex

\ @todo implement the double cell wordset
\ : d2* ;
\ : d2/ ;
\ : d+ ;
\ : d- ;
: not invert ;
: d0= 0= swap 0= and ;
: 2swap >r -rot r> -rot ;
: dnegate invert >r invert 1 um+ r> + ; ( d -- d )
: 0< 0 < ;
: dabs  dup 0< if dnegate then ;
: cell- 1 cells - ;
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
: 2* 1 lshift ;
: 2/ 1 rshift ;

: (do)  r> dup >r swap rot >r >r cell+ >r ;  ( compile-only ) 
: do compile (do) 0 , here ;  ( compile-only )  immediate
: (leave) r> drop r> drop r> drop ;  ( compile-only ) 
: leave compile (leave) ;  ( compile-only )  immediate
: (loop)
   r> r> 1+ r> 2dup <> if
    >r >r @ >r exit
   then >r 1- >r cell+ >r ;  ( compile-only ) 
: (unloop) r> r> drop r> drop r> drop >r ;  ( compile-only ) 
: unloop compile (unloop) ;  ( compile-only )  immediate
: (?do)
   2dup <> if
     r> dup >r swap rot >r >r cell+ >r exit
   then 2drop exit ;  ( compile-only ) 
: ?do  compile (?do) 0 , here ;  ( compile-only )  immediate
: loop  
  compile (loop) dup , compile (unloop) cell- here 1 rshift swap ! ; 
   ( compile-only )  immediate



: zero  over 0= if drop 0 then ;
: fnegate 8000 xor zero ;
: fabs  7fff and ;
: norm  >r 2dup or
        if begin dup 0< not
           while d2* r> 1- >r
           repeat swap 0< - ?dup
           if r> else 8000 r> 1+ then
        else r> drop then ;

: f2*   1+ zero ;
: f*    rot + 4000 - >r um* r> norm ;
: fsq   2dup f* ;

: f2/   1- zero ;
: um/   dup >r um/mod swap r>
        over 2* 1+ u< swap 0< or - ;
: f/    rot swap - 4000 + >r
        0 rot rot 2dup u<
        if   um/ r> zero
        else >r d2/ fabs r> um/ r> 1+
        then ;

: align 20 min 0 do d2/ loop ;
: ralign 1- ?dup if align then
        1 0 d+ d2/ ;
: fsign fabs over 0< if >r dnegate r>
        8000 or then ;

: f+    rot 2dup >r >r fabs swap fabs -
        dup if dup 0<
                if   rot swap  negate
                     r> r> swap >r >r
                then 0 swap ralign
        then swap 0 r> r@ xor 0<
        if   r@ 0< if 2swap then d-
             r> fsign rot swap norm
        else d+ if 1+ 2/ 8000 or r> 1+
                else r> then then ;

: f-    fnegate f+ ;
: f<    f- 0< swap drop ;

( floating point input/output ) decimal
bye
create pl 3 , here  ,001 , ,   ,010 , ,
          ,100 , ,            1,000 , ,
        10,000 , ,          100,000 , ,
     1,000,000 , ,       10,000,000 , ,
   100,000,000 , ,    1,000,000,000 , ,

: tens  2* 2* literal + 2@ ;     hex
: places pl ! ;
: shifts fabs 4010 - dup 0< not
        abort" too big" negate ;
: f#    >r pl @ tens drop um* r> shifts
        ralign pl @ ?dup if 0 do # loop
        [char] . hold then #s rot sign ;
: tuck  swap over ;
: f.    tuck <# f# #> type space ;
: dfloat 4020 fsign norm ;
: f     dfloat point tens dfloat f/ ;
: fconstant f 2constant ;

: float dup 0< dfloat ;
: -+    drop swap 0< if negate then ;
: fix   tuck 0 swap shifts ralign -+ ;
: int   tuck 0 swap shifts  align -+ ;

1.      fconstant one decimal
34.6680 fconstant x1
-57828. fconstant x2
2001.18 fconstant x3
1.4427  fconstant x4

: exp   2dup int dup >r float f-
        f2* x2 2over fsq x3 f+ f/
        2over f2/ f-     x1 f+ f/
        one f+ fsq r> + ;
: fexp  x4 f* exp ;
: get   bl word dup 1+ c@ [char] - = tuck -
        0 0 rot convert drop -+ ;
: e     f get >r r@ abs 13301 4004 */mod
        >r float 4004 float f/ exp r> +
        r> 0< if f/ else f* then ;

: e.    tuck fabs 16384 tuck -
        4004 13301 */mod >r
        float 4004 float f/ exp f*
        2dup one f<
        if 10 float f* r> 1- >r then
        <# r@ abs 0 #s r> sign 2drop
        [char] e hold f# #>     type space ;
