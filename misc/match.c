/* http://c-faq.com/lib/regex.html */
int match(char *pat, char *str)
{
	switch(*pat) {
	case '\0':  return !*str;
	case '*':   return match(pat+1, str) ||
				*str && match(pat, str+1);
	case '?':   return *str && match(pat+1, str+1);
	default:    return *pat == *str && match(pat+1, str+1);
	}
}
