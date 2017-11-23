#!/bin/bash
# A program to find the most common bi-grams of Forth words
# 
# This script is based upon one from:
# <https://greg.blog/2013/01/26/unix-bi-grams-tri-grams-and-topic-modeling/>
#
# Generating tri-grams isn't that helpful, and the utility quickly
# diminishes the 'n' is in 'n-gram'.
set -eu;

INPUT=meta.blk
DATA=`tempfile`;

# Strip data
CLASS='[*\\a-zA-Z0-9_+=<>;:.?/,!^&()@{}#~"-]';
sed \
	-e 's/^variable.*$//' \
	-e 's/^constant.*$//' \
	-e 's/^location.*$//' \
	-e 's/hidden//g'\
	-e 's/immediate//g'\
	-e 's/\w\w*://' \
	-e 's/^[ \t]*//' \
	-e 's/^\..*$//' \
	-e "s/:[ \\t][ \\t]*${CLASS}${CLASS}*//" \
	-e 's/(.*)//g' \
	-e 's/\\.*//' \
	-e 's/\t/ /g'\
	"${INPUT}" | uniq | awk 'NF' > $DATA;

STOPWORDS=`tempfile`;

cat >> "${STOPWORDS}" <<STOP
alu
asm\[
\]asm
if
then
else
for
next
exit
a:
a;
:
;
h:
t:
t;
begin
while
repeat
again
until
literal
immediate
hidden
inline
STOP

# Generate bi-grams

TEMP1=`tempfile`;
TEMP2=`tempfile`;

cat "${DATA}" \
	| tr '[:upper:]' '[:lower:]' \
	| sed 's/|//' \
	| sed G \
	| tr ' ' '\n' \
	| grep -v -w -f "${STOPWORDS}"\
	> "${TEMP1}";

tail -n+2 "${TEMP1}" > "${TEMP2}";

paste -d '|' "${TEMP1}" "${TEMP2}" \
	| grep -v -e '^|' \
	| grep -v -e '|$' \
	| sort \
	| uniq -c \
	| sort -rn \
	| tr '|' ' ' \
	| column -t\
	| awk '{j=($1*2)-($1+2);if($1>=3){i+=j}; print $1,j,$2,$3}END{print "Compress: " i}'\
	| tr ' ' '\t';

rm "${DATA}";
rm "${STOPWORDS}";
rm "${TEMP1}";
rm "${TEMP2}";
