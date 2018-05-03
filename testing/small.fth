0 <ok> ! ( Turn off 'ok' prompt )

only forth definitions hex
variable meta       ( Metacompilation vocabulary )
meta +order definitions

variable assembler.1   ( Target assembler vocabulary )
variable target.1      ( Target dictionary )
variable tcp           ( Target dictionary pointer )
variable tlast         ( Last defined word in target )
variable tdoVar        ( Location of doVar in target )
variable tdoConst      ( Location of doConst in target )
variable tdoNext       ( Location of doNext in target )
variable tdoPrintString ( Location of .string in target )
variable tdoStringLit  ( Location of string-literal in target )
variable fence         ( Do not peephole optimize before this point )
1984 constant #version ( Version number )
5000 constant #target  ( Memory location where the target image will be built )
2000 constant #max     ( Max number of cells in generated image )
2    constant =cell    ( Target cell size )
-1   constant optimize ( Turn optimizations on [-1] or off [0] )
0    constant swap-endianess ( if true, swap the endianess )
$4280 constant pad-area    ( area for pad storage )
variable header -1 header ! ( If true Headers in the target will be generated )
$7FFF constant (rp0)   ( start of return stack )
$4400 constant (sp0)   ( start of variable stack )

1   constant verbose   ( verbosity level, higher is more verbose )
#target #max 0 fill    ( Erase the target memory location )

: ]asm assembler.1 +order ; immediate ( -- )
: a: get-current assembler.1 set-current : ; ( "name" -- wid link )
: a; [compile] ; set-current ; immediate ( wid link -- )

: ( [char] ) parse 2drop ; immediate
: \ source drop @ >in ! ; immediate
: there tcp @ ;         ( -- a : target dictionary pointer value )
: tc! #target + c! ;    ( u a -- )
: tc@ #target + c@ ;    ( a -- u )
: [last] tlast @ ;      ( -- a )
: low  swap-endianess 0= if 1+ then ; ( b -- b )
: high swap-endianess    if 1+ then ; ( b -- b )
: t! over $FF and over high tc! swap 8 rshift swap low tc! ; ( u a -- )
: t@ dup high tc@ swap low tc@ 8 lshift or ; ( a -- u )
: 2/ 1 rshift ;                ( u -- u )
: talign there 1 and tcp +! ;  ( -- )
: tc, there tc! 1 tcp +! ;     ( c -- )
: t,  there t!  =cell tcp +! ; ( u -- )
: tallot tcp +! ;              ( n -- )
: update-fence there fence ! ; ( -- )
: $literal                     ( <string>, -- )
  [char] " word count dup tc, 1- for count tc, next drop talign update-fence ;
: tcells =cell * ;             ( u -- a )
: tbody 1 tcells + ;           ( a -- a )
: meta! ! ;                    ( u a -- )
: dump-hex #target there 16 + dump ; ( -- )
: locations ( -- : list all words and locations in target dictionary )
  target.1 @
  begin
    dup
  while
    dup
    nfa count type space dup
    cfa >body @ u. cr
    $3FFF and @
  repeat drop ;
: display ( -- : display metacompilation and target information )
  verbose 0= if exit then
  hex
  ." COMPILATION COMPLETE" cr
  verbose 1 u> if
    dump-hex cr
    ." TARGET DICTIONARY: " cr
    locations
  then
  ." HOST: "       here        . cr
  ." TARGET: "     there       . cr
  ." HEADER: "     #target 20 dump cr ;

: checksum #target there crc ; ( -- u : calculate CRC of target image )

: save-hex ( -- : save target binary to file )
   #target #target there + (save) throw ;

: finished ( -- : save target image and display statistics )
   display
   only forth definitions hex
   ." SAVING... " save-hex ." DONE! " cr
   ." STACK> " .s cr ;

: [a] ( "name" -- : find word and compile an assembler word )
  token assembler.1 search-wordlist 0= abort" [a]? "
  cfa compile, ; immediate

