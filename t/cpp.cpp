#include "embed.h"
#include <stdio.h>
#include <iostream>
using namespace std;

int main(void) 
{
	cout << "C++ eForth" << endl;
	embed_t *h = embed_new();
	if(!h)
		embed_fatal("embed: allocate failed");
	return embed_forth(h, stdin, stdout, NULL);
}
