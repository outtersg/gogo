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

### Name children and all

# All of those functions are to be run in the runner subshell.

# Global variables:
# (all "list" variables are space-separated)
# gogo_todo_xxx: list of task IDs with name "xxx" that are waiting to run, or running.
# gogo_done_xxx: list of task IDs with name "xxx" that finished running.
# gogo_last_xxx: ID of the last task declared with name xxx (or empty if it finished running).
# gogo_todo_ and gogo_last_ contain non-named as well as named tasks.
# gogo_prereq_id: all prerequisites of a task.
# gogo_waiters_id: who is waiting on task id? (if $gogo_prereq_2 = 1, then $gogo_waiters_1 = 2)
# gogo_names: all symbolic names ever used by a task.

# Birth Registry
gogo_br()
{
	# Get a task ID.
	
	gogo_id=`expr $gogo_id + 1`
	local id=$gogo_id ptid=0
	local name
	local prereq
	while [ $# -gt 0 ]
	do
		case "$1" in
			--after) prereq="$2" ; shift ;;
			--after-last) prereq=$gogo_last_ ;;
			--from) ptid=$2 ; shift ;;
			*:) name="`IFS=: ; echo $1`" ;;
			*) break ;;
		esac
		shift
	done
	
	case "$prereq" in *[,\;/]*) prereq="`echo "$prereq" | sed -e 's/,/ /g' -e 's#[/;]# ; #g'`" ;; esac
	
	# Store the task's command.
	
	IFS="$GOGO_IFS"
	eval gogo_comm_$id='"$*"'
	unset IFS
	# Prerequisites. We first try to resolve all symbolic one to "hard" ones (IDs).
	gogo_resolve_prereq $id $prereq
	eval gogo_prereq_$id='"$prereq"'
	
	gogo_last_=$id
	gogo_todo_="$gogo_todo_ $id"
	if [ -n "$name" ]
	then
		case " $gogo_names" in
			*" $name "*) true ;;
			*) gogo_names="$gogo_names$name "
		esac
		eval \
			gogo_last_$name=$id \
			gogo_todo_$name='"$gogo_todo_'$name $id'"'
	fi
	# gogo_last_$id is voluntarily similar to gogo_last_$name, so that we can address a task either by name or by ID.
	eval \
		gogo_children_$ptid=\"\${gogo_children_$ptid}$id \" \
		gogo_last_$id=$id \
		gogo_name_$id=$name
	gogo_log 9 "---   [$id] \"$name\" (depends on: $prereq)"
	
	# If all of our prereqs are resolved, launch immediately.
	case "$prereq" in
		"") gogoliath $id "$@" ;;
		# @todo Foreground tasks? But we cannot autodetect them (if A Then B After A C (A ; C & B), we have no way to know when launching B that it should go foreground _after_ having background-launched the yet-to-be-declared C. Primary use would be them to modify environment for subsequent tasks, so for that see -e (export).
	esac
}

# Remove a value from all parameters.
# The resulting list is in $output.
gogo_obliterate()
{
	local except="$1" ; shift
	output=""
	while true
	do
		case "$1" in "$except") shift ; output="$output$*" ; return ;; esac
		output="$output$1 "
		shift
	done
}

# NOTE: "after task 5 and of the children it created"
# We had two options here:
# 1. Have a pseudo-task whose *id* included an x (5x);
#    have all tasks requiring 5 having a dependency not to 5, but to 5x;
#    have 5x itself depend on 5 and all children that were created advertizing they were sons of 5.
#    Advantages: we could reuse the cascading mechanism as is
#    Disadvantage: overhead, particularly for simple tasks having no child.
# 2. Have a dedicated handling (another variable) to distinguish waiters waiting for "5" (5s) from those waiting for "5 and its children" (5).
# 3. Mix both (have a variable to store children; when 5 finishes, see if it has children: if yes, spit a pseudo-task and replace variables as if only 5s had finished).
# We chose 3. here (see "Only switch to the pseudo-task […]").

