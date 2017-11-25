0 ok! ( Turn off 'ok' prompt )
\ | Project   | A Small Forth VM/Implementation |
\ | --------- | ------------------------------- |
\ | Author    | Richard James Howe              |
\ | Copyright | 2017 Richard James Howe         |
\ | License   | MIT                             |
\ | Email     | howe.r.j.89@gmail.com           |
 
\ ## A Meta-compiler, an implementation of eForth and a tutorial on both.
\ Project site: <https://github.com/howerj/embed>

\ # Introduction

\ @todo Complete the introduction
\ - Describe where the Forth came from (from a VHDL CPU project, eForth, ...)
\ - Philosophy of Forth
\ - What a meta compiler is
\ - Purpose of this document
\ - A little bit about Forth, a simple introduction
\ - How Vocabularies work

\ The project, documentation and Forth images are under an MIT license,
\ <https://github.com/howerj/embed/blob/master/LICENSE> and the
\ repository is available at <https://github.com/howerj/embed/>.

\ The document is structured in roughly the following order:
\ 1.  The metacompiler
\ 2.  The assembler
\ 3.  Image header generation
\ 4.  Basic Setup, Variables and Special cases
\ 5.  Simple Forth Words, Numeric I/O
\ 6.  Interpreter
\ 7.  Control Words
\ 8.  I/O Control, Boot Words
\ 9. 'See', the Disassembler
\ 10. Block Editor
\ 11. Finishing
\ 12. APPENDIX

\ What you are reading is itself a Forth program, all the explanatory text is
\ are Forth comments. The file should eventually be fed through a preprocessor 
\ to turn it into a Markdown file for further processing.
\ See <https://daringfireball.net/projects/markdown/> for more information
\ about Markdown.

\ Many Forths are written in an assembly language, especially the ones geared
\ towards microcontrollers, although it is more common for new Forth
\ interpreters to be written in C. A metacompiler is a Cross Compiler
\ <https://en.wikipedia.org/wiki/Cross_compiler> written in Forth.

\ References
\ * 'The Zen of eForth' by C. H. Ting
\ * <https://github.com/howerj/embed> (This project)
\ * <https://github.com/howerj/libforth>
\ * <https://github.com/howerj/forth-cpu>
\ Jones Forth:
\ * <https://rwmj.wordpress.com/2010/08/07/jonesforth-git-repository/>
\ * <https://github.com/AlexandreAbreu/jonesforth>
\ J1 CPU
\ * <excamera.com/files/j1.pdf>
\ * <http://excamera.com/sphinx/fpga-j1.html>
\ * <https://github.com/jamesbowman/j1>
\ * <https://github.com/samawati/j1eforth>

\ The Virtual Machine is specifically designed to execute Forth, it is a stack
\ machine that allows many Forth words to be encoded in one instruction but
\ does not contain any high level Forth words, just words like '@', 'r>' and
\ a few basic words for I/O. A full description of the virtual machine is
\ in the appendix.

\ ## Metacompilation wordset
\ This section defines the metacompilation wordset as well as the
\ assembler. The metacompiler, or cross compiler, requires some assembly
\ instructions to be defined so the two word sets are interlinked. 
\ 
\ A clear understanding of how Forth vocabularies work is needed before
\ proceeding with the tutorial. Vocabularies are the way Forth manages
\ namespaces and are generally talked about that much, they are especially
\ useful (in fact pretty much required) for writing a metacompiler.

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
variable fence         ( Do not peephole optimize before this point )
1984 constant #version ( Version number )
5000 constant #target  ( Memory location where the target image will be built )
2000 constant #max     ( Max number of cells in generated image )
2    constant =cell    ( Target cell size )
-1   constant optimize ( Turn optimizations on [-1] or off [0] )
0    constant swap-endianess ( if true, swap the endianess )
$4280 constant pad-area    ( area for pad storage )
variable header -1 header ! ( If true Headers in the target will be generated )

1   constant verbose   ( verbosity level, higher is more verbose )
#target #max 0 fill    ( Erase the target memory location )

: ]asm assembler.1 +order ; immediate ( -- )
: a: get-current assembler.1 set-current : ; ( "name" -- wid link )
: a; [compile] ; set-current ; immediate ( wid link -- )

: ( [char] ) parse 2drop ; immediate
: \ source drop @ >in ! ; immediate
: there tcp @ ; ( -- a : target dictionary pointer value )
: tc! #target + c! ;
: tc@ #target + c@ ;
: [address] $3fff and ;
: [last] tlast @ ;
: low  swap-endianess 0= if 1+ then ; ( b -- b )
: high swap-endianess    if 1+ then ; ( b -- b )
: t! over ff and over high tc! swap 8 rshift swap low tc! ;
: t@ dup high tc@ swap low tc@ 8 lshift or ;
: 2/ 1 rshift ;
: talign there 1 and tcp +! ;
: tc, there tc! 1 tcp +! ;
: t,  there t!  =cell tcp +! ;
: tallot tcp +! ;
: update-fence there fence ! ;
: $literal 
  [char] " word count dup tc, 1- for count tc, next drop talign update-fence ;
: tcells =cell * ;
: tbody 1 tcells + ;
: s! ! ;
: dump-hex #target there 16 + dump ;
: locations ( -- : list all words and locations in target dictionary )
  target.1 @ 
  begin 
    dup 
  while 
    dup 
    nfa count type space dup
    cfa >body @ u. cr
    $3fff and @ 
  repeat drop ;

: display ( -- : display metacompilation and target information )
  verbose 0= if exit then
  hex
  ." COMPILATION COMPLETE" cr
  verbose 1 u> if 
    dump-hex cr 
    ." TARGET DICTIONARY: " cr
    \ words 
    locations
  then
  \ ." META: "       meta        . cr
  \ ." TARGET: "     target.1    . cr
  \ ." ASSEMBLER: "  assembler.1 . cr
  ." HOST: "       here        . cr
  ." TARGET: "     there       . cr
  ." HEADER: "     #target 20 dump cr ;

: checksum #target there crc ;

: save-hex ( -- : save target binary to file )
   #target #target there + (save) throw ;

: finished ( -- : save target image and display statistics )
   display
   only forth definitions hex
   ." SAVING... " save-hex ." DONE! " cr
   ." STACK> " .s cr ;

: [a] ( "name" -- : find word and compile an assembler word )
  token assembler.1 search-wordlist 0= if abort" [a]? " then
  cfa compile, ; immediate

