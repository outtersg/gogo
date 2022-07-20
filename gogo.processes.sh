# Copyright (c) 2020 Guillaume Outters
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

# Two triggers to us having to work:
# - A subprocess finishes
# - We've got input
# Both have a blocking way to detect changes (wait and read)
# To unify this, we will make everything pass through the 2nd one.
# @todo: is it the best way? The main loop has to be either read or wait. wait would require a subshell to abort to transform reads (from the pipe) to signals, and even then how would we wait for either this reader or a "real" subtask? With a read loop: does SIGALRM unblock read? Does a trapped signal unblock wait? Can we trap SIGCHLD?

# @todo while launching a process, redefine Then and After so that they transmit to the main loop (to affect global variables instead of just those in the subshell).
# @todo gogo must necessarily be around the chain's body (gogo cannot launch itself then let elements be added to the chain without control on the end), because it has to stop its main loop once all tasks are finished; if we just chain elements without telling when the last has been instanciated, it could decide to shut down too quickly (e.g.: Then true ; Then true could decide to finish after the first one, because it finishes before the second has launched, and at that time, as no other task runs, it can decide to quit. But we have to preserve some state, for example task IDs, so that subsequent ones know they can run: so we cannot instanciate two independent loops on demand).

#- Main ------------------------------------------------------------------------

gogo_run()
{
	local gigo=/tmp/temp.gogo.$$/gigo # Gogo In, Gogo Out
	GOGO_CHANNEL="$gigo"
	GOGO_IFS="`printf '\003'`"
	
#set -x
	gogo_ploop
	gogo_boot_script
	gogo_pool_loop
	gogo_gloop
}

# Prepare LOOP.
gogo_ploop()
{
	mkdir -p "`dirname "$gigo"`" && mkfifo "$gigo" || gogo_err "Unable to init fifo $gigo" || return 1
	trap gogo_dech SIGCHLD
}

# Garbage LOOP.
gogo_gloop()
{
	rm "$gigo"
}

#- Loop ------------------------------------------------------------------------

gogo_pool_loop()
{
	local dodo
	local gogo_children gogo_dead gogo_id=0
	while read dodo
	do
		gogo_log 9 "--- new instruction: $dodo"
		$dodo
# @todo Handle differently errors than successes.
# Comment s'assurer qu'un processus lancé en asynchrone a ajouté ce qu'il voulait dans la pile avant de rendre la main? A priori quand on le lance il faut lancer sa liste de course puis ajouter une instruction disant "c'est bon j'ai terminé et j'ai empilé tout ce que j'avais.
# Ceci pour implémenter les boucles for d'après le résultat d'une commande listant ce qu'il y a à faire.
# Comment détecter qu'il faut mourir faute de fils? Un wait global qui donne un ordre de mourir? Recevrait-il les SIGCHLD qui lui permettraient de détecter les morts une par une (gogo_dede: death detect)?
	done < "$gigo"
	gogo_log 9 "--- no more instructions, loop exited"
	wait
}

# DEath of a CHild.
gogo_dech()
{
	# @todo Are there any platforms where we need that?
	# Our problem is that writing throws SIGCHLD, which writes, which signals, and so on.
	#echo "gogo_dede" > "$GOGO_CHANNEL"
} 

# DEtect DEath.
gogo_dede()
{
	# @todo Have both ways of registering death: declarative (here we receive a task ID), or authoritative (see gogo_dede_by_pid()).
	#       Problem of declarative is that it relies on the child writing to our channel after having finished; so a crash will ruin it.
	#       Problem of authoritative is that can we rely on jobs being implemented similarly everywhere?
	gogo_log 9 "--- $1 finished"
	# @todo Call gogo_dede_by_pid from time to time (or on signal) to detect children that have crashed without notifying.
}

gogo_dede_by_pid()
{
	local child children
	# @todo Alternate ways of detecting death: with jobs, or plain old ps. For each solution, measure shell compatibility and reliance.
	for child in $gogo_children
	do
		if kill -0 "$child" 2> /dev/null
		then
			children="$children $child"
		else
			gogo_dead="$gogo_dead $child"
			gogo_log 9 "--- PID $child finished"
		fi
	done
	gogo_children="$children"
}

#- Tasks -----------------------------------------------------------------------

# To be called by the script.
gogo_push()
{
	IFS="$GOGO_IFS"
	# @todo In case of really special characters (LF), encode the command line.
	echo "gogosse" "$*" >> $GOGO_CHANNEL
	unset IFS
}

# Schedule Subtask Execution.
gogosse()
{
	IFS="$GOGO_IFS"
	gogo_tifs gogo_br $*
}

# Launch.
gogol()
{
	local gogoret=0
	"$@" || gogoret=$?
	# @todo Handle -e, to export resulting env variables.
	echo "gogo_dede $$ $gogoret" > "$GOGO_CHANNEL"
}

#- Utils -----------------------------------------------------------------------

# Please Announce Unread Lines
gogo_paul()
{
	true
}

# Temporary IFS
gogo_tifs()
{
	unset IFS
	"$@"
}