: asm[ assembler.1 -order ; immediate ( -- )

a: #literal $8000 a; ( literal instruction - top bit set )
a: #alu     $6000 a; ( ALU instruction, further encoding below... )
a: #call    $4000 a; ( function call instruction )
a: #?branch $2000 a; ( branch if zero instruction )
a: #branch  $0000 a; ( unconditional branch )

a: #t      $0000 a; ( T = t )
a: #n      $0100 a; ( T = n )
a: #r      $0200 a; ( T = Top of Return Stack )
a: #[t]    $0300 a; ( T = memory[t] )
a: #n->[t] $0400 a; ( memory[t] = n )
a: #t+n    $0500 a; ( n = n+t, T = carry )
a: #t*n    $0600 a; ( n = n*t, T = upper bits of multiplication )
a: #t&n    $0700 a; ( T = T and N )
a: #t|n    $0800 a; ( T = T  or N )
a: #t^n    $0900 a; ( T = T xor N )
a: #~t     $0A00 a; ( Invert T )
a: #t-1    $0B00 a; ( T == t - 1 )
a: #t==0   $0C00 a; ( T == 0? )
a: #t==n   $0D00 a; ( T = n == t? )
a: #nu<t   $0E00 a; ( T = n < t )
a: #n<t    $0F00 a; ( T = n < t, signed version )
a: #n>>t   $1000 a; ( T = n right shift by t places )
a: #n<<t   $1100 a; ( T = n left  shift by t places )
a: #sp@    $1200 a; ( T = variable stack depth )
a: #rp@    $1300 a; ( T = return stack depth )
a: #sp!    $1400 a; ( set variable stack depth )
a: #rp!    $1500 a; ( set return stack depth )
a: #save   $1600 a; ( Save memory disk: n = start, T = end, T' = error )
a: #tx     $1700 a; ( Transmit Byte: t = byte, T' = error )
a: #rx     $1800 a; ( Block until byte received, T = byte/error )
a: #u/mod  $1900 a; ( Remainder/Divide: )
a: #/mod   $1A00 a; ( Signed Remainder/Divide: )
a: #bye    $1B00 a; ( Exit Interpreter )

a: d+1     $0001 or a; ( increment variable stack by one )
a: d-1     $0003 or a; ( decrement variable stack by one )
a: d-2     $0002 or a; ( decrement variable stack by two )
a: r+1     $0004 or a; ( increment variable stack by one )
a: r-1     $000C or a; ( decrement variable stack by one )
a: r-2     $0008 or a; ( decrement variable stack by two )

a: r->pc   $0010 or a; ( Set Program Counter to Top of Return Stack )
a: n->t    $0020 or a; ( Set Top of Variable Stack to Next on Variable Stack )
a: t->r    $0040 or a; ( Set Top of Return Stack to Top on Variable Stack )
a: t->n    $0080 or a; ( Set Next on Variable Stack to Top on Variable Stack )

: ?set dup $E000 and abort" argument too large " ;
a: branch  2/ ?set [a] #branch  or t, a; ( a -- : an Unconditional branch )
a: ?branch 2/ ?set [a] #?branch or t, a; ( a -- : Conditional branch )
a: call    2/ ?set [a] #call    or t, a; ( a -- : Function call )
a: ALU        ?set [a] #alu     or    a; ( u -- : Make ALU instruction )
a: alu                    [a] ALU  t, a; ( u -- : ALU operation )
a: literal ( n -- : compile a number into target )
  dup [a] #literal and if   ( numbers above $7FFF take up two instructions )
    invert recurse  ( the number is inverted, an literal is called again )
    [a] #~t [a] alu ( then an invert instruction is compiled into the target )
  else
    [a] #literal or t, ( numbers below $8000 are single instructions )
  then a;
a: return ( -- : Compile a return into the target )
   [a] #t [a] r->pc [a] r-1 [a] alu a;

: previous there =cell - ;                      ( -- a )
: lookback previous t@ ;                        ( -- u )
: call? lookback $E000 and [a] #call = ;        ( -- t )
: call>goto previous dup t@ $1FFF and swap t! ; ( -- )
: fence? fence @  previous u> ;                 ( -- t )
: safe? lookback $E000 and [a] #alu = lookback $001C and 0= and ; ( -- t )
: alu>return previous dup t@ [a] r->pc [a] r-1 swap t! ; ( -- )
: exit-optimize                                 ( -- )
  fence? if [a] return exit then
  call?  if call>goto  exit then
  safe?  if alu>return exit then
  [a] return ;
: exit, exit-optimize update-fence ;            ( -- )

: compile-only tlast @ t@ $8000 or tlast @ t! ; ( -- )
: immediate tlast @ t@ $4000 or tlast @ t! ;    ( -- )

: tcreate get-current >r target.1 set-current create r> set-current ;

: thead ( b u -- : compile word header into target dictionary )
  header @ 0= if 2drop exit then
  talign
  there [last] t, tlast !
  there #target + pack$ c@ 1+ aligned tcp +! talign ;

: lookahead ( -- b u : parse a word, but leave it in the input stream )
  >in @ >r bl parse r> >in ! ;

: literal [a] literal ;                      ( u -- )
: h: ( -- : create a word with no name in the target dictionary )
 ' literal <literal> !
 $F00D tcreate there , update-fence does> @ [a] call ;

: t: ( "name", -- : creates a word in the target dictionary )
  lookahead thead h: ;

: fallthrough;
  ' (literal) <literal> !
  $F00D <> if source type cr 1 abort" unstructured! " then ;
: t;
  fallthrough; optimize if exit, else [a] return then ;

: fetch-xt @ dup 0= abort" (null) " ; ( a -- xt )

: tconstant ( "name", n -- , Run Time: -- n )
  >r
  lookahead
  thead
  there tdoConst fetch-xt [a] call r> t, >r
  tcreate r> ,
  does> @ tbody t@ [a] literal ;

: tvariable ( "name", n -- , Run Time: -- a )
  >r
  lookahead
  thead
  there tdoVar fetch-xt [a] call r> t, >r
  tcreate r> ,
  does> @ tbody [a] literal ;

: tlocation ( "name", n -- : Reserve space in target for a memory location )
  there swap t, tcreate , does> @ [a] literal ;

: [t] ( "name", -- a : get the address of a target word )
  token target.1 search-wordlist 0= abort" [t]? "
  cfa >body @ ;

: [v] [t] =cell + ; ( "name", -- a )

: xchange ( "name1", "name2", -- : exchange target vocabularies )
  [last] [t] t! [t] t@ tlast meta! ;

: begin  there update-fence ;                ( -- a )
: until  [a] ?branch ;                       ( a -- )
: if     there update-fence 0 [a] ?branch  ; ( -- a )
: skip   there update-fence 0 [a] branch ;   ( -- a )
: then   begin 2/ over t@ or swap t! ;       ( a -- )
: else   skip swap then ;                    ( a -- a )
: while  if swap ;                           ( a -- a a )
: repeat [a] branch then update-fence ;      ( a -- )
: again  [a] branch update-fence ;           ( a -- )
: aft    drop skip begin swap ;              ( a -- a )
: constant tcreate , does> @ literal ;       ( "name", a -- )
: [char] char literal ;                      ( "name" )
: postpone [t] [a] call ;                    ( "name", -- )
: next tdoNext fetch-xt [a] call t, update-fence ; ( a -- )
: exit exit, ;                               ( -- )
: ' [t] literal ;                            ( "name", -- )
: ." tdoPrintString fetch-xt [a] call $literal ; ( "string", -- )
: $" tdoStringLit   fetch-xt [a] call $literal ; ( "string", -- )

: nop     ]asm  #t       alu asm[ ;
: dup     ]asm  #t       t->n   d+1   alu asm[ ;
: over    ]asm  #n       t->n   d+1   alu asm[ ;
: invert  ]asm  #~t      alu asm[ ;
: um+     ]asm  #t+n     alu asm[ ;
: +       ]asm  #t+n     n->t   d-1   alu asm[ ;
: um*     ]asm  #t*n     alu asm[    ;
: *       ]asm  #t*n     n->t   d-1   alu asm[ ;
: swap    ]asm  #n       t->n   alu asm[ ;
: nip     ]asm  #t       d-1    alu asm[ ;
: drop    ]asm  #n       d-1    alu asm[ ;
: >r      ]asm  #n       t->r   d-1   r+1   alu asm[ ;
: r>      ]asm  #r       t->n   d+1   r-1   alu asm[ ;
: r@      ]asm  #r       t->n   d+1   alu asm[ ;
: @       ]asm  #[t]     alu asm[ ;
: !       ]asm  #n->[t]  d-1    alu asm[ ;
: rshift  ]asm  #n>>t    d-1    alu asm[ ;
: lshift  ]asm  #n<<t    d-1    alu asm[ ;
: =       ]asm  #t==n    d-1    alu asm[ ;
: u<      ]asm  #nu<t    d-1    alu asm[ ;
: <       ]asm  #n<t     d-1    alu asm[ ;
: and     ]asm  #t&n     d-1    alu asm[ ;
: xor     ]asm  #t^n     d-1    alu asm[ ;
: or      ]asm  #t|n     d-1    alu asm[ ;
: sp@     ]asm  #sp@     t->n   d+1   alu asm[ ;
: sp!     ]asm  #sp!     alu asm[ ;
: 1-      ]asm  #t-1     alu asm[ ;
: rp@     ]asm  #rp@     t->n   d+1   alu asm[ ;
: rp!     ]asm  #rp!     d-1    alu asm[ ;
: 0=      ]asm  #t==0    alu asm[ ;
: yield?  ]asm  #bye     alu asm[ ;
: rx?     ]asm  #rx      t->n   d+1   alu asm[ ;
: tx!     ]asm  #tx      n->t   d-1   alu asm[ ;
: (save)  ]asm  #save    d-1    alu asm[ ;
: um/mod  ]asm  #u/mod   t->n   alu asm[ ;
: /mod    ]asm  #/mod    t->n   alu asm[ ;
: /       ]asm  #/mod    d-1    alu asm[ ;
: mod     ]asm  #/mod    n->t   d-1   alu asm[ ;
: rdrop   ]asm  #t       r-1    alu asm[ ;
: dup@   ]asm  #[t]     t->n   d+1 alu asm[ ;
: dup0=   ]asm  #t==0    t->n   d+1 alu asm[ ;
: dup>r   ]asm  #t       t->r   r+1 alu asm[ ;
: 2dup=   ]asm  #t==n    t->n   d+1 alu asm[ ;
: 2dupxor ]asm  #t^n     t->n   d+1 alu asm[ ;
: 2dup<   ]asm  #n<t     t->n   d+1 alu asm[ ;
: rxchg   ]asm  #r       t->r       alu asm[ ;

