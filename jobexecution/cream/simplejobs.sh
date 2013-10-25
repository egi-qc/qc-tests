#!/bin/bash
#
# This script submits simple jobs to a CREAM CE
# 

set -x

DEFAULT_CE=test06.egi.cesga.es
VO=dteam

. utils.sh

mydir=`mktemp -d`
pushd $mydir

init $*

# Get info about the CE
echo "### Show CE info"
glite-ce-service-info $CE

# 1 Submit simple job (assume all things are here!)
echo
echo "### Submit simple job"

cat > job.jdl << EOF
[
Executable = "/bin/uname";
Arguments  = "-a";
]
EOF

submit_job_and_wait job.jdl

# 2 Submit job with i/o
echo
echo "### Submit job with I/O"

dd if=/dev/zero of=myfile count=$(( $RANDOM % 128 ))
size=`stat -c "%s" myfile`

cat > script.sh << EOF
#!/bin/sh

size=\`stat -c %s \$1\`

echo Size of \$1 is \$size and should be \$2
echo "Test to stderr!" 1>&2

if [ \$size -eq \$2 ] ; then
    exit 0
else
    exit 1
fi
EOF

cat > job.jdl << EOF
[
Executable = "script.sh";
Arguments  = "myfile $size";
InputSandbox = {"myfile", "script.sh"};
OutputSandbox = {"std.out", "std.err"};
StdOutput = "std.out";
StdError = "std.err";
OutputSandboxBaseDestUri = "gsiftp://localhost";
]
EOF

submit_and_get_output job.jdl

# 5. Cancel a submitted job
echo 
echo "### Cancel job"
cat > job.jdl << EOF
[
Executable = "/bin/sleep";
Arguments  = "10m";
]
EOF

submit_and_cancel_job job.jdl


# Submit a job with short proxy and renew the proxy with a longer one
echo 
echo "### Renew proxy test"
voms-proxy-destroy
voms-proxy-init --voms $VO -valid 0:5
DELEGID=$(basename $(mktemp))
glite-ce-delegate-proxy -e $CE $DELEGID
cat > job.jdl << EOF
[
Executable = "/bin/sleep";
Arguments  = "10m";
]
EOF
submit_job job.jdl 
# Renew proxy
sleep 1m
voms-proxy-init --voms $VO 
glite-ce-proxy-renew -e $CE $DELEGID
wait_for_job
if [ $JOB_STATUS = "DONE-OK" ] ; then
    echo "### OK!"
else
    echo "### Job is not finished OK and it should!"
    glite-ce-job-status -i $JOBID_FILE
fi

# purge all jobs
glite-ce-job-purge -e $CE -a
# and check there is nothing there
glite-ce-job-status -e $CE -a

popd
rm -rf $mydir