: asm[ assembler.1 -order ; immediate ( -- )

a: #branch  $0000 a;
a: #?branch $2000 a;
a: #call    $4000 a;
a: #alu     $6000 a;
a: #literal $8000 a;

\ ALU Operations
a: #t      0000 a;
a: #n      0100 a;
a: #r      0200 a;
a: #[t]    0300 a;
a: #n->[t] 0400 a;
a: #t+n    0500 a;
a: #t*n    0600 a;
a: #t&n    0700 a;
a: #t|n    0800 a;
a: #t^n    0900 a;
a: #~t     0a00 a;
a: #t-1    0b00 a;
a: #t==0   0c00 a;
a: #t==n   0d00 a;
a: #nu<t   0e00 a;
a: #n<t    0f00 a;
a: #n>>t   1000 a;
a: #n<<t   1100 a;
a: #sp@    1200 a;
a: #rp@    1300 a;
a: #sp!    1400 a;
a: #rp!    1500 a;
a: #save   1600 a;
a: #tx     1700 a;
a: #rx     1800 a;
a: #u/mod  1900 a;
a: #/mod   1a00 a;
a: #bye    1b00 a;

\ The Stack Delta Operations occur after the ALU operations have been executed.
\ They affect either the Return or the Variable Stack. An ALU instruction
\ without one of these operations (generally) do not affect the stacks.
a: d+1     0001 or a; ( increment variable stack by one )
a: d-1     0003 or a; ( decrement variable stack by one )
a: d-2     0002 or a; ( decrement variable stack by two )
a: r+1     0004 or a; ( increment variable stack by one )
a: r-1     000c or a; ( decrement variable stack by one )
a: r-2     0008 or a; ( decrement variable stack by two )

\ All of these instructions execute after the ALU and stack delta operations
\ have been performed except r->pc, which occurs before. They form part of
\ an ALU operation.
a: r->pc   0010 or a; ( Set Program Counter to Top of Return Stack )
a: n->t    0020 or a; ( Set Top of Variable Stack to Next on Variable Stack )
a: t->r    0040 or a; ( Set Top of Return Stack to Top on Variable Stack )
a: t->n    0080 or a; ( Set Next on Variable Stack to Top on Variable Stack )

\ There are five types of instructions; ALU operations, branches,
\ conditional branches, function calls and literals. ALU instructions
\ comprise of an ALU operation, stack effects and register move bits. Function
\ returns are part of the ALU operation instruction set.

: ?set dup $e000 and if abort" argument too large " then ;
a: branch  2/ ?set [a] #branch  or t, a; ( a -- : an Unconditional branch )
a: ?branch 2/ ?set [a] #?branch or t, a; ( a -- : Conditional branch )
a: call    2/ ?set [a] #call    or t, a; ( a -- : Function call )
a: ALU        ?set [a] #alu     or    a; ( u -- : Make ALU instruction )
a: alu                    [a] ALU  t, a; ( u -- : ALU operation )
a: literal ( n -- : compile a number into target )
  dup [a] #literal and if   ( numbers above $7fff take up two instructions )
    invert recurse  ( the number is inverted, an literal is called again )
    [a] #~t [a] alu ( then an invert instruction is compiled into the target )
  else
    [a] #literal or t, ( numbers below $8000 are single instructions )
  then a;
a: return ( -- : Compile a return into the target )
   [a] #t [a] r->pc [a] r-1 [a] alu a;

\ The following words implement a primitive peephole optimizer, which is not
\ the only optimization done, but is the major one. It performs tail call
\ optimizations and merges the return instruction with the previous instruction
\ if possible. 

: previous there =cell - ;
: lookback previous t@ ;
: call? lookback $e000 and [a] #call = ;
: call>goto previous dup t@ $1fff and swap t! ;
: fence? fence @  previous u> ;
: safe? lookback $e000 and [a] #alu = lookback $001c and 0= and ;
: alu>return previous dup t@ [a] r->pc [a] r-1 swap t! ;

: exit-optimize
  fence? if [a] return exit then
  call?  if call>goto  exit then
  safe?  if alu>return exit then
  [a] return ;

: exit, exit-optimize update-fence ;

: compile-only tlast @ t@ $8000 or tlast @ t! ;
: immediate tlast @ t@ $4000 or tlast @ t! ;

\ create a word in the metacompilers dictionary, not the targets
: tcreate get-current >r target.1 set-current create r> set-current ;

: thead ( b u -- : compile word header into target dictionary )
  header @ 0= if 2drop exit then
  talign
  there [last] t, tlast ! 
  there #target + pack$ c@ 1+ aligned tcp +! talign ;

: lookahead ( -- b u : parse a word, but leave it in the input stream )
  >in @ >r bl parse r> >in ! ;

\ The word 'h:' creates a headerless word in the target dictionary for
\ space saving reasons and to declutter the target search order. Ideally 
\ it would instead add the word to a different vocabulary, so it is still 
\ accessible to the programmer, but there is already very little room on the
\ target.
: h: ( -- : create a word with no name in the target dictionary )
 $f00d tcreate there , update-fence does> @ [a] call ;

: t: ( "name", -- : creates a word in the target dictionary )
  lookahead thead h: ;

: fallthrough; $f00d <> if abort" unstructured! " then ;
: t; fallthrough; optimize if exit, else [a] return then ;

: fetch-xt @ dup 0= if abort" (null) " then ; ( a -- xt )

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

: [t]
  token target.1 search-wordlist 0= if abort" [t]? " then
  cfa >body @ ;
: [u] [t] =cell + ; \ @warning only use on variables, not tlocations 

\ xchange takes two vocabularies defined in the target by their variable
\ names "name1" and "name2" and updates "name1" so it contains the previously
\ defined words, and makes "name2" the vocabulary which subsequent definitions
\ are added to.
: xchange ( "name1", "name2", -- : exchange target vocabularies )
  [last] [t] t! [t] t@ tlast s! ; 

: literal [a] literal ;
: begin  there update-fence ;
: until  [a] ?branch ;
: if     there update-fence 0 [a] ?branch  ;
: skip   there update-fence 0 [a] branch ;
: then   begin 2/ over t@ or swap t! ;
: else   skip swap then ;
: while  if swap ;
: repeat [a] branch then update-fence ;
: again  [a] branch update-fence ;
: aft    drop skip begin swap ;
: constant tcreate , does> @ literal ;
: [char] char literal ;
: tcompile, [a] call ;
: tcall [t] tcompile, ;
: next tdoNext fetch-xt [a] call t, update-fence ;

\ Instructions
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
\ : exit    ]asm  #t       r->pc  r-1   alu asm[ ;
: exit exit, ;
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
: (bye)   ]asm  #bye     alu asm[ ;
: rx?     ]asm  #rx      t->n   d+1   alu asm[ ;
: tx!     ]asm  #tx      n->t   d-1   alu asm[ ;
: (save)  ]asm  #save    d-1    alu asm[ ;
: u/mod   ]asm  #u/mod   t->n   alu asm[ ;
: /mod    ]asm  #u/mod   t->n   alu asm[ ;
: /       ]asm  #u/mod   d-1    alu asm[ ;
: mod     ]asm  #u/mod   n->t   d-1   alu asm[ ;
: rdrop   ]asm  #t       r-1    alu asm[ ;
\ Special instructions
: dup-@   ]asm  #[t]     t->n   d+1 alu asm[ ;
: dup>r   ]asm  #t       t->r   r+1 alu asm[ ;
: 2dup=   ]asm  #t==n    t->n   d+1 alu asm[ ;
: 2dup-xor ]asm #t^n     t->n   d+1 alu asm[ ;
: rxchg   ]asm  #r       t->r       alu asm[ ;

: for >r begin ;
\ : next r@ while r> 1- >r repeat r> drop ;

]asm #~t              ALU asm[ constant =invert ( invert instruction )
]asm #t  r->pc    r-1 ALU asm[ constant =exit   ( return/exit instruction )
]asm #n  t->r d-1 r+1 ALU asm[ constant =>r     ( to r. stk. instruction )
$20   constant =bl         ( blank, or space )
$d    constant =cr         ( carriage return )
$a    constant =lf         ( line feed )
$8    constant =bs         ( back space )
$1b   constant =escape     ( escape character )

$10   constant dump-width  ( number of columns for 'dump' )
$50   constant tib-length  ( size of terminal input buffer )
$1f   constant word-length ( maximum length of a word )

$40   constant c/l ( characters per line in a block )
$10   constant l/b ( lines in a block )
$4400 constant sp0 ( start of variable stack )
$7fff constant rp0 ( start of return stack )

( Volatile variables )
$4000 constant _test       ( used in skip/test )
$4002 constant last-def    ( last, possibly unlinked, word definition )
$4006 constant id          ( used for source id )
$4008 constant seed        ( seed used for the PRNG )
$400A constant handler     ( current handler for throw/catch )
$400C constant block-dirty ( -1 if loaded block buffer is modified )
$4010 constant _key        ( -- c : new character, blocking input )
$4012 constant _emit       ( c -- : emit character )
$4014 constant _expect     ( "accept" vector )
\ $4016 constant _tap      ( "tap" vector, for terminal handling )
\ $4018 constant _echo     ( c -- : emit character )
$4020 constant _prompt     ( -- : display prompt )
$4110 constant context     ( holds current context for search order )
$4122 constant #tib        ( Current count of terminal input buffer )
$4124 constant tib-buf     ( ... and address )
$4126 constant tib-start   ( backup tib-buf value )
\ $4280 == pad-area    

$c    constant header-length ( location of length in header )
$e    constant header-crc    ( location of CRC in header )

( ===                        Target Words                           === )
\ With the assembler and meta compiler complete, we can now make our target
\ application, a Forth interpreter which will be able to read in this file
\ and create new, possibly modified, images for the Forth virtual machine
\ to run.

target.1 +order         ( Add target word dictionary to search order )
meta -order meta +order ( Reorder so 'meta' has a higher priority )
forth-wordlist   -order ( Remove normal Forth words to prevent accidents )

\ The following 't,' sequence reserves space and partially populates the
\ image header with file format information, based upon the PNG specification.
\ See <http://www.fadden.com/tech/file-formats.html> and
\ <https://stackoverflow.com/questions/323604> for more information about
\ how to design binary formats

0        t, \  $0: First instruction executed, jump to start / reset vector
0        t, \  $2: Instruction exception vector
$4689    t, \  $4: 0x89 'F'
$4854    t, \  $6: 'T'  'H'
$0a0d    t, \  $8: '\r' '\n'
$0a1a    t, \  $A: ^Z   '\n'
0        t, \  $C: For Length
0        t, \  $E: For CRC
$0001    t, \ $10: Endianess check
#version t, \ $12: Version information