: for >r begin ;

: meta: : ;
: : t: ;
meta: ; t; ;
hide meta:
hide t:
hide t;

]asm #~t              ALU asm[ constant =invert ( invert instruction )
]asm #t  r->pc    r-1 ALU asm[ constant =exit   ( return/exit instruction )
]asm #n  t->r d-1 r+1 ALU asm[ constant =>r     ( to r. stk. instruction )
$20   constant =bl         ( blank, or space )
$FFDF constant =!bl        ( inverse of =bl )
$D    constant =cr         ( carriage return )
$A    constant =lf         ( line feed )
$8    constant =bs         ( back space )
$1B   constant =escape     ( escape character )

$10   constant dump-width  ( number of columns for 'dump' )
$50   constant tib-length  ( size of terminal input buffer )
$1F   constant word-length ( maximum length of a word )

$40   constant c/l         ( characters per line in a block )
$10   constant l/b         ( lines in a block )
(rp0) constant rp0         ( start of return stack )
(sp0) constant sp0         ( start of variable stack )
$2BAD constant magic       ( magic number for compiler security )
$F    constant #highest    ( highest bit in cell )

( Volatile variables )
$4002 constant last-def    ( last, possibly unlinked, word definition )
$4006 constant id          ( used for source id )
$4008 constant seed        ( seed used for the PRNG )
$400A constant handler     ( current handler for throw/catch )
$400C constant block-dirty ( -1 if loaded block buffer is modified )
$4010 constant <key>       ( -- c : new character, blocking input )
$4012 constant <emit>      ( c -- : emit character )
$4014 constant <expect>    ( "accept" vector )
$4110 constant context     ( holds current context for search order )
$4122 constant #tib        ( Current count of terminal input buffer )
$4124 constant tib-buf     ( ... and address )
$4126 constant tib-start   ( backup tib-buf value )

$C    constant vm-options     ( Virtual machine options register )
$16   constant header-length  ( location of length in header )
$18   constant header-crc     ( location of CRC in header )
$1E   constant header-options ( location of options bits in header )

target.1 +order         ( Add target word dictionary to search order )
meta -order meta +order ( Reorder so 'meta' has a higher priority )
forth-wordlist   -order ( Remove normal Forth words to prevent accidents )

0        t, \  $0: PC: program counter, jump to start / reset vector
0        t, \  $2: T, top of stack
(rp0)    t, \  $4: RP0, return stack pointer 
(sp0)    t, \  $6: SP0, variable stack pointer
0        t, \  $8: Instruction exception vector
$8000    t, \  $A: VM Memory Size in cells
$0000    t, \  $C: VM Options
$4689    t, \  $E: 0x89 'F'
$4854    t, \ $10: 'T'  'H'
$0A0D    t, \ $12: '\r' '\n'
$0A1A    t, \ $14: ^Z   '\n'
0        t, \ $16: For Length of Forth image, different from VM size
0        t, \ $18: For CRC of Forth image, not entire VM memory
$0001    t, \ $1A: Endianess check
#version t, \ $1C: Version information
$0001    t, \ $1E: Header options

h: doVar   r> ;    ( -- a : push return address and exit to caller )
h: doConst r> @ ;  ( -- u : push value at return address and exit to caller )

[t] doVar   tdoVar   meta!
[t] doConst tdoConst meta!

0 tlocation cp                ( Dictionary Pointer: Set at end of file )
0 tlocation root-voc          ( root vocabulary )
0 tlocation editor-voc        ( editor vocabulary )
0 tlocation _forth-wordlist   ( set at the end near the end of the file )
0 tlocation current           ( WID to add definitions to )

