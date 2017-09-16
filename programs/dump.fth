0 ok!
hex
0 $3fff !
forth 
get-order 1+ $3fff swap set-order

here constant upto

: quote $22 emit ;
: start cr ." uw_t core[] = { " cr ;
: end   cr ." }; " cr ;
: ?cr $10 mod 0= if cr then ; 
: prefix ."  0x" ; 
: comma [char] , emit ;

: cdump 
	start
	0 here chars for
		aft dup @ prefix 0 u.r comma cell+ r@ ?cr then
	next 
	end ;

cdump
