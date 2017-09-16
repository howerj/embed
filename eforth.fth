( ======================== System Variables ================= )
constant =exit         $601c hidden ( op code for exit )
constant =invert       $6800 hidden ( op code for invert )
constant =>r           $6147 hidden ( op code for >r )
constant =bl           32    hidden ( blank, or space )
constant =cr           13    hidden ( carriage return )
constant =lf           10    hidden ( line feed )
constant =bs           8     hidden ( back space )
constant =escape       27    hidden ( escape character )

constant dump-width    16    hidden ( number of columns for 'dump' )
constant tib-length    80    hidden ( size of terminal input buffer )
constant pad-length    80    hidden ( pad area begins HERE + pad-length )
constant word-length   31    hidden ( maximum length of a word )

constant c/l           64    hidden ( characters per line in a block )
constant l/b           16    hidden ( lines in a block )
constant sp0           $4400 hidden ( start of variable stack )
constant rp0           $7fff hidden ( start of return stack )

entry:             .allocate 2 ( Entry point - not an interrupt )
error:             .allocate 2 ( Error vector )

location cp               0 ( Dictionary Pointer: Set at end of file )
location root-voc         0 ( root vocabulary )
location editor-voc       0 ( editor vocabulary )
location assembler-voc    0 ( assembler vocabulary )
location _forth-wordlist  0 ( set at the end near the end of the file )
location _words           0 ( words execution vector )
location _forth           0 ( forth execution vector )
location _set-order       0 ( set-order execution vector )
location _do_colon        0 ( execution vector for ':' )
location _do_semi_colon   0 ( execution vector for ';' )
location _boot            0 ( -- : execute program at startup )
\ location _message       0 ( n -- : display an error message )

constant _test       $4000 hidden ( used in skip/test )
constant last-def    $4002 hidden ( last, possibly unlinked, word definition )
constant csp         $4004 hidden ( current data stack pointer - for error checking )
constant _id         $4006 hidden ( used for source id )
constant seed        $4008 hidden ( seed used for the PRNG )
constant handler     $400A hidden ( current handler for throw/catch )
constant block-dirty $400C hidden ( -1 if loaded block buffer is modified )
constant bcount      $400E hidden ( instruction counter used in 'see' )
constant _key        $4010 hidden ( -- c : new character, blocking input )
constant _emit       $4012 hidden ( c -- : emit character )
constant _expect     $4014 hidden ( "accept" vector )
\ constant _tap      $4016 hidden ( "tap" vector, for terminal handling )
\ constant _echo     $4018 hidden ( c -- : emit character )
constant _prompt     $4020 hidden ( -- : display prompt )

constant context     $4110 hidden ( holds current context for vocabulary search order )
constant #tib        $4122 hidden ( Current count of terminal input buffer    )
constant tib-buf     $4124 hidden ( ... and address )
constant tib-start   $4126 hidden ( backup tib-buf value )

.mode 3   ( Turn word header compilation and optimization on )
: execute-location @ >r ; hidden
: forth-wordlist _forth-wordlist ;
: words _words execute-location ;
: set-order _set-order execute-location ;
: forth _forth execute-location ;
.set root-voc $pwd
.pwd 0

.built-in ( Add the built in words to the dictionary )

: end-code forth _do_semi_colon execute-location ; immediate
.set assembler-voc $pwd

: assembler root-voc assembler-voc 2 set-order ;
: ;code assembler ; immediate
: code _do_colon execute-location assembler ;

constant cell       2     ( size of a cell in bytes )
variable >in        0     ( Hold character pointer when parsing input )
variable state      0     ( compiler state variable )
variable hld        0     ( Pointer into hold area for numeric output )
variable base       10    ( Current output radix )
variable span       0     ( Hold character count received by expect   )
variable loaded     0     ( Used by boot block to indicate it has been loaded  )
constant #vocs      8     ( number of vocabularies in allowed )
constant b/buf      1024  ( size of a block )
variable blk        18    ( current blk loaded )
constant ver        $1984 ( eForth version )

location .s-string     " <sp"        ( used by .s )
location see.unknown   "(no-name)"   ( used by 'see' for calls to anonymous words )
location see.lit       "LIT"         ( decompilation -> literal )
location see.alu       "ALU"         ( decompilation -> ALU operation )
location see.call      "CAL"         ( decompilation -> Call )
location see.branch    "BRN"         ( decompilation -> Branch )
location see.0branch   "BRZ"         ( decompilation -> 0 Branch )
location see.immediate " immediate " ( used by "see", for immediate words )
location see.inline    " inline "    ( used by "see", for inline words )
location OK            " ok"         ( used by "prompt" )
location redefined     " redefined"  ( used by ":" when a word has been redefined )
location hi-string     "eFORTH V"    ( used by "hi" )