: dup      dup      ; ( n -- n n : duplicate value on top of stack )
: over     over     ; ( n1 n2 -- n1 n2 n1 : duplicate second value on stack )
: invert   invert   ; ( u -- u : bitwise invert of value on top of stack )
: um+      um+      ; ( u u -- u carry : addition with carry )
: +        +        ; ( u u -- u : addition without carry )
: um*      um*      ; ( u u -- ud : multiplication  )
: *        *        ; ( u u -- u : multiplication )
: swap     swap     ; ( n1 n2 -- n2 n1 : swap two values on stack )
: nip      nip      ; ( n1 n2 -- n2 : remove second item on stack )
: drop     drop     ; ( n -- : remove item on stack )
: @        @        ; ( a -- u : load value at address )
: !        !        ; ( u a -- : store 'u' at address 'a' )
: rshift   rshift   ; ( u1 u2 -- u : shift u2 by u1 places to the right )
: lshift   lshift   ; ( u1 u2 -- u : shift u2 by u1 places to the left )
: =        =        ; ( u1 u2 -- t : does u2 equal u1? )
: u<       u<       ; ( u1 u2 -- t : is u2 less than u1 )
: <        <        ; ( u1 u2 -- t : is u2 less than u1, signed version )
: and      and      ; ( u u -- u : bitwise and )
: xor      xor      ; ( u u -- u : bitwise exclusive or )
: or       or       ; ( u u -- u : bitwise or )
: 1-       1-       ; ( u -- u : decrement top of stack )
: 0=       0=       ; ( u -- t : if top of stack equal to zero )
h: yield?  yield?   ; ( u -- !!! : exit VM with 'u' as return value )
h: rx?     rx?      ; ( -- c | -1 : fetch a single character, or EOF )
h: tx!     tx!      ; ( c -- : transmit single character )
: (save)   (save)   ; ( u1 u2 -- u : save memory from u1 to u2 inclusive )
: um/mod   um/mod   ; ( d  u2 -- rem div : mixed unsigned divide/modulo )
: /mod     /mod     ; ( u1 u2 -- rem div : signed divide/modulo )
: /        /        ; ( u1 u2 -- u : u1 divided by u2 )
: mod      mod      ; ( u1 u2 -- u : remainder of u1 divided by u2 )

there constant inline-start
: exit  exit  fallthrough; compile-only ( -- )
: >r    >r    fallthrough; compile-only ( u --, R: -- u )
: r>    r>    fallthrough; compile-only ( -- u, R: u -- )
: r@    r@    fallthrough; compile-only ( -- u )
: rdrop rdrop fallthrough; compile-only ( --, R: u -- )
there constant inline-end

$2       tconstant cell  ( size of a cell in bytes )
$0       tvariable >in   ( Hold character pointer when parsing input )
$0       tvariable state ( compiler state variable )
$0       tvariable hld   ( Pointer into hold area for numeric output )
$10      tvariable base  ( Current output radix )
$0       tvariable span  ( Hold character count received by expect   )
$8       tconstant #vocs ( number of vocabularies in allowed )
$400     tconstant b/buf ( size of a block )
0        tvariable blk   ( current blk loaded, set in 'cold' )
#version constant  ver   ( eForth version )
pad-area tconstant pad   ( pad variable - offset into temporary storage )
0        tvariable dpl   ( number of places after fraction )
0        tvariable <literal> ( holds execution vector for literal )
0        tvariable <boot>  ( -- : execute program at startup )
0        tvariable <ok>

h: [-1] -1 ;                 ( -- -1 : space saving measure, push -1 )
h: 0x8000 $8000 ;            ( -- $8000 : space saving measure, push $8000 )
h: 2drop-0 drop fallthrough; ( n n -- 0 )
h: drop-0 drop fallthrough;  ( n -- 0 )
h: 0x0000 $0000 ;            ( -- $0000 : space/optimization, push $0000 )
h: state@ state @ ;          ( -- u )
h: first-bit 1 and ;         ( u -- u )
h: in! >in ! ;               ( u -- )
h: in@ >in @ ;               ( -- u )
h: base@ base @ ;            ( -- u )
h: base! base ! ;            ( u -- )

: 2drop drop drop ;         ( n n -- )
: 1+ 1 + ;                  ( n -- n : increment a value  )
: negate invert 1+ ;        ( n -- n : negate a number )
: - negate + ;              ( n1 n2 -- n : subtract n1 from n2 )
h: over- over - ;           ( u u -- u u )
h: over+ over + ;           ( u1 u2 -- u1 u1+2 )
: aligned dup first-bit + ; ( b -- a )
: bye -1 0 yield? nop ( $38 -throw ) ; ( -- : leave the interpreter )
h: cell- cell - ;           ( a -- a : adjust address to previous cell )
: cell+  cell + ;           ( a -- a : move address forward to next cell )
: cells 1 lshift ;          ( n -- n : convert cells count to address count )
: chars 1 rshift ;          ( n -- n : convert bytes to number of cells )
: ?dup dup if dup exit then ; ( n -- 0 | n n : duplicate non zero value )
: >  swap  < ;              ( n1 n2 -- t : signed greater than, n1 > n2 )
: u> swap u< ;              ( u1 u2 -- t : unsigned greater than, u1 > u2 )
h: u>= u< invert ;          ( u1 u2 -- t : unsigned greater/equal )
:  <>  = invert ;           ( n n -- t : not equal )
: 0<> 0= invert ;           ( n n -- t : not equal  to zero )
: 0> 0 > ;                  ( n -- t : greater than zero? )
: 0< 0 < ;                  ( n -- t : less than zero? )
: 2dup over over ;          ( n1 n2 -- n1 n2 n1 n2 )
: tuck swap over ;          ( n1 n2 -- n2 n1 n2 )
: +! tuck @ +  fallthrough; ( n a -- : increment value at 'a' by 'n' )
h: swap! swap ! ;           ( a u -- )
h: zero  0 swap! ;          ( a -- : zero value at address )
: 1+!   1  swap +! ;        ( a -- : increment value at address by 1 )
: 1-! [-1] swap +! ;        ( a -- : decrement value at address by 1 )
: 2! ( d a -- ) tuck ! cell+ ! ;      ( n n a -- )
: 2@ ( a -- d ) dup cell+ @ swap @ ;  ( a -- n n )
: get-current current @ ;             ( -- wid )
: set-current current ! ;             ( wid -- )
: bl =bl ;                            ( -- c )
: within over- >r - r> u< ;           ( u lo hi -- t )
h: s>d dup 0< ;                       ( n -- d )
: abs s>d if negate exit then ;       ( n -- u )
: source #tib 2@ ;                    ( -- a u )
h: tib source drop ;
: source-id id @ ;                    ( -- 0 | -1 )
: rot >r swap r> swap ;               ( n1 n2 n3 -- n2 n3 n1 )
: -rot rot rot ;                      ( n1 n2 n3 -- n3 n1 n2 )
h: rot-drop rot drop ;                ( n1 n2 n3 -- n2 n3 )
h: d0= or 0= ;                         ( d -- t )
h: dnegate invert >r invert 1 um+ r> + ; ( d -- d )
h: d+  >r swap >r um+ r> + r> + ;      ( d d -- d )

: execute >r ;                   ( cfa -- : execute a function )
h: @execute @ ?dup if >r then ;  ( cfa -- )

: c@ dup@ swap first-bit 3 lshift rshift $FF and ; ( b --c : char load )

