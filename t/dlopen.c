#include "embed.h"
#include <stdio.h>
#include <dlfcn.h>

typedef embed_t *(*embed_new_t)(void);
typedef void (*embed_free_t)(embed_t *h);
typedef int (*embed_forth_t)(embed_t *h, FILE *in, FILE *out, char *block);
typedef int (*embed_load_t)(embed_t *h, const uint8_t *buffer, size_t length);

int main(void)
{
	fputs("dlopen eForth\n", stdout);
	void *libembed = dlopen("./libembed.so", RTLD_LAZY);
	if(!libembed)
		return -1;
	embed_new_t    new  = (embed_new_t)   dlsym(libembed, "embed_new");
	embed_free_t   del  = (embed_free_t)  dlsym(libembed, "embed_free");
	embed_forth_t  run  = (embed_forth_t) dlsym(libembed, "embed_forth");
	if(!new || !del || !run)
		return -2;
	embed_t *h = new();
	if(!h)
		return -1;
	int r = run(h, stdin, stdout, NULL);
	del(h);
	dlclose(libembed);
	return r;
}

