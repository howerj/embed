/**@brief C++ Test program for embed library
 * @file cpp.cpp
 * @license MIT
 * @author Richard James Howe 
 *
 * See <https://github.com/howerj/embed> for more information. */

#include "embed.hpp"
#include "util.h"
#include <stdio.h>
#include <iostream>
using namespace std;

int main(void) {
	auto h = Embed();
	return h.run();
}

