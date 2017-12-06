0 ok!

\ @todo Add these word definitions to an extension file, the floating
\ point routines will have to go into yet another file
\ @todo Rewrite the do..loop to a more sensible 'for' loop.
: dnegate invert >r invert 1 um+ r> + ; ( d -- d )
: 2* 1 lshift  ;
: 2/ 1 rshift ;
: d2* over $8000 and >r 2* swap 2* swap r> if 1 or then ;
: d2/ dup     1 and >r 2/ swap 2/ r> if $8000 or then swap ;
: arshift ( n u -- n : arithmetic right shift )
  2dup rshift >r swap $8000 and
  if $10 swap - -1 swap lshift else drop 0 then r> or ;
: d+ rot + -rot um+ rot + ;
: d- dnegate d+ ;
: not invert ;
: d0= 0= swap 0= and ;
: 2swap >r -rot r> -rot ;
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

\ The following section implements the floating point word set in Forth, it 
\ does so with an unusual way of representing floating point numbers, but it
\ works and the word definitions are very small. The special values such
\ as Non-A-Number (NaN) and +/- infinity are not handled, but could be
\ added in, and error conditions such as division by zero do not trap, which
\ is trivial to add in. The original document is marked and reproduced
\ at the end of this code section, after a 'bye' to make sure it does not
\ get executed.
\ 
\ The copyright status of this code is unclear, it states in the original
\ text that the following code may be used without a free so long as the
\ copyright notices appears in the source code, which appears below:
\ 
\ FORTH-83 FLOATING POINT.
\  ----------------------------------
\  COPYRIGHT 1985 BY ROBERT F. ILLYES
\ 
\        PO BOX 2516, STA. A
\        CHAMPAIGN, IL 61820
\        PHONE: 217/826-2734
\ 
\ The original source code has been adapted to work with the Forth
\ available at <https://github.com/howerj/embed>
\ It was originally found somewhere on <ftp://ftp.taygeta.com/pub/Forth/>
\ (I believe).
\ Another floating point implementation is available in Forth Dimensions
\ Volume 4, Issue 1, by Michael Jesch.

hex

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

: shifts fabs 4010 - dup 0< not
        abort" too big" negate ;
: dfloat 4020 fsign norm ;
: float dup 0< dfloat ;
: -+    drop swap 0< if negate then ;
: fix   tuck 0 swap shifts ralign -+ ;
: int   tuck 0 swap shifts  align -+ ;
hide align
hide ralign
hide shifts

\ The following code relies on F-83 number parsing, and will have to be
\ adapted to run under more modern Forths, or portably.

( floating point input/output ) decimal
bye
create pl 3 , here  ,001 , ,   ,010 , ,
          ,100 , ,            1,000 , ,
        10,000 , ,          100,000 , ,
     1,000,000 , ,       10,000,000 , ,
   100,000,000 , ,    1,000,000,000 , ,

: tens  2* 2* literal + 2@ ;     hex
: places pl ! ;
: f#    >r pl @ tens drop um* r> shifts
        ralign pl @ ?dup if 0 do # loop
        [char] . hold then #s rot sign ;
: f.    tuck <# f# #> type space ;
: f     dfloat point tens dfloat f/ ;
: fconstant f 2constant ;

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

bye
\ ======================  The Original File ==================================

Vierte Dimension Vol.2, No.4 1986


        A FAST HIGH-LEVEL FLOATING POINT

                Robert F. Illyes

                     ISYS
               PO Box 2516, Sta. A
               Champaign, IL 61820
               Phone: 217/359-6039

If binary normalization and rounding are used, a fast
single-precision FORTH floating point can be built with
accuracy adequate for many applications. The creation
of such high-level floating points has become of more
than academic interest with the release of the Novix
FORTH chip. The FORTH-83 floating point presented here
is accurate to 4.8 digits. Values may range from about
9E-4933 to about 5E4931. This floating point may be
used without fee provided the copyright notice and
associated information in the source are included.