: c! ( c b -- : store character at address )
  tuck first-bit 3 lshift dup>r
  lshift over @
  $FF r> 8 xor lshift and or swap! ;

h: command? state@ 0= ;               ( -- t )

: here cp @ ;                         ( -- a )
: align here fallthrough;             ( -- )
h: cp! aligned cp ! ;                 ( n -- )

: allot cp +! ;                        ( n -- )

h: 2>r rxchg swap >r >r ;              ( u1 u2 --, R: -- u1 u2 )
h: 2r> r> r> swap rxchg nop ;          ( -- u1 u2, R: u1 u2 -- )

h: doNext 2r> ?dup if 1- >r @ >r exit then cell+ >r ;
[t] doNext tdoNext meta!

: min 2dup< fallthrough;              ( n n -- n )
h: mux if drop exit then nip ;        ( n1 n2 b -- n : multiplex operation )
: max 2dup > mux ;                    ( n n -- n )

: key <key> @execute dup [-1] = if bye then ; ( -- c )

: /string over min rot over+ -rot - ;  ( b u1 u2 -- b u : advance string u2 )
h: +string 1 /string ;                 ( b u -- b u : )
: count dup 1+ swap c@ ;               ( b -- b u )
h: string@ over c@ ;                   ( b u -- b u c )

h: ccitt ( crc c -- crc : crc polynomial $1021 AKA "x16 + x12 + x5 + 1" )
  over $8 rshift xor   ( crc x )
  dup  $4 rshift xor   ( crc x )
  dup  $5 lshift xor   ( crc x )
  dup  $C lshift xor   ( crc x )
  swap $8 lshift xor ; ( crc )

: crc ( b u -- u : calculate ccitt-ffff CRC )
  [-1] ( -1 = 0xffff ) >r
  begin
    dup
  while
   string@ r> swap ccitt >r +string
  repeat 2drop r> ;

h: @address @ fallthrough;             ( a -- a )
h: address $3FFF and ;                 ( a -- a : mask off address bits )

h: last get-current @address ;         ( -- pwd )

: emit <emit> @execute ;               ( c -- : write out a char )
: cr =cr emit =lf emit ;               ( -- : emit a newline )
h: colon [char] : emit ;               ( -- )
: space =bl emit ;                     ( -- : emit a space )
h: spaces =bl fallthrough;             ( +n -- )
h: nchars                              ( +n c -- : emit c n times )
  swap 0 max for aft dup emit then next drop ;

: depth sp@ sp0 - chars ;             ( -- u : get current depth )
: pick cells sp@ swap - @ ;           ( vn...v0 u -- vn...v0 vu )

h: >char $7F and dup $7F =bl within if drop [char] _ then ; ( c -- c )
: type 0 fallthrough;                  ( b u -- )
h: typist                              ( b u f -- : print a string )
  >r begin dup while
    swap count r@
    if
      >char
    then
    emit
    swap 1-
  repeat
  rdrop 2drop ;
h: print count type ;                    ( b -- )
h: $type [-1] typist ;                   ( b u --  )

: cmove for aft >r dup c@ r@ c! 1+ r> 1+ then next 2drop ; ( b b u -- )
: fill swap for swap aft 2dup c! 1+ then next 2drop ; ( b u c -- )

h: ndrop for aft drop then next ; ( 0u....nu n -- : drop n cells )

: catch ( i*x xt -- j*x 0 | i*x n )
  sp@       >r
  handler @ >r
  rp@ handler !
  execute
  r> handler !
  r> drop-0 ;

: throw ( k*x n -- k*x | i*x n )
  ?dup if
    handler @ rp!
    r> handler !
    rxchg ( 'rxchg' is equivalent to 'r> swap >r' )
    sp! drop r>
  then ;

h: -throw negate throw ;  ( u -- : negate and throw )
[t] -throw 2/ 4 tcells t!

h: 1depth 1 fallthrough; ( ??? -- : check depth is at least one )
h: ?ndepth depth 1- u> if 4 -throw exit then ; ( ??? n -- check depth )
h: 2depth 2 ?ndepth ;    ( ??? -- :  check depth is at least two )

: decimal  $A base! ;                      ( -- )
: hex     $10 base! ;                      ( -- )
h: radix base@ dup 2 - $22 u> if hex $28 -throw exit then ; ( -- u )

: hold  hld @ 1- dup hld ! c! fallthrough;             ( c -- )
h: ?hold pad $100 - hld @ u> if $11 -throw exit then ; ( -- )
h: extract dup>r um/mod rxchg um/mod r> rot ;         ( ud ud -- ud u )
h: digit  9 over < 7 and + [char] 0 + ;                ( u -- c )

: #> 2drop hld @ pad over - ;             ( w -- b u )
: # 2depth 0 base@ extract digit hold ;   ( d -- d )
: #s begin # 2dup d0= until ;             ( d -- 0 )
: <# pad hld ! ;                          ( -- )

: sign  0< if [char] - hold exit then ;     ( n -- )
h: str ( n -- b u : convert a signed integer to a numeric string )
  dup>r abs 0 <# #s r> sign #> ;

h: (u.) 0 <# #s #> ;             ( u -- b u : turn 'u' into number string )
: u.r >r (u.) r> fallthrough;    ( u +n -- : print u right justified by +n)
h: adjust over- spaces type ;    ( b n n -- )
h: 5u.r 5 u.r ;                  ( u -- )
: u.  (u.) space type ;          ( u -- : print unsigned number )
:  .  radix $A xor if u. exit then str space type ; ( n -- print number )

h: unused $4000 here - ;         ( -- u : unused program space )
h: .free unused u. ;             ( -- : print unused program space )

: pack$ ( b u a -- a ) \ null fill
  aligned dup>r over
  dup cell negate and ( align down )
  - over+ zero 2dup c! 1+ swap cmove r> ;

: =string ( a1 u2 a1 u2 -- t : string equality )
  >r swap r> ( a1 a2 u1 u2 )
  over xor if drop 2drop-0 exit then
  for ( a1 a2 )
    aft
      count >r swap count r> xor
      if rdrop 2drop-0 exit then
    then
  next 2drop [-1] ;

h: tap ( dup echo ) over c! 1+ ; ( bot eot cur c -- bot eot cur )

: accept ( b u -- b u )
  over+ over
  begin
    2dupxor
  while
    key dup =lf xor if tap else drop nip dup then
    \ The alternative 'accept' code replaces the line above:
    \
    \   key  dup =bl - 95 u< if tap else <tap> @execute then
    \
  repeat drop over- ;

