/* NB. untested forth string pack/unpack routines */

#include <assert.h>
#include <string.h>

#define MIN(X, Y) ((X) > (Y) ? (Y) : (X))
#define PACK_SZ (256u)

typedef struct { 
	unsigned char s[PACK_SZ] 
} packed;

unsigned size(packed *p)
{
	assert(p);
	return p->s[0];
}

unsigned char *data(packed *p)
{
	return p->s + 1;
}

int pack(packed *p, const char *s)
{
	size_t l = 0;
	assert(p);
	assert(s);
	memset(p, 0, sizeof(*p));
	l = strlen(s);
	p->s[0] = MIN(l, PACK_SZ - 1);
	memmove(p->s + 1, s, p->s[0]);
	return l >= PACK_SZ ? -1 : 0;
}

int unpack(packed *p, char *s)
{
	assert(p);
	assert(s);
	memmove(s, p->s + 1, p->s[0]);
	s[p->s[0]] = '\0';
	return 0;
}
