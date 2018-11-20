only forth definitions
system +order
decimal
.( B2C: Binary To C Code filter ) cr
.( To generate the application: ) cr cr
.( 	./embed -i embed-1.blk -o b2c.blk b2c.fth ) cr cr
.( To Run: ) cr cr
.( 	./embed -i b2c.blk < embed-1.blk > core.gen.c ) cr cr
.( This program acts as a filter to convert a binary file into a C file ) cr
.( that contains that file. It used by the 'embed' Forth project to ) cr
.( convert a newly cross compiled image to a C file for inclusion in the ) cr
.( embed library. ) cr
cr

72 constant line
variable cnt
variable length

: nl 10 emit ;
: .header 
	." /* eForth image */" nl
	." #include <stdint.h>" nl
	." #include <stddef.h>" nl ;
: .var-start ." const uint8_t embed_default_block[] = {" nl ;
: .var-end nl ." };" nl ;
: comma [char] , ;
: >= < 0= ;
: nl? length @ line >= if 0 length ! nl then ;
: .v 0 <# comma hold #s #> dup length +! nl? type ;
: .tail ." const size_t embed_default_block_size = " cnt @ . ." ;" nl nl ;
: init 0 length ! 0 cnt ! ; 
: key? rx? drop dup -1 <> ;

: b2c
	init
	.header nl
	.var-start
	begin
		key? dup >r if .v cnt 1+! then r> 0=
	until nl
	.var-end nl
	.tail bye ;

' b2c <boot> !

only forth definitions
save
.( Program Compilation Complete ) cr
bye