: expect <expect> @execute span ! drop ;                     ( b u -- )
: query tib tib-length <expect> @execute #tib ! drop-0 in! ; ( -- )

: nfa address cell+ ; ( pwd -- nfa : move to name field address)
: cfa nfa dup c@ + cell+ $FFFE ( <- cell -1 invert ) and ; ( pwd -- cfa )

h: .id nfa print ;                          ( pwd -- : print out a word )

h: immediate? @ $4000 and fallthrough;      ( pwd -- t : immediate word? )
h: logical 0= 0= ;                          ( n -- t )
h: compile-only? @ 0x8000 and logical ;     ( pwd -- t : is compile only? )
h: inline? inline-start inline-end within ; ( pwd -- t : is word inline? )

h: searcher ( a wid -- pwd pwd 1 | pwd pwd -1 | 0 a 0 : find a word in a WID )
  swap >r dup
  begin
    dup
  while
    dup nfa count r@ count =string
    if ( found! )
      rdrop
      dup immediate? 1 or negate exit
    then
    nip dup @address
  repeat
  rdrop 2drop-0 ;

h: finder ( a -- pwd pwd 1 | pwd pwd -1 | 0 a 0 : find a word dictionary )
  >r
  context
  begin
    dup@
  while
    dup@ @ r@ swap searcher ?dup
    if
      >r rot-drop r> rdrop exit
    then
    cell+
  repeat drop-0 r> 0x0000 ;

: search-wordlist searcher rot-drop ; ( a wid -- pwd 1 | pwd -1 | a 0 )
: find ( a -- pwd 1 | pwd -1 | a 0 : find a word in the dictionary )
  finder rot-drop ;

: digit? ( c base -- u f )
  >r [char] 0 - 9 over <
  if 
    7 - 
    =!bl and ( handle lower case, as well as upper case )
    dup $A < or 
  then dup r> u< ;

: >number ( ud b u -- ud b u : convert string to number )
  begin
    ( get next character )
    2dup 2>r drop c@ base@ digit? 
    if   ( d char )
       swap base@ um* drop rot base@ um* d+
    else ( d char )
      drop
      2r> ( restore string )
      nop exit
    then
    2r> ( restore string )
    +string dup0= ( advance string and test for end )
  until ;

h: negative? ( b u -- t : is >number negative? )
  string@ [char] - = if +string [-1] exit then 0x0000 ;

h: base? ( b u -- )
  string@ [char] $ = ( $hex )
  if
    +string hex exit
  then ( #decimal )
  string@ [char] # = if +string decimal exit then ;

h: number? ( b u -- d f : is number? )
  [-1] dpl !
  radix     >r
  negative? >r
  base?
  0 -rot 0 -rot 
  >number
  string@ [char] . = if +string
    dup>r >number nip if 0 rdrop else r> dpl ! [-1] then 
  else 
    nip 0= 
  then
  r> if >r dnegate r> then
  r> base! ; 

h: -trailing ( b u -- b u : remove trailing spaces )
  for
    aft =bl over r@ + c@ <
      if r> 1+ exit then
    then
  next 0x0000 ;

h: lookfor ( b u c xt -- b u : skip until 'xt' test succeeds )
  swap >r -rot
  begin
    dup
  while
    string@ r@ - r@ =bl = 4 pick execute 
    if rdrop rot-drop exit then
    +string
  repeat rdrop rot-drop ;

h: skipTest if 0> exit then 0<> ; ( n f -- t )
h: scanTest skipTest invert ;     ( n f -- t )
h: skipper ' skipTest lookfor ;   ( b u c -- u c )
h: scanner ' scanTest lookfor ;   ( b u c -- u c )

h: parser ( b u c -- b u delta )
  >r over r> swap 2>r
  r@ skipper 2dup
  r> scanner swap r> - >r - r> 1+ ;

: parse ( c -- b u ; <string> )
   >r tib in@ + #tib @ in@ - r@ parser >in +!
   r> =bl = if -trailing then 0 max ;
: ) ; immediate ( -- : do nothing )
:  ( [char] ) parse 2drop ; immediate \ ) ( parse until matching paren )
: .( [char] ) parse type ; ( print out text until matching parenthesis )
: \ #tib @ in! ; immediate ( comment until new line )
h: ?length dup word-length u> if $13 -throw exit then ;
: word 1depth parse ?length here pack$ ; ( c -- a ; <string> )
: token =bl word ;                       ( -- a )
: char token count drop c@ ;             ( -- c; <string> )

h: ?dictionary dup $3F00 u> if 8 -throw exit then ;
: , here dup cell+ ?dictionary cp! ! ; ( u -- : store 'u' in dictionary )
: c, here ?dictionary c! cp 1+! ;      ( c -- : store 'c' in the dictionary )
h: doLit 0x8000 or , ;                 ( n+ -- : compile literal )
: literal ( n -- : write a literal into the dictionary )
  dup 0x8000 and ( n > $7FFF ? )
  if
    invert doLit =invert , exit ( store inversion of n the invert it )
  then
  doLit ; compile-only immediate ( turn into literal, write into dictionary )

h: make-callable chars $4000 or ; ( cfa -- instruction )
: compile, make-callable , ; ( cfa -- : compile a code field address )
h: $compile dup inline? if cfa @ , exit then cfa compile, ; ( pwd -- )
h: not-found source type $D -throw ; ( -- : throw 'word not found' )

h: ?compile dup compile-only? if source type $E -throw exit then ;
: (literal) state@ if postpone literal exit then ; ( u -- u | )
: interpret ( ??? a -- ??? : The command/compiler loop )
  find ?dup if
    state@
    if
      0> if cfa execute exit then \ <- immediate word are executed
      $compile exit               \ <- compiling word are...compiled.
    then
    drop ?compile     \ <- check it's not a compile only word word
    cfa execute exit  \ <- if its not, execute it, then exit 'interpreter'
  then
  \ not a word
  dup>r count number? if rdrop \ it's a number!
    dpl @ 0< if \ <- dpl will -1 if its a single cell number
       drop     \ drop high cell from 'number?' for single cell output
    else        \ <- dpl is not -1, it's a double cell number
       command? if swap then 
       <literal> @execute \ <literal> is executed twice if it's a double
    then
    <literal> @execute exit
  then
  r> not-found ; \ not a word or number, it's an error!