( ======================== System Variables ================= )
: 2drop drop drop ;       ( n n -- )
: 1+ 1 + ;                ( n -- n : increment a value  )
: negate invert 1+ ;      ( n -- n : negate a number )
: - negate + ;            ( n1 n2 -- n : subtract n1 from n2 )

: [-1] -1 ; hidden         ( -- -1 : space saving measure, push -1 onto stack )
: 0x8000 $8000 ; hidden    ( -- $8000 : space saving measure, push $8000 onto stack )
: drop-0 drop 0 ; hidden   ( n -- 0 )
: 2drop-1 2drop [-1] ; hidden ( n n -- -1 )
: dup-@ dup @ ; hidden     ( a -- a u )
: over- over - ; hidden    ( u1 u2 -- u1 u2 u2-u1 )
: base@ base @ ; hidden    ( -- u )
: base! base ! ; hidden    ( u -- )
: here cp @ ;              ( -- a )
: cp! cp ! ; hidden        ( u -- )
: state@ state @ ; hidden  ( -- f )
: command? state@ 0= ; hidden ( -- f )
: swap! swap ! ; hidden    ( a u -- )
: cell- cell - ;           ( a -- a : adjust address to previous cell )
: cell+ cell + ;           ( a -- a : move address forward to next cell )
: cells 1 lshift ;         ( n -- n : convert number of cells to number to increment address by )
: chars 1 rshift ;         ( n -- n : convert bytes to number of cells it occupies )
: ?dup dup if dup exit then ;   ( n -- 0 | n n : duplicate value if it is not zero )
: >  swap < ;              ( n1 n2 -- f : signed greater than, n1 > n2 )
: u> swap u< ;             ( u1 u2 -- f : unsigned greater than, u1 > u2 )
: u>= u< invert ;          ( u1 u2 -- f : )
: <> = invert ;            ( n n -- f : not equal )
: 0<> 0= invert ;          ( n n -- f : not equal  to zero )
: 0> 0 > ;                 ( n -- f : greater than zero? )
: 0< 0 < ;                 ( n -- f : less than zero? )
: 2dup over over ;         ( n1 n2 -- n1 n2 n1 n2 )
: tuck swap over ;         ( n1 n2 -- n2 n1 n2 )
: +! tuck @ + swap! ;     ( n a -- : increment value at address by 'n' )
: 1+!  1 swap +! ;         ( a -- : increment value at address by 1 )
: 1-! [-1] swap +! ; hidden  ( a -- : decrement value at address by 1 )
: execute >r ;             ( cfa -- : execute a function )
: c@ dup ( -2 and ) @ swap 1 and if 8 rshift exit else $ff and exit then ; ( b -- c )
: c!                       ( c b -- )
	swap $ff and dup 8 lshift or swap
	swap over dup ( -2 and ) @ swap 1 and 0 = $ff xor
	>r over xor r> and xor swap ( -2 and ) ! ;