FIXED VS. FLOATING POINT

FORTH programmers have traditionally favored fixed over
floating point. A fixed point application is harder to
write. The range of each value must be known and
considered carefully, if adequate accuracy is to be
maintained and overflow avoided. But fixed point
applications are much more compact and often much
faster than floating point (in the absence of floating
point hardware).

The debate of fixed vs. floating point is at least as
old as the ENIAC, the first electronic digital
computer. John von Neumann used fixed point on the
ENIAC. He felt that the detailed understanding of
expressions required by fixed point was desirable, and
that fixed point was well worth the extra time (1).

But computers are no longer the scarce resource that
they once were, and the extra programming time is often
more costly than any advantages offered by fixed point.
For getting the most out of the least hardware,
however, fixed point will always be the technique of
choice.

Fixed point arithmetic represents a real number as a
ratio of integers, with an implicit divisor. This
implicit divisor may be thought of as the
representation of unity. If unity were represented by
300, for example, 2.5 would be represented by 750.

To multiply 2.5 by 3.5, with all values representing
unity as ten, one would evaluate

                     25 * 35
                     -------
                       10

The ten is called a scale factor, and the division by
ten is called a scaling operation. This expression is
obviously inefficient, requiring both a division and a
multiplication to accomplish a multiplication.

Most scaling operations can, however, be eliminated by
a little algebraic manipulation. In the case of the sum
of two squares, for example, where A and B are fixed
point integers and unity is represented by the integer
U,

      A * A   B * B           (A * A)+(B * B)
      ----- + -----    -->    ---------------
        U       U                    U

In addition to the elimination of a division by U, the
right expression is more accurate. Each division can
introduce some error, and halving the number of
divisions halves the worst-case error.

DECIMAL VS. BINARY NORMALIZATION

A floating point number consists of two values, an
exponent and a mantissa. The mantissa may represent
either an integer or a fraction. The exponent and the
mantissa are related to each other in the same way as
the value and power of ten in scientific notation are
related.

A mantissa is always kept as large as possible. This
process is called normalization. The following
illustrates the action of decimal normalization with an
unsigned integer mantissa:

         Value       Stack representation
               4

         5 * 10         50000  0  --
               3
           * 10          7000  0  --
               3
           * 10         50000 -1  --

The smallest the mantissa can become is 6554. If a
mantissa of 6553 is encountered, normalization requires
that it be made 65530, and that the exponent be
decremented. It follows that the worst-case error in
representing a real number is half of 1 part in 6554,
or 1 part in 13108. The error is halved because of the
rounding of the real number to the nearest floating
point value.

Had we been using binary normalization, the smallest
mantissa would have been 32768, and the worst case
error in representation would have been 1 part 65536,
or 1/5 that of decimal normalization. LOG10(65536) is
4.8, the accuracy in decimal digits.

As with fixed point, scaling operations are required by
floating point. With decimal normalization, this takes
the form of division and multiplication by powers of
ten. Unlike fixed point, no simple algebraic
manipulation will partly eliminate the scale factors.
Consequently there are twice as many multiplications
and divisions as the floating point operators would
seem to imply. Due to the presence of scaling in 73% of
decimally normalized additions (2), the amount is
actually somewhat over twice.

With binary normalization, by contrast, this extra
multiplication effectively disappears. The scaling by
a power of two can usually be handled with a single
shift and some stack manipulation, all fast operations.

Though a decimally normalized floating point can be
incredibly small (3), a binary normalized floating
point has 1/5 the error and is about twice as fast.

It should be mentioned that the mantissa should be
multiples of 2 bytes if the full speed advantage of
binary normalization is to be available. Extra shifting
and masking operations are necessary with odd byte
counts when using the 2-byte arithmetic of FORTH.

NUMBER FORMAT AND ARITHMETIC