: compile  r> dup@ , cell+ >r ; compile-only ( --:Compile next compiled word )
: immediate $4000 last fallthrough; ( -- : previous word immediate )
h: toggle tuck @ xor swap! ;        ( u a -- : xor value at addr with u )

: smudge last fallthrough;
h: (smudge) nfa $80 swap toggle ; ( pwd -- )

h: do$ r> r@ r> count + aligned >r swap >r ; ( -- a )
h: string-literal do$ nop ; ( -- a : do string NB. nop to fool optimizer )
h: .string do$ print ; ( -- : print string  )

[t] .string        tdoPrintString meta!
[t] string-literal tdoStringLit   meta!

h: parse-string [char] " word count + cp! ; ( -- )
( <string>, --, Run: -- b )
: $"  compile string-literal parse-string ; immediate compile-only
: ."  compile .string parse-string ; immediate compile-only ( <string>, -- )
: abort [-1] [-1] yield? ;                                     ( -- )
h: ?abort swap if print cr abort else drop then ;              ( u a -- )
h: (abort) do$ ?abort ;                                        ( -- )
: abort" compile (abort) parse-string ; immediate compile-only ( u -- )

h: preset tib-start #tib cell+ ! 0 in! id zero ;
: ] [-1] state ! ;
: [   state zero ; immediate

h: ?error ( n -- : perform actions on error )
  ?dup if
    .             ( print error number )
    [char] ? emit ( print '?' )
    cr
    sp0 sp!       ( empty stack )
    preset        ( reset I/O streams )
    postpone [    ( back into interpret mode )
    exit
  then ;

h: (ok) command? if ."  ok  " cr exit then ;  ( -- )
h: ?depth sp@ sp0 u< if 4 -throw exit then ;  ( u -- : depth check )
h: eval ( -- )
  begin
    token dup c@
  while
    interpret ?depth
  repeat drop <ok> @execute ;

: quit preset [ begin query ' eval catch ?error again ; ( -- )

h: get-input source in@ source-id <ok> @ ;    ( -- n1...n5 )
h: set-input <ok> ! id ! in! #tib 2! ;   ( n1...n5 -- )
: evaluate ( a u -- )
  get-input 2>r 2>r >r
  0 [-1] 0 set-input
  ' eval catch
  r> 2r> 2r> set-input
  throw ;

h: io! preset fallthrough;  ( -- : initialize I/O )
h: console ' rx? <key> ! ' tx! <emit> ! fallthrough;
h: hand ' (ok)  ( ' drop <-- was emit )  ( ' ktap ) fallthrough;
h: xio  ' accept <expect> ! ( <tap> ! ) ( <echo> ! ) <ok> ! ;

h: ?check ( magic-number -- : check for magic number on the stack )
   magic <> if $16 -throw exit then ;
h: ?unique ( a -- a : print a message if a word definition is not unique )
  dup last @ searcher
  if
    ( source type )
    space
    2drop last-def @ nfa print  ."  redefined " cr exit
  then ;
h: ?nul ( b -- : check for zero length strings )
   count 0= if $A -throw exit then 1- ;

h: find-token token find 0= if not-found exit then ; ( -- pwd,  <string> )
h: find-cfa find-token cfa ;                         ( -- xt, <string> )
: ' find-cfa state@ if postpone literal exit then ; immediate
: [compile] find-cfa compile, ; immediate compile-only  ( --, <string> )
: [char] char postpone literal ; immediate compile-only ( --, <string> )
: ; ( ?quit ) ?check =exit , postpone [ fallthrough; immediate compile-only
h: get-current! ?dup if get-current ! exit then ; ( -- wid )
: : align here dup last-def ! ( "name", -- colon-sys )
    last , token ?nul ?unique count + cp! magic ] ;
: begin here  ; immediate compile-only      ( -- a )
: until chars $2000 or , ; immediate compile-only  ( a -- )
: again chars , ; immediate compile-only ( a -- )
h: here-0 here 0x0000 ;
h: >mark here-0 postpone again ;
: if here-0 postpone until ; immediate compile-only
: then fallthrough; immediate compile-only
h: >resolve here chars over @ or swap! ;
: else >mark swap >resolve ; immediate compile-only
: while postpone if ; immediate compile-only
: repeat swap postpone again postpone then ; immediate compile-only
h: last-cfa last-def @ cfa ;  ( -- u )
: recurse last-cfa compile, ; immediate compile-only
: tail last-cfa postpone again ; immediate compile-only
: create postpone : drop compile doVar get-current ! postpone [ ;
: >body cell+ ; ( a -- a )
h: doDoes r> chars here chars last-cfa dup cell+ doLit ! , ;
: does> compile doDoes nop ; immediate compile-only
: variable create 0 , ;
: constant create ' doConst make-callable here cell- ! , ;
: :noname here-0 magic ]  ;
: for =>r , here ; immediate compile-only
: next compile doNext , ; immediate compile-only
: aft drop >mark postpone begin swap ; immediate compile-only
: hide find-token (smudge) ; ( --, <string> : hide word by name )

h: trace-execute vm-options ! >r ; ( u xt -- )
: trace ( "name" -- : trace a word )
  find-cfa vm-options @ dup>r 3 or trace-execute r> vm-options ! ;

h: find-empty-cell 0 fallthrough; ( a -- )
h: find-cell >r begin dup@ r@ <> while cell+ repeat rdrop ; ( u a -- a )

: get-order ( -- widn ... wid1 n : get the current search order )
  context
  find-empty-cell
  dup cell- swap
  context - chars dup>r 1- s>d if $32 -throw exit then
  for aft dup@ swap cell- then next @ r> ;

xchange _forth-wordlist root-voc
: forth-wordlist _forth-wordlist ;

: set-order ( widn ... wid1 n -- : set the current search order )
  dup [-1] = if drop root-voc 1 set-order exit then
  dup #vocs > if $31 -throw exit then
  context swap for aft tuck ! cell+ then next zero ;

: forth root-voc forth-wordlist 2 set-order ; ( -- )

h: not-hidden? nfa c@ $80 and 0= ; ( pwd -- )
h: .words space
    begin
      dup
    while dup not-hidden? if dup .id space then @address repeat drop cr ;
: words
  get-order begin ?dup while swap dup cr u. colon @ .words 1- repeat ;

xchange root-voc _forth-wordlist

: only [-1] set-order ;                         ( -- )
: definitions context @ set-current ;           ( -- )
h: (order)                                      ( w wid*n n -- wid*n w n )
  dup if
    1- swap >r (order) over r@ xor
    if
      1+ r> -rot exit
    then rdrop
  then ;
: -order get-order (order) nip set-order ;             ( wid -- )
: +order dup>r -order get-order r> swap 1+ set-order ; ( wid -- )

: editor decimal editor-voc +order ;                   ( -- )

: update [-1] block-dirty ! ; ( -- )
h: blk-@ blk @ ;              ( -- k : retrieve current loaded block )
h: +block blk-@ + ;           ( -- )
: save 0 here (save) throw ;  ( -- : save blocks )
: flush block-dirty @ if 0 [-1] (save) throw exit then ; ( -- )

: block ( k -- a )
  1depth
  dup $3F u> if $23 -throw exit then
  dup blk !
  $A lshift ( <-- b/buf * ) ;

h: c/l* ( c/l * ) 6 lshift ;            ( u -- u )
h: c/l/ ( c/l / ) 6 rshift ;            ( u -- u )
h: line swap block swap c/l* + c/l ;    ( k u -- a u )
h: loadline line evaluate ;             ( k u -- )
: load 0 l/b 1- for 2dup 2>r loadline 2r> 1+ next 2drop ; ( k -- )
h: pipe [char] | emit ;                      ( -- )
h: .border 3 spaces c/l [char] - nchars cr ; ( -- )
h: #line dup 2 u.r ;                    ( u -- u : print line number )
h: blank =bl fill ;                     ( b u -- )
h: retrieve block drop ;                ( k -- )
: list                                  ( k -- )
  dup retrieve
  cr
  .border
  0 begin
    dup l/b <
  while
    2dup #line pipe line $type pipe cr 1+
  repeat .border 2drop ;

h: check-header? header-options @ first-bit 0= ; ( -- t )
h: disable-check 1 header-options toggle ;       ( -- )

h: bist ( -- u : built in self test )
  check-header? if 0x0000 exit then       ( is checking disabled? Success? )
  header-length @ here xor if 2 exit then ( length check )
  header-crc @ header-crc zero            ( retrieve and zero CRC )
  0 here crc xor if 3 exit then           ( check CRC )
  disable-check 0x0000 ;                  ( disable check, success )

h: cold ( -- : performs a cold boot  )
   bist ?dup if negate dup yield? exit then
   $10 block b/buf 0 fill
   $12 retrieve io!
   forth sp0 sp!
   <boot> @execute bye ;

h: hi hex cr ." eFORTH V " ver 0 u.r cr here . .free cr postpone [ ; ( -- )
h: normal-running hi quit ;                 ( -- : boot word )

h: validate tuck cfa <> if drop-0 exit then nfa ; ( cfa pwd -- nfa | 0 )

h: search-for-cfa ( wid cfa -- nfa : search for CFA in a word list )
  address cells >r
  begin
    dup
  while
    address dup r@ swap dup@ address swap within ( simplify? )
    if dup @address r@ swap validate ?dup if rdrop nip exit then then
    address @
  repeat rdrop ;

h: name ( cwf -- a | 0 )
   >r
   get-order
   begin
     dup
   while
     swap r@ search-for-cfa ?dup if >r 1- ndrop r> rdrop exit then
   1- repeat rdrop ;

h: .name name ?dup 0= if $" ?" then print ;
h: ?instruction ( i m e -- i 0 | e -1 )
   >r over and r> tuck = if nip [-1] exit then drop-0 ;

h: .instruction ( u -- u )
   ( dup )
   0x8000  0x8000 ?instruction if ." LIT" ( swap .lit ) exit then
   $6000   $6000  ?instruction if ( nip ) ." ALU" exit then
   $6000   $4000  ?instruction if ( nip ) ." CAL" exit then
   $6000   $2000  ?instruction if ( nip ) ." BRZ" exit then
   ( drop ) drop-0 ." BRN" ;

h: decompile ( u -- : decompile instruction )
   dup .instruction $BFFF and 0=
   if space .name exit then drop ;

h: decompiler ( previous current -- : decompile starting at address )
  >r
   begin dup r@ u< while
     dup 5u.r colon space
     dup@
     dup 5u.r space decompile cr cell+
   repeat rdrop drop ;

: see ( --, <string> : decompile a word )
  token finder 0= if not-found exit then
  swap      2dup= if drop here then >r
  cr colon space dup .id space dup cr
  cfa r> decompiler space [char] ; emit
  dup compile-only? if ."  compile-only " then
  dup inline?       if ."  inline "       then
      immediate?    if ."  immediate "    then cr ;

: .s cr depth for aft r@ pick . then next ."  <sp" ;          ( -- )
h: dm+ chars for aft dup@ space 5u.r cell+ then next ;        ( a u -- a )

: dump ( a u -- )
  $10 + \ align up by dump-width
  4 rshift ( <-- equivalent to "dump-width /" )
  for
    aft
      cr dump-width 2dup
      over 5u.r colon space
      dm+ ( dump-width dc+ ) \ <-- dc+ is optional
      -rot
      2 spaces $type
    then
  next drop ;

[last]              [t] _forth-wordlist t!
[t] _forth-wordlist [t] current         t!

0 tlast meta!
h: [block] blk-@ block ;       ( k -- a : loaded block address )
h: [check] dup b/buf c/l/ u>= if $18 -throw exit then ;
h: [line] [check] c/l* [block] + ; ( u -- a )
: b retrieve ;                 ( k -- : load a block )
: l blk-@ list ;               ( -- : list current block )
: n  1 +block b l ;            ( -- : load and list next block )
: p [-1] +block b l ;          ( -- : load and list previous block )
: d [line] c/l blank ;         ( u -- : delete line )
: x [block] b/buf blank ;      ( -- : erase loaded block )
: s update flush ;             ( -- : flush changes to disk )
: q editor-voc -order ;        ( -- : quit editor )
: e q blk-@ load editor ;      ( -- : evaluate block )
: ia c/l* + [block] + source drop in@ + ( u u -- )
   swap source nip in@ - cmove postpone \ ;
: i 0 swap ia ;                ( u -- )
[last] [t] editor-voc t! 0 tlast meta!

there [t] cp t!
[t] (literal) [v] <literal> t!   ( set literal execution vector )
[t] cold 2/ 0 t!                 ( set starting word )
[t] normal-running [v] <boot> t!

there    $B tcells t! \ Set Length First!
checksum $C tcells t! \ Calculate image CRC

finished
bye

