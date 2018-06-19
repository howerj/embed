#include "embed.h"
#include <stdio.h>
#include <iostream>
using namespace std;

int main(void) 
{
	cout << "C++ eForth" << endl;
	embed_t *h = embed_new();
	if(embed_load_buffer(h, embed_default_block, embed_default_block_size) < 0) {
		cerr << "embed: load failed" << endl;
		return -1;
	}
	return embed_forth(h, stdin, stdout, NULL);
}
