\ From ftp://ftp.taygeta.com/pub/Forth/Applications/ANS (called lzss.fo)
\ Retrieved: 30th/11/2017
( LZSS Data Compression -- Standard Forth -- HO & WB -- 94-12-09 )

\ MARKER      LZSS-Data-Compression

\ : reload    LZSS-Data-Compression    S" lzss.fo" INCLUDED ;

( Common Implementation Factors -- You may already have some of these. )

( "\ " out the lines you don't need. )

: array         CREATE  CELLS ALLOT     DOES>   SWAP CELLS + ;

: carray        CREATE  CHARS ALLOT     DOES>   SWAP CHARS + ;

: checked	ABORT" File Access Error. " ;

CREATE single-char-i/o-buffer    0 C,    ALIGN
: read-char				( file -- char ) 
	single-char-i/o-buffer 1 ROT READ-FILE checked IF
		single-char-i/o-buffer C@
	ELSE
		-1
	THEN
;

(     LZSS -- A Data Compression Program )
(     89-04-06 Standard C by Haruhiko Okumura )
(     94-12-09 Standard Forth by Wil Baden )

(     Use, distribute, and modify this program freely. )

4096  CONSTANT    N     ( Size of Ring Buffer )
18    CONSTANT    F     ( Upper Limit for match-length )
2     CONSTANT    Threshold ( Encode string into position & length
                        ( if match-length is greater. )
N     CONSTANT    Nil   ( Index for Binary Search Tree Root )

VARIABLE    textsize    ( Text Size Counter )
VARIABLE    codesize    ( Code Size Counter )
\ VARIABLE  printcount  ( Counter for Reporting Progress )

( These are set by InsertNode procedure. )

VARIABLE    match-position
VARIABLE    match-length

\ : array         CREATE  CELLS ALLOT     DOES>   SWAP CELLS + ;

\ : carray        CREATE  CHARS ALLOT     DOES>   SWAP CHARS + ;

N F + 1 -   carray text-buf   ( Ring buffer of size N, with extra
                  ( F-1 bytes to facilitate string comparison. )

( Left & Right Children and Parents -- Binary Search Trees )

N 1 +       array lson
N 257 +           array rson
N 1 +             array dad

( Input & Output Files )

0 VALUE     infile      0 VALUE     outfile

( For i = 0 to N - 1, rson[i] and lson[i] will be the right and
( left children of node i.  These nodes need not be initialized.
( Also, dad[i] is the parent of node i.  These are initialized to
( Nil = N, which stands for `not used.'
( For i = 0 to 255, rson[N + i + 1] is the root of the tree
( for strings that begin with character i.  These are initialized
( to Nil.  Note there are 256 trees. )

( Initialize trees. )

: InitTree                                ( -- )
      N 257 +  N 1 +  DO    Nil  I rson !    LOOP
      N  0  DO    Nil  I dad !    LOOP
;

( Insert string of length F, text_buf[r..r+F-1], into one of the
( trees of text_buf[r]'th tree and return the longest-match position
( and length via the global variables match-position and match-length.
( If match-length = F, then remove the old node in favor of the new
( one, because the old one will be deleted sooner.
( Note r plays double role, as tree node and position in buffer. )

: InsertNode                              ( r -- )

      Nil OVER lson !    Nil OVER rson !    0 match-length !
      DUP text-buf C@  N +  1 +                 ( r p)

      1                                         ( r p cmp)
      BEGIN                                     ( r p cmp)
            0< not IF                           ( r p)

                  DUP rson @ Nil = not IF
                        rson @
                  ELSE

                        2DUP rson !
                        SWAP dad !              ( )
                        EXIT

                  THEN
            ELSE                                ( r p)

                  DUP lson @ Nil = not IF
                        lson @
                  ELSE

                        2DUP lson !
                        SWAP dad !              ( )
                        EXIT

                  THEN
            THEN                                ( r p)

            0 F DUP 1 DO                        ( r p 0 F)

                  3 PICK I + text-buf C@        ( r p 0 F c)
                  3 PICK I + text-buf C@ -      ( r p 0 F diff)
                  ?DUP IF
                        NIP NIP I
                        LEAVE
                  THEN                          ( r p 0 F)

            LOOP                                ( r p cmp i)

            DUP match-length @ > IF

                  2 PICK match-position !
                  DUP match-length !
                  F < not

            ELSE
                  DROP FALSE
            THEN                                ( r p cmp flag)
      UNTIL                                     ( r p cmp)
      DROP                                      ( r p)

      2DUP dad @ SWAP dad !
      2DUP lson @ SWAP lson !
      2DUP rson @ SWAP rson !

      2DUP lson @ dad !
      2DUP rson @ dad !

      DUP dad @ rson @ OVER = IF
            TUCK dad @ rson !
      ELSE
            TUCK dad @ lson !
      THEN                                      ( p)

      dad Nil SWAP !    ( Remove p )            ( )
;

( Deletes node p from tree. )

: DeleteNode                              ( p -- )

      DUP dad @ Nil = IF    DROP EXIT    THEN   ( Not in tree. )

      ( CASE )                                  ( p)
            DUP rson @ Nil =
      IF
            DUP lson @
      ELSE
            DUP lson @ Nil =
      IF
            DUP rson @
      ELSE

            DUP lson @                          ( p q)

            DUP rson @ Nil = not IF

                  BEGIN
                        rson @
                        DUP rson @ Nil =
                  UNTIL

                  DUP lson @ OVER dad @ rson !
                  DUP dad @ OVER lson @ dad !

                  OVER lson @ OVER lson !
                  OVER lson @ dad OVER SWAP !
            THEN

            OVER rson @ OVER rson !
            OVER rson @ dad OVER SWAP !

      ( ESAC ) THEN THEN                        ( p q)

      OVER dad @ OVER dad !

      OVER DUP dad @ rson @ = IF
            OVER dad @ rson !
      ELSE
            OVER dad @ lson !
      THEN                                      ( p)

      dad Nil SWAP !                            ( )
;

      17 carray   code-buf

      VARIABLE    len
      VARIABLE    last-match-length
      VARIABLE    code-buf-ptr

      VARIABLE    mask

: Encode                                  ( -- )

      0 textsize !    0 codesize !

      InitTree    ( Initialize trees. )

      ( code_buf[1..16] saves eight units of code, and code_buf[0]
      ( works as eight flags, "1" representing that the unit is an
      ( unencoded letter in 1 byte, "0" a position-and-length pair
      ( in 2 bytes.  Thus, eight units require at most 16 bytes
      ( of code. )

      0 0 code-buf C!
      1 mask C!   1 code-buf-ptr !
      0    N F -                                ( s r)

      ( Clear the buffer with any character that will appear often. )

      0 text-buf  N F -  BL  FILL

      ( Read F bytes into the last F bytes of the buffer. )

      DUP text-buf F infile READ-FILE checked   ( s r count)
      DUP len !    DUP textsize !
      0= IF    EXIT    THEN                     ( s r)

      ( Insert the F strings, each of which begins with one or more
      ( `space' characters.  Note the order in which these strings
      ( are inserted.  This way, degenerate trees will be less
      ( likely to occur. )

      F 1 + 1 DO                                ( s r)
            DUP I - InsertNode
      LOOP

      ( Finally, insert the whole string just read.  The
      ( global variables match-length and match-position are set. )

      DUP InsertNode

      BEGIN                                     ( s r)

            ( match_length may be spuriously long at end of text. )
            match-length @ len @ > IF    len @ match-length !   THEN

            match-length @ Threshold > not IF

                  ( Not long enough match.  Send one byte. )
                  1 match-length !
                  ( `send one byte' flag )
                  mask C@ 0 code-buf C@ OR 0 code-buf C!
                  ( Send uncoded. )
                  DUP text-buf C@ code-buf-ptr @ code-buf C!
                  1 code-buf-ptr +!

            ELSE
                  ( Send position and length pair.
                  ( Note match-length > Threshold. )

                  match-position @  code-buf-ptr @ code-buf C!
                  1 code-buf-ptr +!

                  match-position @  8 RSHIFT  4 LSHIFT ( . . j)
                        match-length @  Threshold -  1 -  OR
                        code-buf-ptr @  code-buf C!  ( . .)
                  1 code-buf-ptr +!

            THEN

            ( Shift mask left one bit. )        ( . .)

            mask C@  2*  mask C!    mask C@ 0= IF

                  ( Send at most 8 units of code together. )

                  0 code-buf  code-buf-ptr @    ( . . a k)
                        outfile WRITE-FILE checked ( . .)
                  code-buf-ptr @  codesize  +!
                  0 0 code-buf C!    1 code-buf-ptr !    1 mask C!

            THEN                                ( s r)

            match-length @ last-match-length !

            last-match-length @ DUP 0 DO        ( s r n)

                  infile read-char              ( s r n c)
                  DUP 0< IF   2DROP I LEAVE   THEN

                  ( Delete old strings and read new bytes. )

                  3 PICK DeleteNode
                  DUP 3 1 + PICK text-buf C!

                  ( If the position is near end of buffer, extend
                  ( the buffer to make string comparison easier. )

                  3 PICK F 1 - < IF             ( s r n c)
                        DUP 3 1 + PICK N + text-buf C!
                  THEN
                  DROP                          ( s r n)

                  ( Since this is a ring buffer, increment the
                  ( position modulo N. )

                  >R >R                         ( s)
                        1 +    N 1 - AND
                  R>                            ( s r)
                        1 +    N 1 - AND
                  R>                            ( s r n)

                  ( Register the string in text_buf[r..r+F-1]. )

                  OVER InsertNode

            LOOP                                ( s r i)
            DUP textsize +!

            \ textsize @  printcount @ > IF

            \     ( Report progress each time the textsize exceeds
            \     ( multiples of 1024. )
            \     textsize @ 12 .R
            \     1024 printcount +!

            \ THEN

            ( After the end of text, no need to read, but
            ( buffer may not be empty. )

            last-match-length @ SWAP ?DO        ( s r)

                  OVER DeleteNode

                  >R  1 +  N 1 - AND  R>
                  1 +  N 1 - AND

                  -1 len +!    len @ IF
                        DUP InsertNode
                  THEN
            LOOP

            len @ 0> not
      UNTIL                                     2DROP

      ( Send remaining code. )

      code-buf-ptr @ 1 > IF
            0 code-buf  code-buf-ptr @  outfile  WRITE-FILE checked
            code-buf-ptr @ codesize +!
      THEN
;

: Statistics                              ( -- )
      ." In : " textsize ? CR
      ." Out: " codesize ? CR
      textsize @ IF
            ." Saved: " textsize @ codesize @ - 100 textsize @ */
                  2 .R ." %" CR
      THEN
      infile closed    outfile closed
;

( Just the reverse of Encode. )

: Decode                                  ( -- )

      0 text-buf  N F -  BL FILL

      0  N F -                                  ( flags r)
      BEGIN
            >R                                  ( flags)
                  1 RSHIFT DUP 256 AND 0= IF DROP     ( )
                        infile read-char        ( c)
                        DUP 0< IF               R> 2DROP
                              EXIT              ( c)
                        THEN
                        [ HEX ] 0FF00 [ DECIMAL ] OR ( flags)
                        ( Uses higher byte to count eight. )
                  THEN
            R>                                  ( flags r)

            OVER 1 AND IF

                  infile read-char              ( . . c)
                  DUP 0< IF                     DROP 2DROP
                        EXIT                    ( . r c)
                  THEN

                  OVER text-buf C!              ( . r)
                  DUP text-buf 1 outfile WRITE-FILE checked

                  1 +    N 1 - AND

            ELSE

                  infile read-char              ( . . i)
                  DUP 0< IF                     DROP 2DROP
                        EXIT                    ( . r c)
                  THEN

                  infile read-char              ( . . i j)
                  DUP 0< IF                     2DROP 2DROP
                        EXIT                    ( . . i j)
                  THEN

                  DUP >R    4 RSHIFT    8 LSHIFT OR   R>
                  15 AND    Threshold +    1 +

                  0 ?DO                         ( . r i)

                        DUP I +  N 1 - AND  text-buf ( . r i a)
                        DUP 1 outfile WRITE-FILE checked
                        C@  2 PICK text-buf C!  ( . r i)
                        >R  1 +  N 1 - AND  R>

                  LOOP                          ( . r i)
                  DROP                          ( flags r)

            THEN
      AGAIN
;

                          
