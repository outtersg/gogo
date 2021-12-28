# run with:
# ./gogo.sh tests/simple.test.sh

slec() { sleep $1 ; echo "$2" ; }

Start tee: echo 1
Then slec 1 3
After tee echo 2
