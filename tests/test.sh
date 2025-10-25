#!/bin/sh

fres=/tmp/temp.$$.gogo.test

for f in "$@"
do
	printf "=== %s:\\t" "$f"
	../gogo.sh "$f" > "$fres"
	[ $? -eq 0 ] || { echo "[31mcrashed[0m" ; continue ; }
	ftest="`echo "$f" | sed -e 's/\.test\.sh/.res/g'`"
	diff -q "$fres" "$ftest" || { echo "[31mfailed (unexpected result)[0m" ; diff -uw "$ftest" "$fres" ; continue ; }
	echo "[32mOK[0m"
	rm "$fres"
done
