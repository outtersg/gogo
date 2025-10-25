GOGO_SCRIPTS=..
. "$GOGO_SCRIPTS/gogo.sh"

f()
{
	sleep .$1
	read a
	echo "task $gogo_id waited $1 and read $a"
}

gogogo()
{
	Start f 3
	Start f 2
	Start f 1
}

{ echo a ; echo b ; echo c ; } | gogo_dance gogogo