# Death Registry: unblock tasks that were waiting for us.
gogo_dr()
{
	local id=$1 waiter waiters name prereq
	gogo_log 9 "--- starting cleaning after death of $id"
	eval \
	"
		# If we have children, only close the task itself, not the whole family.
		case \"\$gogo_children_$id\" in
			?*)
				# Replace the task by its closing-pseudo-task (which represents the whole family: the task and its children);
				# This is a simplified version of gogo_br:
				_gogo_set_prereq_ids $id \$gogo_children_$id
				case \"\$gogo_prereq_$id\" in
					# Only switch to the pseudo-task if some children still run:
					[^\\ ]*)
						gogo_children_$id= # Not needed anymore: they are either finished, or pushed to \$gogo_prereq_$id.
						gogo_comm_$id=true
						# Now work on the task itself, not on its family group.
						id=\${id}_itself
						gogo_log 9 \"--- $id becomes \$id, $id now points to the pseudo-task that waits for all children of $1 (\$gogo_prereq_$id) to complete\"
						;;
				esac
				;;
		esac
	"
	eval \
	"
		waiters=\"\$gogo_waiters_$id\"
		name=\"\$gogo_name_$id\"
	"
	eval \
	"
		if [ -n \"\$name\" ]
		then
			case \"\$gogo_last_$name\" in $id) unset gogo_last_$name ;; esac
			gogo_done_$name=\"\$gogo_done_$name$id \"
			case \" \$gogo_todo_$name \" in *\" $id \"*) gogo_obliterate $id \$gogo_todo_$name ; gogo_todo_$name=\"\$output\" ;; esac
		fi
	"
	case "$gogo_last_" in $id) unset gogo_last_ ;; esac
	case " $gogo_todo_ " in *" $id "*) gogo_obliterate $id $gogo_todo_ ; gogo_todo_="$output" ;; esac
	
	gogo_log 9 "--- looking for waiters of $id ($waiters) that become launchable"
	
	for waiter in $waiters
	do
		# Are we its last dependency?
		eval 'prereq="$gogo_prereq_'$waiter\"
		gogo_resolve_prereq $waiter $prereq
		case "$prereq" in "") gogoliath $waiter ;; esac
	done
	
	gogo_log 9 "--- finished handling death of $id"
}

_gogo_set_prereq_ids()
{
	local id="$1" pr ; shift
	prs=
	for pr in "$@"
	do
		case " $gogo_todo_ " in
			*" $pr "*)
				prs="$prs$pr "
				_gogo_will_wait $pr $id
				;;
		esac
	done
	eval gogo_prereq_$id=\"\$prs\"
}

# Resolves symbolic prerequisites in $@; result is stored in $prereq.
# (prereqs found already finished are eaten immediately, doing a bit of gogo_ack_prereq())
# Symbols are evaluated at the time they are passed, so "task,other" means "the latest tasks having names 'task' and 'other' instantiated before we asked to launch the current one".
# Each packet of symbols is resolved simultaneously (items in a packet are separated by ","; packets are separated by "/" or ";"). Thus:
#   "task;other~" means "the last 'task' task, and every 'other' that may have been instantiated while 'task' ran" (so wait 'task' to finish before evaluating 'other~')
#   "task,other~" is one packet, so both are evaluated, and the wildcard other~ will only get the 'other's that were programmed at the time we evaluated.
# N.B.: as "task" means "task and all of its chidren", "task;other~" is of no use if 'other' is emitted by 'task' (a simple "task" will do), only if task is a watchdog for an unrelated emitter of 'other's.
gogo_resolve_prereq()
{
	local pr id="$1" ; shift # _gogo_resolve_pr() relies on $id being defined.
	prereq=
	
	while [ $# -gt 0 ]
	do
		pr="$1"
		case "$pr" in
			# On ; return, letting aliases to be resolved later (once all prereqs before the ; are finished).
			\;)
				# But if every prereq preceding the ; has already finished, ignore the ;
				case "$prereq" in "") shift ; continue ;; esac
				prereq="$prereq $*"
				return
				;;
			# "The whole family" (every task ever launched with this name):
			*~)
						IFS='~'
						gogo_tifs _gogo_resolve_pr $pr
				;;
			# Wildcards. Lookup $gogo_names to find matching, already launched, tasks.
			*\**)
				local name prs=
				eval 'for name in $gogo_names ; do case "$name" in '"$pr"') _gogo_resolve_pr "$name" ; case "$pr" in ?*) prs="$prs$pr " ;; esac ;; esac ; done' >&2
				pr="$prs"
				;;
			# [0-9]*: A numeric ID (already resolved), we just have to check it has finished:
			# @duplicate _gogo_set_prereq_ids()
			[0-9]*)
				case " $gogo_todo_ " in
					*" $pr "*) _gogo_will_wait $pr $id ;;
					*) pr= ;;
				esac
				;;
			# [^0-9]*: A symbolic (not already resolved) but single (no wildcard) name;
			*)
				_gogo_resolve_pr -1 "$pr"
				;;
		esac
		case "$pr" in
			?*) prereq="$prereq$pr " ;;
		esac
		shift
	done
	
	# Already run prerequisites are not needed anymore: remove them.
}