h: doVar   r> t;
h: doConst r> @ t;

[t] doVar tdoVar s!
[t] doConst tdoConst s!

0 tlocation cp                ( Dictionary Pointer: Set at end of file )
0 tlocation root-voc          ( root vocabulary )
0 tlocation editor-voc        ( editor vocabulary )
0 tlocation assembler-voc     ( assembler vocabulary )
0 tlocation _forth-wordlist   ( set at the end near the end of the file )
0 tlocation current           ( WID to add definitions to )

\ === ASSEMBLY INSTRUCTIONS ===
t: nop      nop      t;
t: dup      dup      t;
t: over     over     t;
t: invert   invert   t;
t: um+      um+      t;
t: +        +        t;
t: um*      um*      t;
t: *        *        t;
t: swap     swap     t;
t: nip      nip      t;
t: drop     drop     t;
t: @        @        t;
t: !        !        t;
t: rshift   rshift   t;
t: lshift   lshift   t;
t: =        =        t;
t: u<       u<       t;
t: <        <        t;
t: and      and      t;
t: xor      xor      t;
t: or       or       t;
t: sp@      sp@      t;
t: sp!      sp!      t;
t: 1-       1-       t;
t: 0=       0=       t;
t: (bye)    (bye)    t;
t: rx?      rx?      t;
t: tx!      tx!      t;
t: (save)   (save)   t;
t: u/mod    u/mod    t;
t: /mod     /mod     t;
t: /        /        t;
t: mod      mod      t;

there constant inline-start 
t: rp@      rp@      nop t; compile-only
t: rp!      rp!      nop t; compile-only
t: exit     exit     nop t; compile-only
t: >r       >r       nop t; compile-only
t: r>       r>       nop t; compile-only
t: r@       r@       nop t; compile-only
t: rdrop    rdrop    nop t; compile-only 
there constant inline-end 

[last] [t] assembler-voc t!

$2       tconstant cell  ( size of a cell in bytes )
$0       tvariable >in   ( Hold character pointer when parsing input )
$0       tvariable state ( compiler state variable )
$0       tvariable hld   ( Pointer into hold area for numeric output )
$10      tvariable base  ( Current output radix )
$0       tvariable span  ( Hold character count received by expect   )
$8       tconstant #vocs ( number of vocabularies in allowed )
$400     tconstant b/buf ( size of a block )
0        tvariable blk   ( current blk loaded, set in 'cold' )
#version tconstant ver   ( eForth version )
0        tvariable boot         ( -- : execute program at startup )
pad-area tconstant pad   ( pad variable - offset into temporary storage )

h: swap! swap ! t;           ( a u -- )
h: [-1] -1 literal t;        ( -- -1 : space saving measure, push -1 )
h: 0x8000 $8000 literal t;   ( -- $8000 : space saving measure, push $8000 )
h: 0x0000 $0000 literal t;   ( -- $0000 : space/optimization, push $0000 )
t: 2drop drop drop t;        ( n n -- )
h: drop-0 drop 0x0000 t;  ( n -- 0 )
h: 2drop-0 2drop 0x0000 t; ( n n -- 0 )
h: state@ state @ t;         ( -- u )
h: first-bit 1 literal and t; ( u -- u )

t: 1+ 1 literal + t;         ( n -- n : increment a value  )
t: negate invert 1+ t;       ( n -- n : negate a number )
t: - negate + t;             ( n1 n2 -- n : subtract n1 from n2 )
h: over- over - t;           ( u u -- u u )
h: over+ over + t;           ( u1 u2 -- u1 u1+2 )
h: in! >in ! t;              ( u -- )
h: in@ >in @ t;              ( -- u )
t: aligned dup first-bit + t; ( b -- a )
t: bye 0 literal (bye) t;    ( -- : leave the interpreter )
t: cell- cell - t;           ( a -- a : adjust address to previous cell )
t: cell+ cell + t;           ( a -- a : move address forward to next cell )
t: cells 1 literal lshift t; ( n -- n : convert cells count to address count )
t: chars 1 literal rshift t; ( n -- n : convert bytes to number of cells )
t: ?dup dup if dup exit then t; ( n -- 0 | n n : duplicate non zero value )
t: >  swap < t;              ( n1 n2 -- f : signed greater than, n1 > n2 )
t: u> swap u< t;             ( u1 u2 -- f : unsigned greater than, u1 > u2 )
t: u>= u< invert t;          ( u1 u2 -- f : )
t: <> = invert t;            ( n n -- f : not equal )
t: 0<> 0= invert t;          ( n n -- f : not equal  to zero )
t: 0> 0 literal > t;         ( n -- f : greater than zero? )
t: 0< 0 literal < t;         ( n -- f : less than zero? )
t: 2dup over over t;         ( n1 n2 -- n1 n2 n1 n2 )
t: tuck swap over t;         ( n1 n2 -- n2 n1 n2 )
t: +! tuck @ + swap! t;      ( n a -- : increment value at address by 'n' )
t: 1+!  1 literal swap +! t; ( a -- : increment value at address by 1 )
t: 1-! [-1] swap +! t;       ( a -- : decrement value at address by 1 )
t: execute >r t;             ( cfa -- : execute a function )
t: c@ dup-@ swap first-bit
   if
      8 literal rshift exit
   then
   $ff literal and t; ( b -- c )
t: c!                       
  swap $ff literal and dup 8 literal lshift or swap
  swap over dup ( -2 and ) @ swap first-bit 0= $ff literal xor
  >r over xor r> and xor swap ! t;     ( c b -- )
h: string@ over c@ t;                  ( b u -- b u c )
t: 2! ( d a -- ) tuck ! cell+ ! t;     ( n n a -- )
t: 2@ ( a -- d ) dup cell+ @ swap @ t; ( a -- n n )
t: command? state@ 0= t;               ( -- f )
t: get-current current @ t;            ( -- wid )
t: set-current current ! t;            ( wid -- )
t: here cp @ t;                        ( -- a )
t: align here fallthrough;             ( -- )
h: cp! aligned cp ! t;                 ( n -- )
t: source #tib 2@ t;                   ( -- a u )
t: source-id id @ t;                   ( -- 0 | -1 )
h: @execute @ ?dup if >r then t;       ( cfa -- )
t: bl =bl t;                           ( -- c )
t: within over- >r - r> u< t;          ( u lo hi -- f )
\ t: dnegate invert >r invert 1 literal um+ r> + t; ( d -- d )
t: abs dup 0< if negate exit then t;   ( n -- u )
t: count dup 1+ swap c@ t;             ( cs -- b u )
t: rot >r swap r> swap t;              ( n1 n2 n3 -- n2 n3 n1 )
t: -rot swap >r swap r> t;             ( n1 n2 n3 -- n3 n1 n2 )
\ @warning be careful with '2>r' and '2r>' as peephole optimizer can
\ break these words. They should not be used before an 'exit' or a 't;'.
h: 2>r rxchg swap >r >r t;              ( u1 u2 --, R: -- u1 u2 )
h: 2r> r> r> swap rxchg nop t; ( -- u1 u2, R: u1 u2 -- )
h: doNext 2r> ?dup if 1- >r @ >r exit then cell+ >r t;
[t] doNext tdoNext s!
t: min 2dup < fallthrough;          ( n n -- n )
h: mux if drop exit then nip t; ( n1 n2 b -- n : multiplex operation )
t: max 2dup > mux t;                    ( n n -- n )
h: >char $7f literal and dup $7f literal =bl within
  if drop [char] _ then t;              ( c -- c )
h: tib #tib cell+ @ t;                  ( -- a )
\ h: echo _echo @execute t;             ( c -- )
t: key _key @execute dup [-1] ( <-- EOF = -1 ) = if bye then t; ( -- c )
t: allot cp +! t;                       ( n -- )
t: /string over min rot over+ -rot - t; ( b u1 u2 -- b u : advance string u2 )
h: +string 1 literal /string t;         ( b u -- b u : )
h: @address @ fallthrough;              ( a -- a )
h: address $3fff literal and t;         ( a -- a : mask off address bits )
h: last get-current @address t;         ( -- pwd )
t: emit _emit @execute t;               ( c -- : write out a char )
t: cr =cr emit =lf emit t;              ( -- )
t: space =bl emit t;                    ( -- )
h: depth sp@ sp0 - chars t;             ( -- u )
h: vrelative cells sp@ swap - t;        ( -- u )
t: pick  vrelative @ t;                 ( vn...v0 u -- vn...v0 vu )
t: type 0 literal fallthrough;          ( b u -- )
h: typist                               ( b u f -- : print a string )
  >r begin dup while
    swap count r@
    if
      >char
    then
    emit
    swap 1-
  repeat
  rdrop 2drop t;
