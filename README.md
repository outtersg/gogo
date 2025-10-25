# Guillaume Outters' Gentle Orderer

A pure shell task launcher and organizer.

## Example: junction point

We'll launch concurrent connections to 3 SSH hosts, then run a summary task once all SSH have finished.\
(example of a simple workflow with a single junction point, that a shell `wait` would do equally well)

```sh
fetch()
{
	ssh -o ConnectTimeout=3 $1 hostname > /tmp/statistics.$$.$1
	echo "Finished fetching from $1"
}

statistics()
{
    echo Summary:
	ls /tmp/statistics.$$.* # Or whatever processing we want to do once all results have been received.
	rm -f /tmp/statistics.$$.*
}

rm -f /tmp/statistics.$$.*
for host in partage b mdm
do
	Start fetch_$host: fetch $host
done
After "fetch_*" statistics
```
```
Finished fetching from mdm
Finished fetching from partage
ssh: connect to host bonemine.local port 22: Operation timed out
Finished fetching from b
Summary:
/tmp/statistics.4293.b
/tmp/statistics.4293.mdm
/tmp/statistics.4293.partage
```

## Example: graph workflow

Here we start 3 initial tasks in decreasing duration order, and have a second wave of tasks each depending on the completion of a pair from the first wave.
```sh
t()
{
	local taskname="$1" wait="$2" ; shift 2
	"$@" $taskname: time sh -c "echo starting $taskname for $wait ; sleep $wait ; echo finishing $taskname"
}

t a   .3 Start
t b   .2 Start
t c   .1 Start
t ab  .1 After a,b
t ac  .1 After a,c
t bc  .1 After b,c
t end .1 After ab,bc
```

```
starting a for .3
starting b for .2
starting c for .1
finishing c
	0.13 real	0.00 user	0.03 sys
finishing b
	0.21 real	0.00 user	0.00 sys
starting bc for .1
finishing a
	0.31 real	0.00 user	0.01 sys
finishing bc
	0.10 real	0.00 user	0.00 sys
starting ab for .1
starting ac for .1
finishing ac
finishing ab
	0.12 real	0.12 real	0.00 user	0.00 user	0.00 sys
0.00 sys
starting end for .1
finishing end
	0.11 real	0.00 user	0.00 sys
```
