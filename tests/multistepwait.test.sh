# run with:
# ./gogo.sh tests/simple.test.sh

#- Test dynamic addition of children to the queue ------------------------------

# Expected timings:
# 0.0 Start dynl, start dync0, start dyns0
# 0.5 Start monitors
# 0.8 Finish dync0, "after 1st dync"
# 1.0 Start dync1, start dyns1
# 1.2 Finish dyns0
# 1.6 Start dync2, start dyns2
# 1.8 Finish dync1
# 2.2 Finish dyns1
# 2.4 Finish dync2, "after all dync"
# 2.8 Finish dyns2

handlerange()
{
	echo "Handling range $1 - $2"
	sleep 0.8
	echo "Finished range $1 - $2"
}

slowrange()
{
	sleep 1.2
	echo "Slowly finished range $1 - $2"
}

dynl()
{
	local id
	{
		# Subprocess that spits tasks we will have to launch.
		echo 1 1000
		sleep 1 # To be sure the following subtasks do not occur (and get detected) before the ending monitors.
		echo 1001 2000
		sleep 0.6
		echo 2001 2586
	} | while read from to
	do
		Start dync: handlerange $from $to
		Start dyns: slowrange $from $to
	done
}

# Launch in gogogo mode: it allows tasks to run as soon as they are declared, while "inline mode" waits for all level-0 tasks to have been scheduled before launching the first one.
gogogo()
{
	Start dynl: dynl
	sleep 0.5
After dync~ echo "After first dyn child" # We haven't wait for dynl, so all dyn children are not instanciated: dync~ only evaluates to the first one (or even no task, because the Then + Then to reach the first dync may be slower than the After we're in.
	After dynl echo "After all dynl children" # dynl and all of its children.
	After dynl-/dync~ echo "After all dynl 'dync' children" # This one first waits for dynl itself to have completed, and then only, evaluates dync~ (so it knows the 3 of them); but it does not wait for dyns ones.
}
