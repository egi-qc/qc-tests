#JOBMANAGER=jobmanager-pbs
#JOBMANAGER=jobmanager-pbs2
#JOBMANAGER=jobmanager


HOST=test27.egi.cesga.es
PBS=0
JOBMANAGER=$1
echo $JOBMANAGER | grep pbs > /dev/null
if [ $? -eq 0 ] ; then
    PBS=1
fi


echo "*** Using $JOBMANAGER ***"

echo "### Simple whoami:"
globus-job-run $HOST/$JOBMANAGER `which whoami`


echo
echo
echo "### File transfer:"

cat > job1.rsl << EOF
&
(executable=/bin/ls)
(arguments=-l)
(file_stage_in = (\$(GLOBUSRUN_GASS_URL) # "/home/enol/myfile" afile))
EOF
seq $RANDOM > myfile
echo "ls -l myfile"
ls -l myfile 
echo "job:"
cat job1.rsl
echo "output:"
globusrun -s -f job1.rsl -r $HOST/$JOBMANAGER

echo
echo
echo "### Job Status:"
cat > job2.rsl << EOF
&
(executable=/bin/sleep)
(arguments=1m)
EOF
echo "job:"
cat job2.rsl
jobid=`globusrun -b -s -f job2.rsl -r $HOST/$JOBMANAGER`
echo "job id: $jobid"
status=""
while [ "$status" != "DONE" ]; do
	date
	status=`globusrun -status $jobid`
	echo "Status: $status"
	if [ "$PBS" = "1" ] ; then
		echo "PBS Status: "
		qstat
	fi 
	sleep 20s
done


echo
echo
echo "### Job Cancel:"
cat > job3.rsl << EOF
&
(executable=/bin/sleep)
(arguments=10m)
EOF
echo "job:"
cat job3.rsl
date
jobid=`globusrun -b -s -f job3.rsl -r $HOST/$JOBMANAGER`
echo "job id: $jobid"
globusrun -status $jobid
if [ "$PBS" = "1" ] ; then
	echo "PBS Status: "
	qstat
fi 
sleep 1m
date
echo "Cancelling..."
globusrun -k $jobid
if [ "$PBS" = "1" ] ; then
	echo "PBS Status: "
	qstat
fi 
echo "Status post cancel:"
globusrun -status $jobid
if [ "$PBS" = "1" ] ; then
	echo "PBS Status: "
	qstat
fi 

if [ "$PBS" != "1" ] ; then
	echo
	echo "### Parallel job:"
	cat > job4.rsl << EOF
&
(executable=/bin/ls)
(arguments=-ltr)
(count=2)
EOF
	echo "job:"
	cat job4.rsl
	echo "output:"
	globusrun -s -f job4.rsl -r $HOST/$JOBMANAGER
fi
