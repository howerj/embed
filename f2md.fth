\ This is a highly specialized Forth program that creates a turn-key 
\ application, which when run, acts as a filter reading from standard input
\ and writing to standard output. It expects as its input a specially formatted
\ document, which is actually a well documented Forth program, which it then
\ turns into a markdown document.
\ 
\ Compilation:
\
\       ./embed -o f2md.blk f2md.fth
\
\ Usage:
\	./embed -i f2md.blk < embed.fth > embed.md
\

.( Compiling f2md.fth ) cr

only forth definitions
system +order
decimal

variable line
variable start-line
variable code-block
variable paragraph
10 constant nl
9 constant tab
create queue 4 c, 0 c, 0 c, 0 c, 0 c,
create nbye 4 c, nl c, char b c, char y c, char e , ( "\nbye" )

: .pipe [char] | emit ;
: .tab tab emit ;
: .line .tab line @ 5 u.r .pipe space ;
: start 1 line ! 1 start-line ! 0 code-block ! ;
: =line 1 start-line ! ;
: <>line 0 start-line ! ; \ 0 code-block ! ;
: encode 1 code-block ! ;
: code? code-block @ 0= 0= ;
: +line line 1+! ;
: nl? dup nl = ;
: tab? dup tab = ;
: .nl nl emit ;
: .nl? if .nl then ;
: slash? dup [char] \ = ;
: start? start-line @ 0= 0= ;
: aswap 2dup c@ >r c@  swap c!  r> swap c! ; ( b b -- )
: enqueue queue count 1- for aft dup dup 1+ aswap 1+ then next c! ;
\ : .queue queue count .tab .pipe type .pipe cr ;
: end? queue count nbye count compare 0= ;
: escape ( c -- )
	code? if emit exit then
	dup [char] _ = if [char] \ emit emit exit then 
\	dup [char] < = if drop ." &lt;" exit then 
\	dup [char] > = if drop ." &gt;" exit then 
	emit ;
: filter ( c -- ) 
	nl? if emit =line exit then
	start? if 
		slash? if 
			paragraph @ 0= .nl? 1 paragraph !
			drop key 
			nl?  if emit =line exit then 
			tab? if emit encode exit else drop then 
			<>line exit 
		then
		paragraph @ .nl? 0 paragraph !
		tab? if encode else <>line then
		.line emit +line exit
	then
	emit ;
: converter begin key dup enqueue end? if emit exit then filter again ;
: end .nl begin key emit again ;
: f2md start converter end bye ;

' f2md <boot> !

.( Compilation done ) cr

only forth definitions
.( Saving... ) cr
save
.( Application Saved ) cr
bye