This floating point package uses an unsigned single
precision fraction with binary normalization,
representing values from 1/2 to just under 1. The high
bit of the fraction is always set.

The sign of the floating point number is carried in the
high bit of the single precision exponent, The
remaining 15 bits of the exponent represent a power of
2 in excess 4000 hex. The use of excess 4000 permits
the calculation of the sign as an automatic outcome of
exponent arithmetic in multiplication and division.

A zero floating point value is represented by both a
zero fraction and a zero exponent. Any operation that
produces a zero fraction also zeros the exponent.

The exponent is carried on top of the fraction , so the
sign may be tested by the phrase DUP 0< and zero by the
phrase DUP 0= .

The FORTH-83 Double Number Extension Word Set is
required. Floating point values are used with the "2"
words: 2CONSTANT, 2@, 2DUP, etc.

There is no checking for exponent overflow or underflow
after arithmetic operation, nor is division by zero
checked for. The rationale for this is the same as with
FORTH integer arithmetic. By requiring that the user
add any such tests, 1) all arithmetic isn't slowed by
tests that are only sometimes needed and 2) the way in
which errors are resolved may be determined by the
user. The extremely large exponent range makes exponent
overflow and underflow quite unlikely, of course.

All of the arithmetic is rounding. The failure to round
is the equivalent of throwing a bit of accuracy away.
The representational accuracy of 4.8 digits will be
quickly lost without rounding arithmetic.

The following words behave like their integer
namesakes:

     F+  F-  F*  F/  F2*  F2/  FABS  FNEGATE  F<

Single precision integers may be floated by FLOAT, and
produced from floating point by FIX and INT, which are
rounding and truncating, respectively. DFLOAT floats a
double precision integer.

NUMBER INPUT AND OUTPUT

Both E and F formats are supported. A few illustrations
should suffice to show their usage. An underscore
indicates the point at which the return key is pressed.
PLACE determines the number of places to the right of
the decimal point for output only.

           12.34  F      F. _ 12.340
           12.34  F      E. _ 1.234E1
           .033 E -1002  E. _ 3.300E-1004

           4 PLACES

           2. F -3. F F/ F. _ -0.6667
           2. F -3. F F/ E. _ -6.6667E-1

F and E will correctly float any input string
representing a signed double precision number. There
may be as many as 9 digits to the right of the decimal
point. Numbers input by E are accurate to over 4
digits. F is accurate to the full 4.8 digits if there
are no digits to the right of the decimal point.
Conversion is slightly less accurate with zeros to the
right of the decimal point because a division by a
power of ten must be added to the input conversion
process.

F and E round the input value to the nearest floating
point value. So a sixth digit will often allow a more
accurately rounded conversion, even thought the result
is only accurate to 4.8 digits. There is no advantage
to including trailing zeros, however. In many floating
points, this extra accuracy can only be achieved by the
inconvenient procedure of entering the values as
hexadecimal integers.

Only the leftmost 5 digits of the F. output are
significant. F. displays values from 32767 to -32768,
with up to 4 additional places to the right of the
decimal point. The algorithm for F. avoids double
rounding by using integer rather than floating point
multiplication to scale by a power of ten. This gives
as much accuracy as possible at the expense of a
somewhat limited range. Since a higher limit on size
would display digits that are not significant, this
range limit does not seem at all undesirable.

Like E input, E. is accurate to somewhat over 4 digits.
The principal source of inaccuracy is the function EXP,
which calculates powers of 2.

The following extended fraction is used by EXP. It
gives the square root of 2 to the x power. The result
must be squared to get 2 to the x.

                      2x
         1 + ---------------------------
                              57828
             34.668 - x - --------------
                                        2
                          2001.18 + (2x)

In order to do E format I/O conversion, one must be
able to evaluate the expressions

         a   a/log10(2)        b    b*log10(2)
       10 = 2           and   2 = 10

These log expressions may be easily evaluated with
great precision by applying a few fixed point
techniques. First, a good rational approximation to
log10(2) is needed.

            log10(2)     = .3010299957
            4004 / 13301 = .3010299978

