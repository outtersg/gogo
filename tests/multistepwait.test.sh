# run with:
# ./gogo.sh tests/simple.test.sh

#- Test dynamic addition of children to the queue ------------------------------

dynl()
{
	local id
	{
		# Subprocess that spits tasks we will have to launch.
		echo 1 1000
		sleep 1
		echo 1001 2000
		sleep 1
		echo 2001 2586
	} | while read from to
	do
		Then dync: echo "Handling range $from - $to"
	done
}
Then dynl: dynl
After dync~ echo "After first dyn child" # We haven't wait for dynl, so all dyn children are not instanciated: dync~ only evaluates to the first one.
After dynl,dync~ echo "After all dyn children" # This one first waits for dynl to have completed, so dync~ has all children.
