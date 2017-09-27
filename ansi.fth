0 ok!
\ https://en.wikipedia.org/wiki/ANSI_escape_code

only forth
variable ansi-voc 0 ansi-voc !

get-order 1+ ansi-voc swap set-order


: CSI $1b emit [char] [ emit ; 
: 10u. base @ >r decimal <# #s #>  type r> base ! ; ( u -- )
: sequence swap CSI 10u. emit ; ( n c -- )
: sgr [char] m sequence ; ( -- )

0 constant black
1 constant red 
2 constant green
3 constant yellow
4 constant blue
5 constant magenta
6 constant cyan
7 constant white

: foreground $1e + sgr ;
: background $28 + sgr ;

get-order -rot swap rot set-order

: at-xy CSI 10u. $3b emit 10u. [char] H emit ; ( x y -- )
: page 2 [char] J sequence 1 1 at-xy ; ( -- )

only forth