h: print count type t; ( b -- )
h: $type [-1] typist t;
h: decimal? [char] 0 [char] : within t; ( c -- f : decimal char? )
h: lowercase? [char] a [char] { within t;   ( c -- f )
h: uppercase? [char] A [char] [ within t;   ( c -- f )
h: >lower                                   ( c -- c : convert to lower case )
  dup uppercase? if =bl xor exit then t;
t: spaces =bl fallthrough;                  ( +n -- )
h: nchars                                   ( +n c -- : emit c n times )
  swap 0 literal max for aft dup emit then next drop t;
t: cmove for aft >r dup c@ r@ c! 1+ r> 1+ then next 2drop t; ( b b u -- )
t: fill swap for swap aft 2dup c! 1+ then next 2drop t; ( b u c -- )

\ t: even first-bit 0= t;
\ t: odd even 0= t;

t: catch
  sp@ >r
  handler @ >r
  rp@ handler !
  execute
  r> handler !
  r> drop-0 t;

t: throw
  ?dup if
    handler @ rp!
    r> handler !
    rxchg ( <-- r> swap >r )
    sp! drop r>
  then t;

h: -throw negate throw t;  ( space saving measure )
[t] -throw 2/ 2 t! 

h: 1depth 1 literal fallthrough;
h: ?ndepth depth 1- u> if 4 literal -throw exit then t;

\ h: um+ ( w w -- w carry )
\   over over + >r
\   r@ 0 < invert >r
\   over over and
\   0 < r> or >r
\   or 0 < r> and invert 1 +
\   r> swap t; 

\ constant #bits $f
\ constant #high $e ( number of bits - 1, highest bit )
\ t: um/mod ( ud u -- ur uq )
\   ?dup 0= if $a literal -throw exit then
\   2dup u<
\   if negate #high
\     for >r dup um+ >r >r dup um+ r> + dup
\       r> r@ swap >r um+ r> or
\       if >r drop 1+ r> else drop then r>
\     next
\     drop swap exit
\   then drop 2drop [-1] dup t;

\ t: m/mod ( d n -- r q ) \ floored division
\   dup 0< dup>r
\   if
\     negate >r dnegate r>
\   then
\   >r dup 0< if r@ + then r> um/mod r>
\   if swap negate swap exit then t;

t: decimal $a literal base ! t;              ( -- )
t: hex     $10 literal base ! t;             ( -- )
h: radix base @ dup 2 literal - $22 literal u>
  if hex $28 literal -throw exit then t;
h: digit  9 literal over < 7 literal and + [char] 0 + t; ( u -- c )
h: extract u/mod swap t;               ( n base -- n c )
t: hold  hld @ 1- dup hld ! c! fallthrough;  ( c -- )
h: ?hold hld @ pad $100 literal + u> if $11 literal -throw exit then t;  ( -- )
\ t: holds begin dup while 1- 2dup + c@ hold repeat 2drop t;
t: sign  0< if [char] - hold exit then t;    ( n -- )
t: #>  drop hld @ pad over- t;               ( w -- b u )
t: #  1depth radix extract digit hold t;     ( u -- u )
t: #s begin # dup while repeat t;            ( u -- 0 )
t: <#  pad hld ! t;                          ( -- )
h: str ( n -- b u : convert a signed integer to a numeric string )
  dup>r abs <# #s r> sign #> t;
h: adjust over- spaces type t;   ( b n n -- )
t:  .r >r str r> adjust t;  ( n n : print n, right justified by +n )
h: (u.) <# #s #> t;   ( u -- : )
t: u.r >r (u.) r> adjust t;    ( u +n -- : print u right justified by +n)
t: u.  (u.) space type t;   ( u -- : print unsigned number )
t:  . ( n -- print space, signed number )
   radix $a literal xor if u. exit then str space type t;
t: ? @ . t; ( a -- : display the contents in a memory cell )
\ t: .base base @ dup decimal base ! t; ( -- )

t: pack$ ( b u a -- a ) \ null fill
  aligned dup>r over
  dup cell negate and ( align down )
  - over+ 0 literal swap! 2dup c! 1+ swap cmove r> t;

\ h: ^h ( bot eot cur c -- bot eot cur )
\   >r over r@ < dup
\   if
\     =bs dup echo =bl echo echo
\   then r> + t;

\ h: ktap ( bot eot cur c -- bot eot cur )
\   dup =lf ( <-- was =cr ) xor
\   if =bs xor
\     if =bl tap else ^h then
\     exit
\   then drop nip dup t;

h: tap ( dup echo ) over c! 1+ t; ( bot eot cur c -- bot eot cur )
t: accept ( b u -- b u )
  over+ over
  begin
    2dup-xor
  while
    key dup =lf xor if tap else drop nip dup then
    ( key  dup =bl - 95 u< if tap else _tap @execute then )
  repeat drop over- t;

t: expect ( b u -- ) _expect @execute span ! drop t;
t: query tib tib-length _expect @execute #tib ! drop-0 in! t; ( -- )

t: =string ( a1 u2 a1 u2 -- f : string equality )
  >r swap r> ( a1 a2 u1 u2 )
  over xor if drop 2drop-0 exit then
  for ( a1 a2 )
    aft
      count >r swap count r> xor
      if rdrop 2drop-0 exit then
    then
  next 2drop [-1] t;

t: nfa address cell+ t; ( pwd -- nfa : move to name field address)
t: cfa nfa dup c@ + cell+ $fffe literal and t; ( pwd -- cfa )
h: .id nfa print t; ( pwd -- : print out a word )
h: logical 0= 0= t; ( n -- f )
h: immediate? @ $4000 literal and logical t; ( pwd -- f )
h: compile-only? @ 0x8000 and logical t; ( pwd -- f )
h: inline? inline-start inline-end within t;

h: searcher ( a a -- pwd pwd 1 | pwd pwd -1 | 0 : find a word in a vocabulary )
  swap >r dup
  begin
    dup
  while
    dup nfa count r@ count =string
    if ( found! )
      dup immediate? if 1 literal else [-1] then
      rdrop exit
    then
    nip dup @address
  repeat
  rdrop 2drop-0 t;

h: finder ( a -- pwd pwd 1 | pwd pwd -1 | 0 a 0 : find a word dictionary )
  >r
  context
  begin
    dup-@
  while
    dup-@ @ r@ swap searcher ?dup
    if
      >r rot drop r> rdrop exit
    then
    cell+
  repeat drop-0 r> 0x0000 t;

t: search-wordlist searcher rot drop t; ( a wid -- pwd 1 | pwd -1 | a 0 )
t: find ( a -- pwd 1 | pwd -1 | a 0 : find a word in the dictionary )
  finder rot drop t;

h: numeric? ( char -- n|-1 : convert character in 0-9 a-z range to number )
  >lower
  dup lowercase? if $57 literal - exit then ( 97 = 'a', +10 as 'a' == 10 )
  dup decimal?   if [char] 0 - exit then 
  drop [-1] t;

h: digit? ( c -- f : is char a digit given base )
  >lower numeric? base @ u< t;

h: do-number ( n b u -- n b u : convert string )
  begin
    ( get next character )
    2dup 2>r drop c@ dup digit? ( n char bool, Rt: b u )
    if   ( n char )
      swap base @ * swap numeric? + ( accumulate number )
    else ( n char )
      drop
      2r> ( restore string )
      nop exit
    then
    2r> ( restore string )
    +string dup 0= ( advance string and test for end )
  until t;

h: negative?
   string@ $2D literal =
   if +string [-1] exit then
   0x0000 t; ( b u -- f )

h: base? ( b u -- )
  string@ $24 literal = ( $hex )
  if
    +string hex exit
  then ( #decimal )
  string@ [char] # = if +string decimal exit then t;

h: >number ( n b u -- n b u : convert string )
  radix >r
  negative? >r
  base?
  do-number
  r> if rot negate -rot then
  r> base ! t;

t: number? 0 literal -rot >number nip 0= t; ( b u -- n f : is number? )

h: -trailing ( b u -- b u : remove trailing spaces )
  for
    aft =bl over r@ + c@ <
      if r> 1+ exit then
    then
  next 0x0000 t;

\ @todo rewrite so 'lookfor' does not use vectored word execution

h: lookfor ( b u c -- b u : skip until _test succeeds )
  >r
  begin
    dup
  while
    string@ r@ - r@ =bl = _test @execute if rdrop exit then
    +string
  repeat rdrop t;

h: skipTest if 0> exit then 0<> t; ( n f -- f )
h: scanTest skipTest invert t; ( n f -- f )
h: skipper [t] skipTest literal _test ! lookfor t; ( b u c -- u c )
h: scanner [t] scanTest literal _test ! lookfor t; ( b u c -- u c )

h: parser ( b u c -- b u delta )
  >r over r> swap 2>r 
  r@ skipper 2dup
  r> scanner swap r> - >r - r> 1+ t;

t: parse ( c -- b u t; <string> )
   >r tib in@ + #tib @ in@ - r> parser >in +! -trailing 0 literal max t;
t: ) t; immediate
t: ( $29 literal parse 2drop t; immediate \ )
t: .( $29 literal parse type t;
t: \ #tib @ in! t; immediate
h: ?length dup word-length u> if $13 literal -throw exit then t;
t: word 1depth parse ?length here pack$ t;  ( c -- a ; <string> )
t: token =bl word t;
t: char token count drop c@ t;               ( -- c; <string> )
h: unused $4000 literal here - t;
h: .free unused u. t;

h: preset ( tib ) tib-start #tib cell+ ! 0 literal in! 0 literal id ! t;
t: ] [-1]       state ! t;
t: [  0 literal state ! t; immediate

h: ?error ( n -- : perform actions on error )
  ?dup if
    .             ( print error number )
    [char] ? emit ( print '?' )
    cr
    sp0 sp!       ( empty stack )
    preset        ( reset I/O streams )
    [             ( back into interpret mode )
    exit
  then t;

h: ?dictionary dup $3f00 literal u> if 8 literal -throw exit then t;
t: , here dup cell+ ?dictionary cp! ! t; ( u -- )
t: c, here ?dictionary c! cp 1+! t; ( c -- : store 'c' in the dictionary )
h: doLit 0x8000 or , t;
t: literal ( n -- : write a literal into the dictionary )
  dup 0x8000 and ( n > $7fff ? )
  if
    invert doLit =invert , exit ( store inversion of n the invert it )
  then
  doLit ( turn into literal, write into dictionary )
  t; compile-only immediate

h: make-callable chars $4000 literal or t; ( cfa -- instruction )
t: compile, make-callable , t; ( cfa -- : compile a code field address )
h: $compile dup inline? if cfa @ , exit then cfa compile, t; ( pwd -- )
h: not-found source type $d literal -throw t; ( -- : throw 'word not found' )

\ @todo more words should have vectored execution
\ such as: interpret, literal, abort, page, at-xy, ?error

h: ?compile dup compile-only? if source type $e literal -throw exit then t;
h: interpret ( ??? a -- ??? : The command/compiler loop )
  find ?dup if
    state@
    if
      0> if cfa execute exit then ( <- immediate word )
      $compile exit               ( <- compiling word )
    then
    drop ?compile cfa execute exit
  then 
  \ not a word
  dup count number? if
    nip
    state@ if [t] literal tcompile, exit then exit
  then
  ( drop space print ) not-found t;

t: immediate last $4000 literal fallthrough; ( -- : previous word immediate )
h: toggle over @ xor swap! t;           ( a u -- : xor value at addr with u )
h: do$ r> r@ r> count + aligned >r swap >r t; ( -- a )
h: $"| do$ nop t; ( -- a : do string NB. nop to fool optimizer )
h: ."| do$ print t; ( -- : print string  )

h: .ok command? if ."| $literal  ok  " cr exit then t;
h: ?depth sp@ sp0 u< if 4 literal -throw exit then t;
h: eval
  begin
    token dup c@
  while
    interpret ?depth
  repeat drop _prompt @execute t;
t: quit preset [ begin query [t] eval literal catch ?error again t;
t: ok! _prompt ! t;

h: get-input source in@ id @ _prompt @ t; ( -- n1...n5 )
h: set-input ok! id ! in! #tib 2! t;      ( n1...n5 -- )
t: evaluate ( a u -- )
  get-input 2>r 2>r >r
  0 literal [-1] 0 literal set-input
  [t] eval literal catch
  r> 2r> 2r> set-input
  throw t;

h: ccitt ( crc c -- crc : crc polynomial $1021 AKA "x16 + x12 + x5 + 1" )
  over $8 literal rshift xor    ( crc x )
  dup  $4 literal rshift xor    ( crc x )
  dup  $5 literal lshift xor    ( crc x )
  dup  $c literal lshift xor    ( crc x )
  swap $8 literal lshift xor t; ( crc )

t: crc ( b u -- u : calculate ccitt-ffff CRC )
  $ffff literal >r
  begin
    dup
  while
   string@ r> swap ccitt >r 1 literal /string
  repeat 2drop r> t;

t: random ( -- u : pseudo random number )
  seed @ 0= seed swap toggle seed @ 0 literal ccitt dup seed ! t; 

\ h: not-implemented 15 literal -throw t;
\ [t] not-implemented tvariable =page
\ [t] not-implemented tvariable =at-xy
\ t: page =page @execute t;   ( -- : page screen )
\ t: at-xy =at-xy @execute t; ( x y -- : set cursor position )

h: 5u.r 5 literal u.r t;
h: colon $3a literal emit t; ( -- )

\ t: d. base @ >r decimal  . r> base ! t;
\ t: h. base @ >r hex     u. r> base ! t;

\ ## I/O Control 

h: io! preset fallthrough;  ( -- : initialize I/O )
h: console [t] rx? literal _key ! [t] tx! literal _emit ! fallthrough;
h: hand [t] .ok  literal ( ' "drop" <-- was emit )  ( ' ktap ) fallthrough;
h: xio  [t] accept literal _expect ! ( _tap ! ) ( _echo ! ) ok! t;
\ h: pace 11 emit t;
\ t: file [t] pace literal [t] drop literal [t] ktap literal xio t;

\ ## Control Structures

h: ?check ( $cafe -- : check for magic number on the stack )
   $cafe literal <> if $16 literal -throw exit then t;
h: ?unique ( a -- a : print a message if a word definition is not unique )
  dup last @ searcher
  if
    \ source type
    space
    2drop last-def @ nfa print  ."| $literal  redefined " cr exit
  then t;
h: ?nul ( b -- : check for zero length strings )
   count 0= if $a literal -throw exit then 1- t;
h: find-cfa token find if cfa exit then not-found t;
t: ' find-cfa state@ if tcall literal exit then t; immediate
t: [compile] find-cfa compile, t; immediate compile-only  ( -- ; <string> )
\ NB. 'compile' only works for words, instructions, and numbers below $8000
t: compile  r> dup-@ , cell+ >r t; ( -- : Compile next compiled word )
t: [char] char tcall literal t; immediate compile-only ( --, <string> : )
\ h: ?quit command? if $38 literal -throw exit then t;
t: ; ( ?quit ) ?check =exit , [ fallthrough; immediate compile-only
h: get-current! ?dup if get-current ! exit then t;
t: : align here dup last-def !
    last , token ?nul ?unique count + cp! $cafe literal ] t;
t: begin here  t; immediate compile-only
t: until fallthrough; immediate compile-only
h: jumpz, chars $2000 literal or , t;
t: again fallthrough; immediate compile-only
h: jump, chars ( $0000 literal or ) , t;
h: here-0 here 0x0000 t;
t: if here-0 jumpz, t; immediate compile-only
t: then fallthrough; immediate compile-only
h: doThen  here chars over @ or swap! t;
t: else here-0 jump, swap doThen t; immediate compile-only
t: while tcall if t; immediate compile-only
t: repeat swap tcall again tcall then t; immediate compile-only
h: last-cfa last-def @ cfa t;  ( -- u )
t: recurse last-cfa compile, t; immediate compile-only
t: tail last-cfa jump, t; immediate compile-only
t: create tcall : drop compile doVar get-current ! [ t;
t: >body cell+ t;
h: doDoes r> chars here chars last-cfa dup cell+ doLit ! , t;
t: does> compile doDoes nop t; immediate compile-only
t: variable create 0 literal , t;
t: constant create [t] doConst literal make-callable here cell- ! , t;
t: :noname here 0 literal $cafe literal ]  t;
t: for =>r , here t; immediate compile-only
t: next compile doNext , t; immediate compile-only
t: aft drop here-0 jump, tcall begin swap t; immediate compile-only
t: doer create =exit last-cfa ! =exit ,  t;
t: make
  find-cfa find-cfa make-callable
  state@
  if
    tcall literal tcall literal compile ! nop exit
  then
  swap! t; immediate
t: hide ( "name", -- : hide a given word from the search order )
  token find 0= if not-found exit then nfa $80 literal toggle t;

\ ## Strings 

h: $,' [char] " word count + cp! t; ( -- )
t: $"  compile $"| $,' t; immediate compile-only ( -- ; <string> )
t: ."  compile ."| $,' t; immediate compile-only ( -- ; <string> )
t: abort [-1] (bye) t;
h: {abort} do$ print cr abort t;
t: abort" compile {abort} $,' t; immediate compile-only \ "

\ ## Vocabulary Words 

h: find-empty-cell begin dup-@ while cell+ repeat t; ( a -- a )

t: get-order ( -- widn ... wid1 n : get the current search order )
  context
  find-empty-cell
  dup cell- swap
  context - chars dup>r 1- dup 0< if $32 literal -throw exit then
  for aft dup-@ swap cell- then next @ r> t;

xchange _forth-wordlist root-voc

t: forth-wordlist _forth-wordlist t;

t: set-order ( widn ... wid1 n -- : set the current search order )
  dup [-1] = if drop root-voc 1 literal set-order exit then
  dup #vocs > if $31 literal -throw exit then
  context swap for aft tuck ! cell+ then next 0 literal swap! t;

t: forth root-voc forth-wordlist  2 literal set-order t;

\ The name fields length in a counted string is used to store a bit 
\ indicating the word is hidden. This is the highest bit in the count byte.
h: not-hidden? nfa c@ $80 literal and 0= t;
h: .words space 
    begin 
      dup 
    while dup not-hidden? if dup .id space then @address repeat drop cr t;
t: words
  get-order begin ?dup while swap dup cr u. colon @ .words 1- repeat t;

xchange root-voc _forth-wordlist

t: previous get-order swap drop 1- set-order t;
t: also get-order over swap 1+ set-order t;
t: only [-1] set-order t;
t: order get-order for aft . then next cr t;
t: anonymous get-order 1+ here 1 literal cells allot swap set-order t;
t: definitions context @ set-current t;
t: (order) ( w wid*n n -- wid*n w n )
  dup if
    1- swap >r (order) over r@ xor
    if
      1+ r> -rot exit
    then r> drop
  then t;
t: -order get-order (order) nip set-order t; ( wid -- )
t: +order dup>r -order get-order r> swap 1+ set-order t; ( wid -- )

t: editor decimal root-voc editor-voc 2 literal set-order t;
t: assembler root-voc assembler-voc 2 literal set-order t;
t: ;code assembler t; immediate
t: code : assembler t;

xchange _forth-wordlist assembler-voc
t: end-code forth ; t; immediate
xchange assembler-voc _forth-wordlist

\ ## Block Word Set

t: update [-1] block-dirty ! t;          ( -- )
h: blk-@ blk @ t;
h: +block blk-@ + t;               ( -- )
t: save ( -1 ) 0 literal here (save) throw t;
t: flush block-dirty @ if 0 literal [-1] (save) throw exit then t;

t: block ( k -- a )
  1depth
  dup $3f literal u> if $23 literal -throw exit then
  dup blk !
  $a literal lshift ( <-- b/buf * ) t;

h: c/l* ( c/l * ) 6 literal lshift t;
h: c/l/ ( c/l / ) 6 literal rshift t;
h: line swap block swap c/l* + c/l t;  ( k u -- a u )
h: loadline line evaluate t;  ( k u -- )
t: load 0 literal l/b 1- for 2dup 2>r loadline 2r> 1+ next 2drop t;
h: pipe $7c literal emit t;
h: .line line -trailing $type t;
h: .border 3 literal spaces c/l $2d literal nchars cr t;
h: #line dup 2 literal u.r t;  ( u -- u : print line number )
t: thru over- for dup load 1+ next drop t; ( k1 k2 -- )
t: blank =bl fill t;
\ t: message l/b extract .line cr t; ( u -- )
h: retrieve block drop t;
t: list
  dup retrieve
  cr
  .border
  0 literal begin
    dup l/b <
  while
    2dup #line pipe line $type pipe cr 1+
  repeat .border 2drop t;

\ t: index ( k1 k2 -- : show titles for block k1 to k2 )
\  over- cr
\  for
\    dup 5u.r space pipe space dup 0 literal .line cr 1+
\  next drop t;


\ ## Booting

\ 'bist' checks the length field in the header matches 'here' and that the
\ CRC in the header matches the CRC it calculates in the image, it has to
\ zero the CRC field out first.
h: bist ( -- u : built in self test )
  header-crc @ 0 literal = if 0x0000 exit then ( exit if CRC was zero )
  header-length @ here xor if 2 literal exit then ( length check )
  header-crc @ 0 literal header-crc !   ( retrieve and zero CRC )
  0 literal here crc xor if 3 literal exit then 0x0000 t;

t: cold
   bist ?dup if negate (bye) exit then
   $10 literal block b/buf 0 literal fill
   $12 literal retrieve io! 
   forth sp0 sp! t;

t: hi hex cr ."| $literal eFORTH V " ver 0 literal u.r cr here . .free cr [ t;
h: normal-running hi quit t;
h: boot-sequence cold boot @execute bye t;

\ ## See : The Forth Disassembler

\ @warning This disassembler is experimental, and not liable to work
\ @todo improve this with better output and exit detection.
\ 'see' could be improved with a word that detects when the end of a
\ word actually occurs, and with a disassembler for instructions. The output
\ could also be better formatted, or optionally made to be more or less
\ verbose.

h: validate tuck cfa <> if drop-0 exit then nfa t; ( cfa pwd -- nfa | 0 )

\ @todo Do this for every vocabulary loaded, and name assembly instruction
h: name ( cfa -- nfa )
  address cells >r
  \ last
  context @ @address
  begin
    dup
  while
    address dup r@ swap dup-@ address swap within ( simplify? )
    if @address r> swap validate exit then
    address @
  repeat rdrop t;

h: .name name ?dup 0= if $"| $literal ??? " then print t;

h: ?instruction ( i m e -- i 0 | e -1 )
   >r over and r> tuck = if nip [-1] exit then drop-0 t;

h: .instruction
   0x8000        0x8000        ?instruction if ."| $literal LIT " exit then
   $6000 literal $6000 literal ?instruction if ."| $literal ALU " exit then
   $6000 literal $4000 literal ?instruction if ."| $literal CAL " exit then
   $6000 literal $2000 literal ?instruction if ."| $literal BRZ " exit then
   drop 0 literal ."| $literal BRN " t;

t: decompile ( u -- : decompile instruction )
   dup .instruction $4000 literal =
   if space .name exit then drop t;

h: decompiler ( previous current -- : decompile starting at address )
  >r
   begin dup r@ u< while
     dup 5u.r colon
     dup-@
     dup 5u.r space decompile cr cell+
   repeat rdrop drop t;

\ 'see' is the Forth disassembler, it takes a word and (attempts) to 
\ turn it back into readable Forth source code. The disassembler is only
\ a few hundred bytes in size, which is a testament to the brevity achievable
\ with Forth.
\ 
\ If the word 'see' was good enough we could potentially dispense with the
\ source code entirely: the entire dictionary could be disassembled and saved
\ to disk, modified, then recompiled yielding a modified Forth. Although 
\ comments would not be present, meaning this would be more of an intellectual
\ exercise than of any utility.

t: see ( --, <string> : decompile a word )
  token finder 0= if not-found exit then
  swap 2dup= if drop here then >r
  cr colon space dup .id space dup
  cr
  cfa r> decompiler space $3b literal emit
  dup compile-only? if ."| $literal  compile-only  " then 
  dup inline?       if ."| $literal  inline  "       then
      immediate?    if ."| $literal  immediate  "    then cr t;

t: .s ( -- ) cr depth for aft r@ pick . then next ."| $literal  <sp "  t;

h: dm+ chars for aft dup-@ space 5u.r cell+ then next t; ( a u -- a )
\ h: dc+ chars for aft dup-@ space decompile cell+ then next t; ( a u -- a )

t: dump ( a u -- )
  $10 literal + \ align up by dump-width
  4 literal rshift ( <-- equivalent to "dump-width /" )
  for
    aft
      cr dump-width 2dup
      over 5u.r colon space
      dm+ ( dump-width dc+ ) \ <-- dc+ should be optional?
      -rot
      2 literal spaces $type
    then
  next drop t;

[last] [t] _forth-wordlist t!
[t] _forth-wordlist [t] current t!

\ ## Block Editor

0 tlast s!
h: [block] blk-@ block t;
h: [check] dup b/buf c/l/ u>= if $18 literal -throw exit then t;
h: [line] [check] c/l* [block] + t;
t: b retrieve t;
t: l blk-@ list t;
t: n  1 literal +block b l t;
t: p [-1] +block b l t;
t: d [line] c/l blank t;
t: x [block] b/buf blank t;
t: s update flush t;
t: q forth flush t;
t: e forth blk-@ load editor t;
t: ia c/l* + [block] + source drop in@ +
   swap source nip in@ - cmove [t] \ tcompile, t;
t: i 0 literal swap ia t;
t: u update t;
\ t: w words t;
\ h: yank pad c/l t; hidden
\ t: c [line] yank >r swap r> cmove t;
\ t: y [line] yank cmove t;
\ t: ct swap y c t;
\ t: ea [line] c/l evaluate t;
\ t: sw 2dup y [line] swap [line] swap c/l cmove c t;
[last] [t] editor-voc t! 0 tlast s!

\ ## Final Touches

there           [t] cp t!
[t] boot-sequence 2/ 0 t! ( set starting word )
[t] normal-running [u] boot t!

there    6 tcells t! \ Set Length First!
checksum 7 tcells t! \ Calculate image CRC

finished
bye

\ ## APPENDIX

\ @note The appendix should go here, which should contain the VM source,
\ and a description of the Virtual Machine. The file should also be prepared
\ so it can be sent to a preprocessor that will convert this file to markdown,
\ for viewing on the web.

## The Virtual Machine

The Virtual Machine is a 16-bit stack machine based on the [H2 CPU][], a
derivative of the [J1 CPU][], but adapted for use on a computer.

Its instruction set allows for a fairly dense encoding, and the project
goal is to be fairly small whilst still being useful.  It is small enough
that is should be easily understandable with little explanation, and it
is hackable and extensible by modification of the source code.

## Virtual Machine Memory Map

There is 64KiB of memory available to the Forth virtual machine, of which only
the first 16KiB can contain program instructions (or more accurately branch
locations can only be in the first 16KiB of memory). The virtual machine memory
can divided into three regions of memory, the applications further divide the
memory into different sections.

| Block   |  Region          |
| ------- | ---------------- |
| 0 - 15  | Program Storage  |
| 16      | User Data        |
| 17      | Variable Stack   |
| 18 - 62 | User data        |
| 63      | Return Stack     |

Program execution begins at address zero. The variable stack starts at the
beginning of block 17 and grows upwards, the return stack starts at the end of
block 63 and grows downward.

## Instruction Set Encoding

For a detailed look at how the instructions are encoded the source code is the
definitive guide, available in the file [forth.c][].

A quick overview:

	+---------------------------------------------------------------+
	| F | E | D | C | B | A | 9 | 8 | 7 | 6 | 5 | 4 | 3 | 2 | 1 | 0 |
	+---------------------------------------------------------------+
	| 1 |                    LITERAL VALUE                          |
	+---------------------------------------------------------------+
	| 0 | 0 | 0 |            BRANCH TARGET ADDRESS                  |
	+---------------------------------------------------------------+
	| 0 | 0 | 1 |            CONDITIONAL BRANCH TARGET ADDRESS      |
	+---------------------------------------------------------------+
	| 0 | 1 | 0 |            CALL TARGET ADDRESS                    |
	+---------------------------------------------------------------+
	| 0 | 1 | 1 |   ALU OPERATION   |T2N|T2R|N2T|R2P| RSTACK| DSTACK|
	+---------------------------------------------------------------+
	| F | E | D | C | B | A | 9 | 8 | 7 | 6 | 5 | 4 | 3 | 2 | 1 | 0 |
	+---------------------------------------------------------------+

	T   : Top of data stack
	N   : Next on data stack
	PC  : Program Counter

	LITERAL VALUES : push a value onto the data stack
	CONDITIONAL    : BRANCHS pop and test the T
	CALLS          : PC+1 onto the return stack

	T2N : Move T to N
	T2R : Move T to top of return stack
	N2T : Move the new value of T (or D) to N
	R2P : Move top of return stack to PC

	RSTACK and DSTACK are signed values (twos compliment) that are
	the stack delta (the amount to increment or decrement the stack
	by for their respective stacks: return and data)

### ALU Operations

The ALU can be programmed to do the following operations on an ALU instruction,
some operations trap on error (U/MOD, /MOD).

|  #  | Mnemonic | Description          |
| --- | -------- | -------------------- |
|  0  | T        | Top of Stack         |
|  1  | N        | Copy T to N          |
|  2  | R        | Top of return stack  |
|  3  | T@       | Load from address    |
|  4  | NtoT     | Store to address     |
|  5  | T+N      | Double cell addition |
|  6  | T\*N     | Double cell multiply |
|  7  | T&N      | Bitwise AND          |
|  8  | TorN     | Bitwise OR           |
|  9  | T^N      | Bitwise XOR          |
| 10  | ~T       | Bitwise Inversion    |
| 11  | T--      | Decrement            |
| 12  | T=0      | Equal to zero        |
| 13  | T=N      | Equality test        |
| 14  | Nu&lt;T  | Unsigned comparison  |
| 15  | N&lt;T   | Signed comparison    |
| 16  | NrshiftT | Logical Right Shift  |
| 17  | NlshiftT | Logical Left Shift   |
| 18  | SP@      | Depth of stack       |
| 19  | RP@      | R Stack Depth        |
| 20  | SP!      | Set Stack Depth      |
| 21  | RP!      | Set R Stack Depth    |
| 22  | SAVE     | Save Image           |
| 23  | TX       | Get byte             |
| 24  | RX       | Send byte            |
| 25  | U/MOD    | u/mod                |
| 26  | /MOD     | /mod                 |
| 27  | BYE      | Return               |

### Encoding of Forth Words

Many Forth words can be encoded directly in the instruction set, some of the
ALU operations have extra stack and register effects as well, which although
would be difficult to achieve in hardware is easy enough to do in software.

| Word   | Mnemonic | T2N | T2R | N2T | R2P |  RP |  SP |
| ------ | -------- | --- | --- | --- | --- | --- | --- |
| dup    | T        | T2N |     |     |     |     | +1  |
| over   | N        | T2N |     |     |     |     | +1  |
| invert | ~T       |     |     |     |     |     |     |
| um+    | T+N      |     |     |     |     |     |     |
| \+     | T+N      |     |     | N2T |     |     | -1  |
| um\*   | T\*N     |     |     |     |     |     |     |
| \*     | T\*N     |     |     | N2T |     |     | -1  |
| swap   | N        | T2N |     |     |     |     |     |
| nip    | T        |     |     |     |     |     | -1  |
| drop   | N        |     |     |     |     |     | -1  |
| exit   | T        |     |     |     | R2P |  -1 |     |
| &gt;r  | N        |     | T2R |     |     |   1 | -1  |
| r&gt;  | R        | T2N |     |     |     |  -1 |  1  |
| r@     | R        | T2N |     |     |     |     |  1  |
| @      | T@       |     |     |     |     |     |     |
| !      | NtoT     |     |     |     |     |     | -1  |
| rshift | NrshiftT |     |     |     |     |     | -1  |
| lshift | NlshiftT |     |     |     |     |     | -1  |
| =      | T=N      |     |     |     |     |     | -1  |
| u&lt;  | Nu&lt;T  |     |     |     |     |     | -1  |
| &lt;   | N&lt;T   |     |     |     |     |     | -1  |
| and    | T&N      |     |     |     |     |     | -1  |
| xor    | T^N      |     |     |     |     |     | -1  |
| or     | T|N      |     |     |     |     |     | -1  |
| sp@    | SP@      | T2N |     |     |     |     |  1  |
| sp!    | SP!      |     |     |     |     |     |     |
| 1-     | T--      |     |     |     |     |     |     |
| rp@    | RP@      | T2N |     |     |     |     |  1  |
| rp!    | RP!      |     |     |     |     |     | -1  |
| 0=     | T=0      |     |     |     |     |     |     |
| nop    | T        |     |     |     |     |     |     |
| (bye)  | BYE      |     |     |     |     |     |     |
| rx?    | RX       | T2N |     |     |     |     |  1  |
| tx!    | TX       |     |     | N2T |     |     | -1  |
| (save) | SAVE     |     |     |     |     |     | -1  |
| u/mod  | U/MOD    | T2N |     |     |     |     |     |
| /mod   | /MOD     | T2N |     |     |     |     |     |
| /      | /MOD     |     |     |     |     |     | -1  |
| mod    | /MOD     |     |     | N2T |     |     | -1  |
| rdrop  | T        |     |     |     |     |  -1 |     |

## Interaction

The outside world can be interacted with in two ways, with single character
input and output, or by saving the current Forth image. The interaction is
performed by three instructions.

## eForth

The interpreter is based on eForth by C. H. Ting, with some modifications
to the model.

## eForth Memory model

The eForth model imposes extra semantics to certain areas of memory.

| Address       | Block  | Meaning                        |
| ------------- | ------ | ------------------------------ |
| $0000         |   0    | Start of execution             |
| $0002         |   0    | Trap Handler                   |
| $0004-EOD     |   0    | The dictionary                 |
| EOD-PAD1      |   ?    | Compilation and Numeric Output |
| PAD1-PAD2     |   ?    | Pad Area                       |
| PAD2-$3FFF    |   15   | End of dictionary              |
| $4000         |   16   | Interpreter variable storage   |
| $4400         |   17   | Start of variable stack        |
| $4800-$FBFF   | 18-63  | Empty blocks for user data     |
| $FC00-$FFFF   |   0    | Return stack block             |

## Error Codes

This is a list of Error codes, not all of which are used by the application.

| Hex  | Dec  |  Message                                      |
| ---- | ---- | --------------------------------------------- |
| FFFF |  -1  | ABORT                                         |
| FFFE |  -2  | ABORT"                                        |
| FFFD |  -3  | stack overflow                                |
| FFFC |  -4  | stack underflow                               |
| FFFB |  -5  | return stack overflow                         |
| FFFA |  -6  | return stack underflow                        |
| FFF9 |  -7  | do-loops nested too deeply during execution   |
| FFF8 |  -8  | dictionary overflow                           |
| FFF7 |  -9  | invalid memory address                        |
| FFF6 | -10  | division by zero                              |
| FFF5 | -11  | result out of range                           |
| FFF4 | -12  | argument type mismatch                        |
| FFF3 | -13  | undefined word                                |
| FFF2 | -14  | interpreting a compile-only word              |
| FFF1 | -15  | invalid FORGET                                |
| FFF0 | -16  | attempt to use zero-length string as a name   |
| FFEF | -17  | pictured numeric output string overflow       |
| FFEE | -18  | parsed string overflow                        |
| FFED | -19  | definition name too long                      |
| FFEC | -20  | write to a read-only location                 |
| FFEB | -21  | unsupported operation                         |
| FFEA | -22  | control structure mismatch                    |
| FFE9 | -23  | address alignment exception                   |
| FFE8 | -24  | invalid numeric argument                      |
| FFE7 | -25  | return stack imbalance                        |
| FFE6 | -26  | loop parameters unavailable                   |
| FFE5 | -27  | invalid recursion                             |
| FFE4 | -28  | user interrupt                                |
| FFE3 | -29  | compiler nesting                              |
| FFE2 | -30  | obsolescent feature                           |
| FFE1 | -31  | &gt;BODY used on non-CREATEd definition       |
| FFE0 | -32  | invalid name argument (e.g., TO xxx)          |
| FFDF | -33  | block read exception                          |
| FFDE | -34  | block write exception                         |
| FFDD | -35  | invalid block number                          |
| FFDC | -36  | invalid file position                         |
| FFDB | -37  | file I/O exception                            |
| FFDA | -38  | non-existent file                             |
| FFD9 | -39  | unexpected end of file                        |
| FFD8 | -40  | invalid BASE for floating point conversion    |
| FFD7 | -41  | loss of precision                             |
| FFD6 | -42  | floating-point divide by zero                 |
| FFD5 | -43  | floating-point result out of range            |
| FFD4 | -44  | floating-point stack overflow                 |
| FFD3 | -45  | floating-point stack underflow                |
| FFD2 | -46  | floating-point invalid argument               |
| FFD1 | -47  | compilation word list deleted                 |
| FFD0 | -48  | invalid POSTPONE                              |
| FFCF | -49  | search-order overflow                         |
| FFCE | -50  | search-order underflow                        |
| FFCD | -51  | compilation word list changed                 |
| FFCC | -52  | control-flow stack overflow                   |
| FFCB | -53  | exception stack overflow                      |
| FFCA | -54  | floating-point underflow                      |
| FFC9 | -55  | floating-point unidentified fault             |
| FFC8 | -56  | QUIT                                          |
| FFC7 | -57  | exception in sending or receiving a character |
| FFC6 | -58  | [IF], [ELSE], or [THEN] exception             |


## To Do / Wish List

* Documentation of the project, some words, and the instruction set, as well as
the memory layout
* Remove the compiler after a cross compiler has been made within the Forth
interpreter, prepared images and the metacompiler would be provided instead.
* To facilitate porting to microcontrollers the Forth could be made to be
stored in a ROM, with initial variable values copied to RAM, the virtual
machine would also have to be modified to map different parts of the address
space into RAM and ROM. This would allow the system to require very little
(~2-4KiB) of RAM for a usable system, with a 6KiB ROM.
* Relative jumps could be used instead of absolute jumps in the code, this
would make relocation easier, and could make all code position independent. It
may also make the resulting code easier to compress, especially if the 
majority of jumps are to near locations. Perhaps relative addressing should
only be used for branches and not calls, or vice versa.
* Different ways of compressing the core file, and image self extractions,
should be investigated; [LZSS][], [Run Length Encoding][], [Huffman][] and 
[Adaptive Huffman][] encoding could be implemented in Forth and in the 
meta-compiler so an image can be self-extracted on the fly.
* Routines written in Forth for memory allocation, a soft floating point
library, and a 16-bit metacompiler for the [8086][]/[DOS][] would be useful.
* A method for obfuscating the produced image could be made, perhaps by
xoring the image with a known constant. A trivial obfuscation, obviously. Or
'encrypting' against the output of a Pseudo Random Number Generator for extra 
marks.
* Save and load all state to disk, not just the core. The current system also
does not embed format information into the binary files, which means the
generated object files is indistinguishable from other binary formats.
Magic numbers to identify the format, and Endianess information could be
included in the file format, the metacompiler could insert this information
into the generated object. Other information to include would be a CRC and
length information. See <http://www.fadden.com/tech/file-formats.html>,
and <https://stackoverflow.com/questions/323604>.
* Improve the command line argument passing in [forth.c][].
* On the Windows platform the input and output streams should be reopened in
binary mode.
* More assertions and range checks should be added to the interpreter, for
example the **save** function needs checks for bounds.
* The forth virtual machine in [forth.c][] should be made to be crash proof,
with checks to make sure indices never go out of bounds.
* Documentation could be extracted from the [meta.fth][] file, which should
describe the entire system: The metacompiler, the target virtual machine,
and how Forth works.
* Add more references, and turn this program into a literate file.
   - Compression routines would be a nice to have feature for reducing
   the saved image size. LZSS could be used, see:
   <https://oku.edu.mie-u.ac.jp/~okumura/compression/lzss.c>
   Adaptive Huffman encoding performs even better.
   - Talk about and write about:
     - Potential additions
     - The philosophy of Forth
     - How the meta compiler words
     - Implementing allocation routines, and floating point routines
     - Compression and the similarity of Forth Factoring and LZW compression
* This Forth needs a series of unit tests to make sure the basic functionality
of all the words is correct
* This Forth lacks a version of 'FORGET', as well as 'MARKER', which is
unfortunate, as they are useful.
* One possible exercise would be to reduce the image size to its absoluate
minimum, by removing unneeded functionality for the metacompilation process,
such as the block editor, and 'see', as well as any words not actually used
in the metacompilation process.

[H2 CPU]: https://github.com/howerj/forth-cpu
[J1 CPU]: http://excamera.com/sphinx/fpga-j1.html
[forth.c]: forth.c
[compiler.c]: compiler.c
[eforth.fth]: eforth.fth
[C compiler]: https://gcc.gnu.org/
[make]: https://www.gnu.org/software/make/
[Windows]: https://en.wikipedia.org/wiki/Microsoft_Windows
[Linux]: https://en.wikipedia.org/wiki/Linux
[C99]: https://en.wikipedia.org/wiki/C99
[meta.fth]: meta.fth
[DOS]: https://en.wikipedia.org/wiki/DOS
[8086]: https://en.wikipedia.org/wiki/Intel_8086
[LZSS]: https://en.wikipedia.org/wiki/Lempel%E2%80%93Ziv%E2%80%93Storer%E2%80%93Szymanski
[Run Length Encoding]: https://en.wikipedia.org/wiki/Run-length_encoding
[Huffman]: https://en.wikipedia.org/wiki/Huffman_coding
[Adaptive Huffman]: https://en.wikipedia.org/wiki/Adaptive_Huffman_coding
