# run with:
# ./gogo.sh test.sh

late() { sleep 4 ; Start sleep 2 ; Then echo "Started 4 s after everybody, slept 2, but expected to appear" ; }

Start sleep 8
Then echo "Slept 8 (and nobody should have wait for me)"
Start sleep 5
Then w0: echo "Slept 5 (and expected I was waited for)"
for d in 2 3 1
do
	Start sleep $d
	Then w1: echo "Slept $d"
done
After "w0*,w1*" echo "Everyone finished (except the really long one)"
Start late # This one will want to emit new instruction long after the main script has stacked its order. Will they get caught and executed?
