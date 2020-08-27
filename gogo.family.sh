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
