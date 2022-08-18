# run with:
# ./gogo.sh tests/simple.test.sh

#- Test dynamic addition of children to the queue ------------------------------

handlerange()
{
	echo "Handling range $1 - $2"
	sleep 2
	echo "Finished range $1 - $2"
}

dynl()
{
	local id
	{
		# Subprocess that spits tasks we will have to launch.
		echo 1 1000
		sleep 2 # To be sure the following subtasks do not occur before the ending monitors.
		echo 1001 2000
		sleep 1
		echo 2001 2586
	} | while read from to
	do
		Start dync: handlerange $from $to
	done
}

# Launch in gogogo mode: it allows tasks to run as soon as they are declared, while "inline mode" waits for all level-0 tasks to have been scheduled before launching the first one.
gogogo()
{
	Start dynl: dynl
	sleep 1
After dync~ echo "After first dyn child" # We haven't wait for dynl, so all dyn children are not instanciated: dync~ only evaluates to the first one (or even no task, because the Then + Then to reach the first dync may be slower than the After we're in.
After dynl,dync~ echo "After all dyn children" # This one first waits for dynl to have completed, so dync~ has all children.
}