: c, here c! cp 1+! ;    ( c -- : store 'c' at next available location in the dictionary )
: 2! ( d a -- ) tuck ! cell+ ! ;          ( n n a -- )
: 2@ ( a -- d ) dup cell+ @ swap @ ;      ( a -- n n )
: source #tib 2@ ;                        ( -- a u )
: source-id _id @ ;                       ( -- 0 | -1 )
: pad here pad-length + ;                 ( -- a )
: @execute @ ?dup if >r then ; hidden     ( cfa -- )
: bl =bl ;                                ( -- c )
: within over- >r - r> u< ;              ( u lo hi -- f )
: dnegate invert >r invert 1 um+ r> + ;   ( d -- d )
: abs dup 0< if negate exit then ;        ( n -- u )
: count  dup 1+ swap c@ ;                 ( cs -- b u )
: rot >r swap r> swap ;                   ( n1 n2 n3 -- n2 n3 n1 )
: -rot swap >r swap r> ;                  ( n1 n2 n3 -- n3 n1 n2 )
\ : 2>r r> -rot >r >r >r ; hidden           ( u1 u2 --, R: -- u1 u2 )
\ : 2r> r> r> r> rot >r ; hidden            ( -- u1 u2, R: u1 u2 -- )
: doNext r> r> ?dup if 1- >r @ >r exit then cell+ >r ; hidden
: min 2dup < if drop exit else nip exit then ; ( n n -- n )
: max 2dup > if drop exit else nip exit then ; ( n n -- n )
: >char $7f and dup 127 =bl within if drop [char] _ then ; hidden ( c -- c )
: tib #tib cell+ @ ; hidden               ( -- a )
\ : echo _echo @execute ; hidden            ( c -- )
: key _key @execute ;                     ( -- c )
: allot cp +! ;                           ( n -- )
: /string over min rot over + -rot - ;    ( b u1 u2 -- b u : advance a string u2 characters )
: +string 1 /string ; hidden
: address $3fff and ; hidden              ( a -- a : mask off address bits )
: last context @ @ address ;              ( -- pwd )
: emit _emit @execute ;                   ( c -- : write out a char )
: toggle over @ xor swap! ; hidden       ( a u -- : xor value at addr with u )
: cr =cr emit =lf emit ;                  ( -- )
: space =bl emit ;                        ( -- )
: depth sp@ sp0 - chars ; hidden
: vrelative cells sp@ swap - ; hidden
: pick  vrelative @ ;                     ( vn...v0 u -- vn...v0 vu )
: typist >r begin dup while swap count r@ if >char then emit swap 1- repeat rdrop 2drop ; hidden ( b u f -- : print a string )
: type 0 typist ;
: $type [-1] typist ; hidden
: print count type ; hidden               ( b -- )
: decimal? 48 58 within ; hidden            ( c -- f : decimal char? )
: lowercase? [char] a [char] { within ; hidden  ( c -- f : is character lower case? )
: uppercase? [char] A [char] [ within ; hidden  ( c -- f : is character upper case? )
: >lower dup uppercase? if =bl xor exit then ; hidden ( c -- c : convert to lower case )
: nchars swap 0 max for aft dup emit then next drop ; hidden ( +n c -- : emit c n times  )
: spaces =bl nchars ;                     ( +n -- )
: cmove for aft >r dup c@ r@ c! 1+ r> 1+ then next 2drop ; ( b b u -- )
: fill swap for swap aft 2dup c! 1+ then next 2drop ; ( b u c -- )
: aligned dup 1 and if 1+ exit then ;          ( b -- a )
: align here aligned cp! ;               ( -- )

: catch
	sp@ >r
	handler @ >r
	rp@ handler !
	execute
	r> handler !
	r> drop-0 ;

: throw
	?dup if
		handler @ rp!
		r> handler !
		r> swap >r
		sp! drop r>
	then ;

: -throw negate throw ; hidden ( space saving measure )

: ?ndepth depth 1- u> if 4 -throw exit then ; hidden
: 1depth 1 ?ndepth ; hidden

\ : um/mod ( ud u -- ur uq )
\ 	?dup 0= if 10 -throw exit then
\ 	2dup u<
\ 	if negate 15
\ 		for >r dup um+ >r >r dup um+ r> + dup
\ 			r> r@ swap >r um+ r> or
\ 			if >r drop 1+ r> else drop then r>
\ 		next
\ 		drop swap exit
\ 	then drop 2drop-1 dup ;

\ : m/mod ( d n -- r q ) \ floored division
\ 	dup 0< dup >r
\ 	if
\ 		negate >r dnegate r>
\ 	then
\ 	>r dup 0< if r@ + then r> um/mod r>
\ 	if swap negate swap exit then ;

0!: 10 -throw
.set error 0!
: /mod over 0< swap m/mod ; ( n n -- r q )
: mod  /mod drop ;           ( n n -- r )
: /    /mod nip ;            ( n n -- q )
: decimal 10 base! ;                       ( -- )
: hex     16 base! ;                       ( -- )
: radix base@ dup 2 - 34 u> if hex 40 -throw exit then ; hidden
: digit  9 over < 7 and + 48 + ; hidden      ( u -- c )
: extract  0 swap um/mod swap ; hidden       ( n base -- n c )
: ?hold hld @ here u< if 17 -throw exit then ; hidden ( -- )
: hold  hld @ 1- dup hld ! ?hold c! ;        ( c -- )
\ : holds begin dup while 1- 2dup + c@ hold repeat 2drop ;
: sign  0< if [char] - hold exit then ;           ( n -- )
: #>  drop hld @ pad over- ;                ( w -- b u )
: #  1depth radix extract digit hold ;       ( u -- u )
: #s begin # dup while repeat ;              ( u -- 0 )
: <#  pad hld ! ;                            ( -- )
: str dup >r abs <# #s r> sign #> ;          ( n -- b u : convert a signed integer to a numeric string )
: adjust over- spaces type ; hidden ( b n n -- ) 
:  .r >r str r> adjust ;       ( n n : print n, right justified by +n )
: (u.) <# #s #> ; hidden
: u.r >r (u.) r> adjust ;    ( u +n -- : print u right justified by +n)
: u.  (u.) space type ;                  ( u -- : print unsigned number )
:  .  radix 10 xor if u. exit then str space type ; ( n -- print space, signed number )
: ? @ . ;                                    ( a -- : display the contents in a memory cell )
: .base base@ dup decimal base! ; ( -- )

: pack$ ( b u a -- a ) \ null fill
	aligned dup >r over
	dup cell negate and ( align down )
	- over +  0 swap!  2dup c!  1+ swap cmove  r> ; hidden

\ : ^h ( bot eot cur c -- bot eot cur )
\ 	>r over r@ < dup
\ 	if
\ 		=bs dup echo =bl echo echo
\ 	then r> + ; hidden

: tap ( dup echo ) over c! 1+ ; hidden ( bot eot cur c -- bot eot cur )

\ : ktap ( bot eot cur c -- bot eot cur )
\ 	dup =lf ( <-- was =cr ) xor
\ 	if =bs xor
\ 		if =bl tap else ^h then
\ 		exit
\ 	then drop nip dup ; hidden

: accept ( b u -- b u )
	over + over
	begin
		2dup xor
	while
		key dup =lf xor if tap else drop nip dup then
		( key  dup =bl - 95 u<
		if tap else _tap @execute then )
	repeat drop over- ;

: expect ( b u -- ) _expect @execute span ! drop ;
: query tib tib-length _expect @execute #tib !  drop-0 >in ! ; ( -- )

: =string ( a1 u2 a1 u2 -- f : string equality )
	>r swap r> ( a1 a2 u1 u2 )
	over xor if 2drop drop-0 exit then
	for ( a1 a2 )
		aft
			count >r swap count r> xor
			if rdrop drop drop-0 exit then
		then
	next 2drop-1 ;

: nfa address cell+ ; hidden ( pwd -- nfa : move to name field address)
: cfa nfa dup count nip + cell+ $fffe and ; hidden ( pwd -- cfa : move to code field address )
: .id nfa print ; hidden ( pwd -- : print out a word )
: logical 0= 0= ; hidden ( n -- f )
: immediate? @ $4000 and logical ; hidden ( pwd -- f : is immediate? )
: inline?    @ 0x8000 and logical ; hidden ( pwd -- f : is inline? )

\ @todo make a better version of 'search' that returns the PWD as well as the
\ previous PWD, this should make implementing 'see' easier, as well as 'hide' 

: search ( a a -- pwd 1 | pwd -1 | a 0 : find a word in a vocabulary )
	swap >r
	begin
		dup
	while
		dup nfa count r@ count =string
		if ( found! )
			dup immediate? if 1 else [-1] then
			rdrop exit
		then
		@ address
	repeat
	drop r> 0 ; hidden

: find ( a -- pwd 1 | pwd -1 | a 0 : find a word in the dictionary )
	>r
	context
	begin
		dup-@
	while
		dup-@ @ r@ swap search ?dup if rot rdrop drop exit else drop then
		cell+
	repeat drop r> 0 ;

: numeric? ( char -- n|-1 : convert character in 0-9 a-z range to number )
	>lower
	dup lowercase? if 87 - exit then ( 97 = 'a', +10 as 'a' == 10 )
	dup decimal?   if 48 - exit then ( 48 = '0' )
	drop [-1] ; hidden

: digit? >lower numeric? base@ u< ; hidden ( c -- f : is char a digit given base )

: do-number ( n b u -- n b u : convert string )
	begin
		( get next character )
		2dup >r >r drop c@ dup digit? ( n char bool, R: b u )
		if   ( n char )
			swap base@ * swap numeric? + ( accumulate number )
		else ( n char )
			drop
			r> r> ( restore string )
			exit
		then
		r> r> ( restore string )
		+string dup 0= ( advance string and test for end )
	until ; hidden

: negative? ( b u -- f )
	over c@ $2D = if +string [-1] else 0 then ; hidden

: base? ( b u -- )
	over c@ $24 = ( $hex )
	if 
		+string hex 
	else ( #decimal )
		over c@ [char] # = if +string decimal then 
	then ; hidden

: >number ( n b u -- n b u : convert string )
	radix >r
	negative? >r
	base?
	do-number
	r> if rot negate -rot then
	r> base! ; hidden

: number? 0 -rot >number nip 0= ; ( b u -- n f : is number? )

: -trailing ( b u -- b u : remove trailing spaces )
	for
		aft =bl over r@ + c@ <
			if r> 1+ exit then
		then
	next 0 ; hidden

: lookfor ( b u c -- b u : skip until _test succeeds )
	>r
	begin
		dup
	while
		over c@ r@ - r@ =bl = _test @execute if rdrop exit then
		+string
	repeat rdrop ; hidden

: skipper if 0> exit else 0<> exit then ; hidden    ( n f -- f )
: scanner skipper invert ; hidden         ( n f -- f )
: skip ' skipper _test ! lookfor ; hidden ( b u c -- u c )
: scan ' scanner _test ! lookfor ; hidden ( b u c -- u c )

: parser ( b u c -- b u delta )
	>r over r> swap >r >r
	r@ skip 2dup
	r> scan swap r> - >r - r> 1+ ; hidden

: parse >r tib >in @ + #tib @ >in @ - r> parser >in +! -trailing 0 max ; ( c -- b u ; <string> )
: ) ; immediate
: "(" 41 parse 2drop ; immediate
: .( 41 parse type ;
: "\" #tib @ >in ! ; immediate
: ?length dup word-length u> if 19 -throw exit then ; hidden
: word 1depth parse ?length here pack$ ;          ( c -- a ; <string> )
: token =bl word ; hidden
: char token count drop c@ ;               ( -- c; <string> )
: .s ( -- ) cr depth for aft r@ pick . then next .s-string print ;
: unused $4000 here - ; hidden
: .free unused u. ; hidden
: preset ( tib ) tib-start #tib cell+ ! 0 >in ! 0 _id ! ; hidden
: ] [-1] state ! ;
: [  0 state ! ; immediate

: ?error ( n -- : perform actions on error )
	?dup if
		[char] ? emit ( print '?' )
		. cr          ( print error number )
		sp0 sp!       ( empty stack )
		preset        ( reset I/O streams )
		[             ( back into interpret mode )
		exit
	then ; hidden

: ?dictionary dup $3f00 u> if 8 -throw exit then ; hidden
: , here dup cell+ ?dictionary cp! ! ; ( u -- )
: doLit 0x8000 or , ; hidden
: ?compile command? if 14 -throw exit then ; hidden ( fail if not compiling )
: literal ( n -- : write a literal into the dictionary )
	?compile
	dup 0x8000 and ( n > $7fff ? )
	if
		invert doLit =invert , exit ( store inversion of n the invert it )
	else
		doLit exit ( turn into literal, write into dictionary )
	then ; immediate

: make-callable chars $4000 or ; hidden ( cfa -- instruction )
: compile, make-callable , ;         ( cfa -- : compile a code field address )
: $compile dup inline? if cfa @ , exit else cfa compile, exit then ; hidden ( pwd -- )

: interpret ( ??? a -- ??? : The command/compiler loop )
	find ?dup if
		state@
		if
			0> if \ immediate
				cfa execute exit
			else
				$compile exit
			then
		else
			drop cfa execute exit
		then
	else \ not a word
		dup count number? if
			nip
			state@ if literal exit then
		else
			drop space print 13 -throw exit
		then
	then ; hidden

: bye 0 (bye) ;
: "immediate" last $4000 toggle ;
: .ok command? if OK print space then cr ; hidden
: ?depth sp@ sp0 u< if 4 -throw exit then ; hidden
: eval begin token dup count nip while interpret ?depth repeat drop _prompt @execute ; hidden
: quit preset [ begin query ' eval catch ?error again ;

: evaluate ( a u -- )
	_prompt @ >r  0 _prompt !
	_id     @ >r [-1] _id !
	>in     @ >r  0 >in !
	source >r >r
	#tib 2!
	' eval catch
	r> r> #tib 2!
	r> >in !
	r> _id !
	r> _prompt !
	throw ;

: random ( -- u : 16-bit xorshift PRNG )
	seed @ ?dup 0= if 7 seed ! random exit then
	dup 13 lshift xor
	dup  9 rshift xor
	dup  7 lshift xor
	dup seed ! ;

: 5u.r 5 u.r ; hidden
: dm+ chars for aft dup-@ space 5u.r cell+ then next ; hidden ( a u -- a )
: colon 58 emit ; hidden ( -- )

: dump ( a u -- )
	4 rshift ( <-- equivalent to "dump-width /" )
	for
		aft
			cr dump-width 2dup
			over 5u.r colon space
			dm+ -rot
			2 spaces $type
		then
	next drop ;

\ : CSI $1b emit [char] [ emit ; hidden
\ : 10u. base@ >r decimal (u.) type r> base! ; hidden ( u -- )
\ : ansi swap CSI 10u. emit ; ( n c -- )
\ : at-xy CSI 10u. $3b emit 10u. [char] H emit ; ( x y -- )
\ : page 2 [char] J ansi 1 1 at-xy ; ( -- )
\ : sgr [char] m ansi ; ( -- )

: d. base@ >r decimal .  r> base! ;
: h. base@ >r hex     u. r> base! ;

( ==================== Advanced I/O Control ========================== )

\ : pace 11 emit ; hidden
: xio  ' accept _expect ! ( _tap ! ) ( _echo ! ) _prompt ! ; hidden
\ : file ' pace ' "drop" ' ktap xio ;
: hand ' .ok  ( ' "drop" <-- was emit )  ( ' ktap ) xio ; hidden
: console ' "rx?" _key ! ' "tx!" _emit ! hand ; hidden
: io! console preset ; ( -- : initialize I/O )

( ==================== Advanced I/O Control ========================== )

( ==================== Control Structures ============================ )

: !csp sp@ csp ! ; hidden
: ?csp sp@ csp @ xor if 22 -throw exit then ; hidden
: +csp    1 cells csp +! ; hidden
: -csp [-1] cells csp +! ; hidden
: ?unique dup last search if drop redefined print cr exit else drop exit then ; hidden ( a -- a )
: ?nul count 0= if 16 -throw exit then 1- ; hidden ( b -- : check for zero length strings )
: find-cfa token find if cfa exit else 13 -throw exit then ; hidden
: "'" find-cfa state@ if literal exit then ; immediate
: [compile] ?compile find-cfa compile, ; immediate ( -- ; <string> )
: compile  r> dup-@ , cell+ >r ; ( -- : Compile next compiled word NB. Works for words, instructions, and numbers below $8000 )
: "[char]" ?compile char literal ; immediate ( --, <string> : )
: ?quit command? if 56 -throw exit then ; hidden
: ";" ?quit ( ?compile ) +csp ?csp context @ ! =exit ,  [ ; immediate
: ":" align !csp here dup last-def ! last ,  token ?nul ?unique count + aligned cp! ] ;
: jumpz, chars $2000 or , ; hidden
: jump, chars ( $0000 or ) , ; hidden
: "begin" ?compile here -csp ; immediate
: "until" ?compile jumpz, +csp ; immediate
: "again" ?compile jump, +csp ; immediate
: "if" ?compile here 0 jumpz, -csp ; immediate
: doThen  here chars over @ or swap! ; hidden
: "then" ?compile doThen +csp ; immediate
: "else" ?compile here 0 jump, swap doThen ; immediate
: "while" ?compile call "if" ; immediate
: "repeat" ?compile swap call "again" call "then" ; immediate
: recurse ?compile last-def @ cfa compile, ; immediate
: tail ?compile last-def @ cfa jump, ; immediate
: create call ":" compile doVar context @ ! [ ;
: doDoes r> chars here chars last-def @ cfa dup cell+ doLit ! , ; hidden
: does> ?compile compile doDoes nop ; immediate
: "variable" create 0 , ;
: ":noname" here ] !csp ;
: "for" ?compile =>r , here -csp ; immediate
: "next" ?compile compile doNext , +csp ; immediate
: "aft" ?compile drop here 0 jump, call "begin" swap ; immediate
: doer create =exit last-def @ cfa ! =exit ,  ;
: make
	find-cfa find-cfa make-callable
	state@
	if
		literal literal compile ! exit
	else
		swap! exit
	then ; immediate

: "constant" create ' doConst make-callable here cell- ! , ;

\ : [leave] rdrop rdrop rdrop ; hidden
\ : leave ?compile compile [leave] ; immediate
\ : [do] r> dup >r swap rot >r >r cell+ >r ; hidden
\ : do ?compile compile [do] 0 , here ; immediate
\ : [loop]
\     r> r> 1+ r> 2dup <> if >r >r @ >r exit then
\     >r 1- >r cell+ >r ; hidden
\ : [unloop] r> rdrop rdrop rdrop >r ; hidden
\ : loop compile [loop] dup , compile [unloop] cell- here chars swap! ; immediate
\ : [i] r> r> tuck >r >r ; hidden
\ : i ?compile compile [i] ; immediate
\ : [?do]
\    2dup <> if r> dup >r swap rot >r >r cell+ >r exit then 2drop exit ; hidden
\ : ?do  ?compile compile [?do] 0 , here ; immediate


\ : back here cell- @ ; hidden ( a -- : get previous cell )
\ : call? back $e000 and $4000 = ; hidden ( -- f : is call )
\ : merge? back dup $e000 and $6000 = swap $1c and 0= and ; hidden ( -- f : safe to merge exit )
\ : redo here cell- ! ; hidden
\ : merge back $1c or redo ; hidden
\ : tail-call back $1fff and redo ; hidden ( -- : turn previously compiled call into tail call )
\ : compile-exit call? if tail-call else merge? if merge else =exit , then then ; hidden
\ : compile-exit call? if tail-call else merge? if merge then then =exit , ; hidden
\ : "exit" compile-exit ; immediate
\ : "exit" =exit , ; immediate

( ==================== Control Structures ============================ )

( ==================== Strings ======================================= )

: do$ r> r@ r> count + aligned >r swap >r ; hidden ( -- a )
: $"| do$ nop ; hidden                             ( -- a : do string NB. nop needed to fool optimizer )
: ."| do$ print ; hidden                           ( -- : print string )
: $,' 34 word count + aligned cp! ; hidden         ( -- )
: $"  ?compile compile $"| $,' ; immediate         ( -- ; <string> )
: ."  ?compile compile ."| $,' ; immediate         ( -- ; <string> )
\ : abort 0 rp! quit ;                             ( --, R: ??? --- ??? : Abort! )
\ : abort" ?compile ." compile abort ; immediate

( ==================== Strings ======================================= )

( ==================== Block Word Set ================================ )

: update [-1] block-dirty ! ;          ( -- )
: +block blk @ + ;                     ( -- )
: save ( [-1] ) here (save) throw ;
: flush block-dirty @ if [-1] (save) throw exit then ;

: block ( k -- a )
	1depth
	dup 63 u> if 35 -throw exit then
	dup blk !
	10 lshift ( b/buf * ) ;

: c/l* ( c/l * ) 6 lshift ; hidden
: c/l/ ( c/l / ) 6 rshift ; hidden
: line swap block swap c/l* + c/l ; hidden ( k u -- a u )
: loadline line evaluate ; hidden ( k u -- )
: load 0 l/b 1- for 2dup >r >r loadline r> r> 1+ next 2drop ;
: pipe 124 emit ; hidden
\ : .line line -trailing $type ; hidden
: .border 3 spaces c/l 45 nchars cr exit ; hidden
: #line dup 2 u.r exit ; hidden ( u -- u : print line number )
: thru over- for dup load 1+ next drop ; ( k1 k2 -- )
: blank =bl fill ;
\ : message l/b extract .line cr ; ( u -- )
: list
	dup block drop
	cr
	.border
	0 begin
		dup l/b <
	while
		2dup #line pipe line $type pipe cr 1+
	repeat .border 2drop ;

\ : index ( k1 k2 -- : show titles for block k1 to k2 )
\	over- cr
\	for
\		dup 5u.r space pipe space dup  0 .line cr 1+
\	next drop ;

( ==================== Block Word Set ================================ )

( ==================== Booting ======================================= )

: cold 16 block b/buf 0 fill sp0 sp! io! forth ; 
: hi hex cr hi-string print ver 0 u.r cr here . .free cr [ ;
: normal-running hi quit ; hidden
: boot cold _boot @execute bye ; hidden
: boot! _boot ! ; ( xt -- )

( ==================== Booting ======================================= )

( ==================== See =========================================== )

( @warning This disassembler is experimental, and not liable to work )

: bcount@ bcount @ ; hidden
: bcounter! bcount@ if drop exit else chars over swap -  bcount ! exit then ; hidden ( u a -- u )
: -bcount   bcount@ if bcount 1-! exit then ; hidden ( -- )
: abits $1fff and ; hidden

: validate ( cfa pwd -- nfa | 0 )
	tuck cfa <> if drop-0 exit else nfa exit then ; hidden

( @todo Do this for every vocabulary loaded )
: name ( cfa -- nfa )
	abits cells >r
	last
	begin
		dup
	while
		address dup r@ swap dup-@ address swap within ( simplify? )
		if @ address r> swap validate exit then
		address @
	repeat rdrop ; hidden

: .name name ?dup 0= if see.unknown then print ; hidden
: mask-off 2dup and = ; hidden ( u u -- u f )

i.end2t: cells
i.end:   5u.r rdrop exit
: i.print print abits ; hidden

: instruction ( decode instruction )
	over >r
	0x8000 mask-off if see.lit     print $7fff and      branch i.end then
	$6000  mask-off if see.alu     i.print              branch i.end then
	$4000  mask-off if see.call    i.print dup cells    5u.r rdrop space .name exit then
	$2000  mask-off if see.0branch i.print r@ bcounter! branch i.end2t then
	                   see.branch  i.print r@ bcounter! branch i.end2t ; hidden

: continue? ( u a -- f : determine whether to continue decompilation  )
	bcount@ if 2drop-1 exit then
	over $e000 and if drop else u> exit then
	dup ' doVar make-callable = if drop-0 exit then ( print next address ? )
	=exit and =exit <> ; hidden

: decompile ( a -- a : decompile a single instruction )
	dup 5u.r colon dup-@ 5u.r space
	dup-@ instruction
	dup-@ ' doNext make-callable = if cell+ dup ? then
	cr
	cell+ ; hidden

: decompiler ( a -- : decompile starting at address )
	0 bcount !
	dup chars >r
	begin dup-@ r@ continue? while decompile -bcount ( nuf? ) repeat decompile rdrop
	drop ; hidden

: see ( --, <string> : decompile a word )
	token find 0= if 13 -throw exit then
	cr colon space dup .id space
	dup inline?    if see.inline    print then
	dup immediate? if see.immediate print then
	cr
	cfa decompiler space 59 emit cr ;

\ : see
\ 	token find 0= if 13 -throw exit then
\ 	begin nuf? while
\ 		dup-@ dup $4000 and $4000
\ 		= if space .name else . then cell+
\ 	repeat drop ;

( ==================== See =========================================== )

( ==================== Vocabulary Words ============================== )

: find-empty-cell begin dup-@ while cell+ repeat ; hidden ( a -- a )

: get-order ( -- widn ... wid1 n : get the current search order )
	context
	find-empty-cell
	dup cell- swap
	context - chars dup >r 1- dup 0< if 50 -throw exit then
	for aft dup-@ swap cell- then next @ r> ;

: [set-order] ( widn ... wid1 n -- : set the current search order )
	dup [-1]  = if drop root-voc 1 [set-order] exit then
	dup #vocs > if 49 -throw exit then
	context swap for aft tuck ! cell+ then next 0 swap! ; hidden

: previous get-order swap drop 1- [set-order] ;
\ : also get-order over swap 1+ [set-order] ;
: only -1 [set-order] ;

: [forth] root-voc forth-wordlist 2 set-order ; hidden
: editor decimal editor-voc 1 [set-order] ;

: .words space begin dup while dup .id space @ address repeat drop cr ; hidden
: [words] get-order begin ?dup while swap dup cr u. colon @ .words 1- repeat ; hidden

.set _forth-wordlist $pwd

( ==================== Vocabulary Words ============================== )

( ==================== Block Editor ================================== )

.pwd 0
: [block] blk @ block ; hidden
: [check] dup b/buf c/l/ u>= if 24 -throw exit then ; hidden
: [line] [check] c/l* [block] + ; hidden
: b block drop ;
: l blk @ list ;
: n  1 +block b l ;
: p -1 +block b l ;
: d [line] c/l blank ;
: x [block] b/buf blank ;
: s update flush ;
: q forth flush ;
: e forth blk @ load editor ;
: ia c/l* + [block] + source drop >in @ +
  swap source nip >in @ - cmove call "\" ;
: i 0 swap ia ;
: u update ;
: w words ;
: yank pad c/l ; hidden
: c [line] yank >r swap r> cmove ;
: y [line] yank cmove ;
: ct swap y c ;
: ea [line] c/l evaluate ;
: sw 2dup y [line] swap [line] swap c/l cmove c ;
.set editor-voc $pwd

( ==================== Block Editor ================================== )

( ==================== Startup Code ================================== )

start:
.set entry start
	boot exit

.set cp  $pc

.set _do_colon      ":"
.set _do_semi_colon ";"
.set _forth         [forth]
.set _set-order     [set-order]
.set _words         [words]
.set _boot          normal-running
\ .set _message       message     ( execution vector of _message, used in ?error )
