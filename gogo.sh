#!/bin/sh
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

# Guillaume Outters' Gentle Orderer
# Grand Ordonnanceur de Guillaume Outters

# Can either be used as part of a script (that has to define $GOGO_SCRIPTS as the directory containing gogo.sh)
# or as a launcher, as in gogo.sh my_commands.sh
# Should be installed as a whole package (gogo.sh next to its gogo.*.sh includes), but can be used from a link, for example after: ln -s "`pwd`/gogo.sh" ~/bin/gogo

set -e

#- Output ----------------------------------------------------------------------

# Displays a message using $1 as an ANSI escape sequence.
# E.g.:
#   gogo_colordisplay 31 "# Fatal error" >&2
#   cat "$stderrOutputFile" | gogo_colordisplay 33 >&2
gogo_colordisplay()
{
	local color="$1" ; shift
	local message="$*"
	local ret="`printf '\n'`"
	case "$message" in
		*""*) message="`echo "$message" | sed -e "s//[36m_[${color}m/g"`"
	esac
	case "$message" in
		"") _gogo_colordisplayFilter "$color" ;;
		*"$ret"*) echo "$message" | _gogo_colordisplayFilter "$color" ;;
		*) printf "%s%s%s\n" "[${color}m" "$message" "[0m" ;;
	esac
}

_gogo_colordisplayFilter()
{
	sed -e "s/^/[${color}m/" -e "s/$/[0m/" 
}

gogo_warn()
{
	gogo_colordisplay 33 "$@" >&2
}

gogo_err()
{
	gogo_colordisplay 31 "$@" >&2
	return 1
}

gogo_fatal()
{
	gogo_err "$@"
	exit 1
}

gogo_log()
{
	local level="$1" ; shift
	gogo_colordisplay 90 "$@" >&2
}

#- Initialization --------------------------------------------------------------

# Compute All Localizable Links and Get Includee's Real Location.
gogo_callgirl()
{
	if [ -z "$GOGO_SCRIPTS" ]
	then
		gogo_unlink_s() { local s2 ; while [ -h "$s" ] ; do s2="`readlink "$s"`" ; case "$s2" in [^/]*) s2="`dirname "$s"`/$s2" ;; esac ; s="$s2" ; done ; }
		gogo_callgirl_search() { local s="`command -v "$0"`" ; [ -x "$s" -o ! -x "$0" ] || s="$0" ; case "$s" in */bin/*sh) case "`basename "$s"`" in *.*) true ;; *sh) s="$1" ;; esac ;; esac ; case "$s" in [^/]*) s="`pwd`/$s" ;; esac ; gogo_unlink_s ; s="`dirname "$s"`" ; gogo_unlink_s ; GOGO_SCRIPTS="$s" ; }
		gogo_callgirl_search
	fi
	
	if [ ! -f "$GOGO_SCRIPTS/gogo.sh" ]
	then
		gogo_fatal "# Could not find myself (gogo.sh) at \$GOGO_SCRIPTS ($GOGO_SCRIPTS)."
	fi
}

gogo_includes()
{
	local f
	for f in "$GOGO_SCRIPTS"/gogo.*.sh
	do
		. "$f"
	done
}

gogo_dance()
{
	gogo_callgirl "$@"
	gogo_includes
	
	local f
	for f in "$@"
	do
		if [ "$f" -ef "$GOGO_SCRIPTS/gogo.sh" ] ; then continue ; fi # In case we are called as sh gogo.sh userfile.sh
		# Handle two types of scripts:
		# - those embedding their own gogogo() start point(); they are supposed to be a bunch of function definitions, and define a gogogo() function that start everything.
		# - the simple ones, whose body *is* the script.
		if grep -q 'gogogo()' < "$f"
		then
			. "$f"
			gogo_boot_script() { ( export GOGO_CHANNEL ; gogogo ) & }
		else
			# The script may embed both utility function definitions (that should be played in the loop runner, so that its env gets the utilities),
			# and a sequence of instructions to start subprocesses (that should be played by the loop filler).
			# For having the utilities available in the (runner's) env, it cannot be run in a subshell like above;
			# BUT we cannot either run the filler sequentially before the runner (because the filler will fill the pipe, and will block if the runner, not yet launched, does not consume it).
			# So we have to short-circuit the filler low-level funcs, so that they delay their write: it means we will run the first commands only after the last one has been piped.
			gogo_boot_script()
			{
				export GOGO_CHANNEL=$gigo.tmp
				touch $gigo.tmp && chmod 600 $gigo.tmp
				> $gigo.tmp
				. "$f" # Runs in master process (so affects the env), but with GOGO_CHANNEL redirected to a conventional file instead of a blocking fifo.
				( cat $gigo.tmp > $gigo ; rm $gigo.tmp ) & # Now copy the file to the FIFO, in a subshell (no matter if it blocks).
				export GOGO_CHANNEL=$gigo
				# And now let the loop run.
			}
		fi
		
		gogo_run
	done
}

gogo_dance "$@"