The following code will convert an integer power of
ten, assumed to be on the stack, into a power of 2:

               13301 4004 */MOD >R
               FLOAT 4004 FLOAT F/ EXP
               R> +

The first line divides the power of ten by log10(2) and
pushes the quotient on the return stack. The quotient
is the integer part of the power of two.

The second line finds the fractional part of the power
of two by dividing the remainder by the divisor. This
floating point fractional part is evaluated using EXP.

The third line adds the integer power of two into the
exponent of the floating point value of the fractional
part, completing the conversion.

The inverse process is used to convert a power of 2 to
a power of ten.

FORTH-83 LIMITATIONS

Perhaps the most serious deficiency in the FORTH-83
with extensibility as its pre-eminent feature, it is
surprisingly difficult to write standard code that will
alter the processing of numeric input strings by the
interpreter and compiler.

It is usually a simple matter to replace the system
conversion word (usually called NUMBER) with a routine
of ones choice. But there if no simple standard way of
doing this. The interpreter, compiler and abort
language are all interwoven, and may all have to be
replaced if a standard solution is sought.

This floating point package assumes that double
precision integers are generated if the numeric input
string contains a period, and that a word PLACES can be
written that will leave the number of digits to the
right of the period. This does not seem to be
guaranteed by FORTH-83, although it may be safely
assumed on most systems that include double precision.

If you know how this part of your system works, you
will probably want to eliminate the words E and F, and
instead force floating point conversion of any input
string containing a period. Double precision integers
could still be generated by using a comma or other
punctuation.

It is suggested that future FORTH standards include the
word NUMBER, which is a vector to the current input
numeric word.

It is also suggested that the Double Number Extension
Wordset specification include a requirement that the
interpreter and compiler be able to accept input
strings specifying double precision values.

COMMENTS ON THE FOLLOWING CODE

The words ". and "- leave the ASCII values for period
and minus, respectively. Replace these with whatever
language you prefer for insertion of ASCII values.

The size of F+ can be considerably reduced at the
expense of quite a lot of execution speed. Think twice
before you simplify it.

The normalizing word NORM expects the stack value under
the exponent to be a double precision signed integer.
It leaves a normalized floating point number, rounding
the double precision integer into the fraction.

ALIGN and RALIGN expect an integer shift count with an
unsigned double precision number beneath. They leave
double precision unsigned integer results. At least one
shift is always performed. RALIGN rounds after
alignment.

UM/ divides an unsigned double precision number by an
unsigned single precision number, and rounds the single
precision quotient.

ZERO forces a floating point value with a zero fraction
to also have a zero exponent.

FSIGN applies the sign of the stack value under the
exponent to the exponent. The double precision integer
under an exponent is left unsigned.

FEXP evaluates a power of e. It is included because it
is a trivial but useful application of EXP.

GET converts the next word in the input stream into a
single precision signed integer.

REFERENCES

1. Von Neumann, J., John von Neumann Collected Works,
vol. 5, p.113.

2. Knuth, D. K., The Art of Computer Programming,
second edition, vol. 2, pp. 238,9.

3. Tracy, M., Zen Floating Point, 1984 FORML Conference
Proceedings, pp. 33-35.


( FORTH-83 FLOATING POINT.
  ----------------------------------
  COPYRIGHT 1985 BY ROBERT F. ILLYES

        PO BOX 2516, STA. A
        CHAMPAIGN, IL 61820
        PHONE: 217/826-2734  )     HEX

: ZERO  OVER 0= IF DROP 0 THEN ;
: FNEGATE 8000 XOR ZERO ;
: FABS  7FFF AND ;
: NORM  >R 2DUP OR
        IF BEGIN DUP 0< NOT
           WHILE D2* R> 1- >R
           REPEAT SWAP 0< - ?DUP
           IF R> ELSE 8000 R> 1+ THEN
        ELSE R> DROP THEN ;

