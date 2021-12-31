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

# Birth Registry
gogo_br()
{
	# Get a task ID.
	
	gogo_last_id=`expr $gogo_last_id + 1`
	local id=$gogo_last_id
	
	# Store the task's command.
	
	eval gogo_t_$id=\"\$\"
}

_gogosse()
{
	local after=
	while [ $# -gt 0 ]
	do
		case "$1" in
			--after) ;;
			--after-last) ;;
			*:) ;;
			*) break ;;
		esac
		shift
	done
# Lui affecter un numéro de tâche
	gogo_br 
# Si pas de condition avant, on peut lancer tout de suite: gogol
}

# Resolves symbolic prerequisites in $@; result is stored in $prereq.
# (prereqs found already finished are eaten immediately, doing a bit of gogo_ack_prereq())
# Non-wildcard symbols are resolved immediately ("task,other" means "the latest instantiated tasks having names 'task' and 'other'").
# Wildcard symbols are resolved immediately only if they are first in line:
#   "task,other~" means "the last 'task' task, and every 'other' that may have been instantiated by 'task'" (so wait 'task' to finish before evaluating 'other~')
#   "other~"      here we have no preceding task (that could emit other 'other's), so look up for tasks named 'other' immediately
gogo_resolve_prereq()
{
	local pr sep=
	prereq=
	
	for pr in "$@"
	do
		case "$pr" in
			# "The whole family" (every task ever launched with this name):
			*~)
				case "$sep" in
					# Only resolve if no preceding task is wait for.
					"")
						IFS=~
						gogo_tifs _gogo_resolve_pr todo $pr
						;;
					# Else copy as is.
					*) prereq="$prereq $pr" ;;
				esac
				;;
			# [^0-9]*: A symbolic (not already resolved) but single (no wildcard) name;
			#  [0-9]*: A numeric ID (already resolved), we just have to check it has finished:
			*)
				_gogo_resolve_pr curr "$pr"
				;;
			# @todo Handle *\* (x~ resolves to (possibly multiple) tasks named x, whereas x* refers to x as well as xy or xylophone).
		esac
		case "$pr" in
			?*)
				prereq="$prereq$pr$sep"
				sep=' '
				;;
		esac
	done
	
	# Already run prerequisites are not needed anymore: remove them.
}

# Resolve a single name, if found put result in $pr.
# If 
_gogo_resolve_pr()
{
	eval 'pr="$gogo_'$1'_'$2'"'
	case "$pr" in
		?*)
			# Still running? Mark us as waiting for it, to speed up our resolution
			# À FAIRE: sur waiters_, ne pas réinvoquer tout resolve, mais virer promptement juste la valeur de la liste. Sauf que derrière si on est le dernier (liste résultante vide), il faudra déclencher gogol => fonction haut niveau à appeler soit de resolve_prereq, soit de dede cuort-circuitant
			gogo_waiters_= # Si pas déjà référencé comme attendant!
			return
			;;
	esac
	
	# If not found, are there done tasks with this name?
	
	eval 'local done="$gogo_done_'$2'"'
	case "$done" in
		"") gogo_warn "$name depends on $2~, but no tasks has ever been launched with this name" ;;
	esac
	
	# Nonetheless return an empty dependency.
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
			[^0-9]*) prereq="$prereq
				_gogo_resolve_pr curr "$pr"
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