# Resolve a single name, if found put result in $pr.
# If 
_gogo_resolve_pr()
{
	local suffix s=todo # Which set do we select from?
	case "$1" in -1) shift ; s=last ;; esac
	case "$1" in *\!|*-) suffix=_itself ; set -- "`echo "$1" | sed -e 's/.$//'`" ;; esac
	eval 'pr="$gogo_'${s}_$1\"
	case "$pr" in
		?*)
			# Still running? Mark us as waiting for it, to speed up our resolution
			# À FAIRE: sur waiters_, ne pas réinvoquer tout resolve, mais virer promptement juste la valeur de la liste. Sauf que derrière si on est le dernier (liste résultante vide), il faudra déclencher gogol => fonction haut niveau à appeler soit de resolve_prereq, soit de dede cuort-circuitant
			gogo_waiters_= # Si pas déjà référencé comme attendant!
			# @todo Do modify gogo_waiters only if "$pr" was alphabetical. Else it should already be in it.
			local idpr
			case "$suffix" in
				?*)
					local pr2
					for idpr in $pr
					do
						pr2="$pr2$idpr$suffix "
					done
					pr="$pr2"
					;;
			esac
			for idpr in $pr
			do
				case "$idpr" in [0-9]*) _gogo_will_wait $idpr $id ;; esac
			done
			return
			;;
	esac
	
	# If not found, are there done tasks with this name?
	
	eval 'local done="$gogo_done_'$1'"'
	case "$done" in
		"") gogo_warn "$name depends on $1, but no tasks has ever been launched with this name" ;;
		# @todo (in debug mode only) write that $id depended on it / them.
	esac
	
	# Nonetheless return an empty dependency.
}

_gogo_will_wait()
{
	eval "case \" \$gogo_waiters_$1 \" in *\" $2 \"*) return ;; esac ; gogo_waiters_$1=\"\${gogo_waiters_$1}$2 \""
}

# Removes already finished prerequisites from $pr.
gogo_ack_prereq()
{
	local pr
	
	prereq=
	
	# If first prereq is symbolic, resolve it.
	
	while [ -z "$prereq" ]
	do
		case "$1" in
			[^0-9]*)
# À FAIRE: définir $id histoire que gogo_resolve_prereq l'inscrive.
				gogo_resolve_prereq "$1" # Will fill $prereq if necessary.
				shift
				;;
			*) break ;;
		esac
	done
	
	# Now loop over remaining items.
	
	for pr in "$@"
	do
		case "$pr" in
			# Symbolic prereq, but not first prereq: skip for later.
			[^0-9]*)
				#prereq="$prereq
				_gogo_resolve_pr -1 "$pr"
				;;
		esac
	done
}

# NOTE to self:
# On my FreeBSD 11.2, to test for an empty variable, case in "") seems quicker than test -z.
# With 10^6 iterations (6 nested loops over 10 elements each):
# case "$coucou" in "") ;; esac
#   0,6 s (coucou not defined)
#   0,8 s (coucou holds 8 characters)
# [ -z "$coucou" ]
#   1,2 s (coucou not defined)
#   1,7 s (coucou holds 8 characters)
