#include "embed.h"

int main(void) {
	return embed_forth(embed_new(), stdin, stdout, NULL);
}
