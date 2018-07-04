/**@brief C++ Test program for embed library
 * @file cpp.cpp
 * @license MIT
 * @author Richard James Howe 
 *
 * See <https://github.com/howerj/embed> for more information. */

#include "embed.h"
#include <stdio.h>
#include <iostream>
using namespace std;

int main(void) 
{
	cout << "C++ Usage of embed library" << endl;
	embed_t *h = embed_new();
	if(!h)
		embed_fatal("embed: allocate failed");
	return embed_forth(h, stdin, stdout, NULL);
}