: F2*   1+ ZERO ;
: F*    ROT + 4000 - >R UM* R> NORM ;
: FSQ   2DUP F* ;

: F2/   1- ZERO ;
: UM/   DUP >R UM/MOD SWAP R>
        OVER 2* 1+ U< SWAP 0< OR - ;
: F/    ROT SWAP - 4000 + >R
        0 ROT ROT 2DUP U<
        IF   UM/ R> ZERO
        ELSE >R D2/ FABS R> UM/ R> 1+
        THEN ;

: ALIGN 20 MIN 0 DO D2/ LOOP ;
: RALIGN 1- ?DUP IF ALIGN THEN
        1 0 D+ D2/ ;
: FSIGN FABS OVER 0< IF >R DNEGATE R>
        8000 OR THEN ;

: F+    ROT 2DUP >R >R FABS SWAP FABS -
        DUP IF DUP 0<
                IF   ROT SWAP  NEGATE
                     R> R> SWAP >R >R
                THEN 0 SWAP RALIGN
        THEN SWAP 0 R> R@ XOR 0<
        IF   R@ 0< IF 2SWAP THEN D-
             R> FSIGN ROT SWAP NORM
        ELSE D+ IF 1+ 2/ 8000 OR R> 1+
                ELSE R> THEN THEN ;

: F-    FNEGATE F+ ;
: F<    F- 0< SWAP DROP ;

( FLOATING POINT INPUT/OUTPUT ) DECIMAL

CREATE PL 3 , HERE  ,001 , ,   ,010 , ,
          ,100 , ,            1,000 , ,
        10,000 , ,          100,000 , ,
     1,000,000 , ,       10,000,000 , ,
   100,000,000 , ,    1,000,000,000 , ,

: TENS  2* 2* LITERAL + 2@ ;     HEX
: PLACES PL ! ;
: SHIFTS FABS 4010 - DUP 0< NOT
        ABORT" TOO BIG" NEGATE ;
: F#    >R PL @ TENS DROP UM* R> SHIFTS
        RALIGN PL @ ?DUP IF 0 DO # LOOP
        ". HOLD THEN #S ROT SIGN ;
: TUCK  SWAP OVER ;
: F.    TUCK <# F# #> TYPE SPACE ;
: DFLOAT 4020 FSIGN NORM ;
: F     DFLOAT POINT TENS DFLOAT F/ ;
: FCONSTANT F 2CONSTANT ;

: FLOAT DUP 0< DFLOAT ;
: -+    DROP SWAP 0< IF NEGATE THEN ;
: FIX   TUCK 0 SWAP SHIFTS RALIGN -+ ;
: INT   TUCK 0 SWAP SHIFTS  ALIGN -+ ;

1.      FCONSTANT ONE DECIMAL
34.6680 FCONSTANT X1
-57828. FCONSTANT X2
2001.18 FCONSTANT X3
1.4427  FCONSTANT X4

: EXP   2DUP INT DUP >R FLOAT F-
        F2* X2 2OVER FSQ X3 F+ F/
        2OVER F2/ F-     X1 F+ F/
        ONE F+ FSQ R> + ;
: FEXP  X4 F* EXP ;
: GET   BL WORD DUP 1+ C@ "- = TUCK -
        0 0 ROT CONVERT DROP -+ ;
: E     F GET >R R@ ABS 13301 4004 */MOD
        >R FLOAT 4004 FLOAT F/ EXP R> +
        R> 0< IF F/ ELSE F* THEN ;

: E.    TUCK FABS 16384 TUCK -
        4004 13301 */MOD >R
        FLOAT 4004 FLOAT F/ EXP F*
        2DUP ONE F<
        IF 10 FLOAT F* R> 1- >R THEN
        <# R@ ABS 0 #S R> SIGN 2DROP
        "E HOLD F# #>     TYPE SPACE ;


