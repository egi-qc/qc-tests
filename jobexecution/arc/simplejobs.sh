#!/bin/bash
#
# This script submits simple jobs to a CREAM CE
# 

DEFAULT_CE=test27.egi.cesga.es
VO=dteam

. utils.sh


mydir=`mktemp -d`
pushd $mydir

init $*

echo "### Call arcinfo"
arcinfo -c $CE 

# Selecting interfaces to test:
TEST_GRIDFTPJOB=0
TEST_BES=0
arcinfo -c $CE | grep -q "org\.nordugrid\.gridftpjob" && TEST_GRIDFTPJOB=1
arcinfo -c $CE | grep -q "org\.ogf\.bes" && TEST_BES=1

TEST_GRIDFTPJOB=1
TEST_BES=0

if [ $TEST_GRIDFTPJOB -eq 1 ] ; then
    echo "Will test org.nordugrid.gridftpjob interface"
fi
if [ $TEST_BES -eq 1 ] ; then
    echo "Will test org.ogf.bes interface"
fi

echo
echo "### Submit simple job"

cat > job.rsl << EOF
&(Executable = "/bin/uname")(Arguments = "-a")
EOF

[ $TEST_GRIDFTPJOB -eq 1 ] &&  submit_job_and_wait job.rsl org.nordugrid.gridftpjob
[ $TEST_BES -eq 1 ] &&  submit_job_and_wait job.rsl org.ogf.bes

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

cat > job.rsl << EOF
&
(Executable="script.sh")
(Arguments="myfile" "$size")
(inputfiles=("myfile" "" ) ("script.sh" ""))
(stdout="std.out")
(stderr="std.err")
EOF

[ $TEST_GRIDFTPJOB -eq 1 ] &&  submit_and_get_output job.rsl org.nordugrid.gridftpjob
[ $TEST_BES -eq 1 ] &&  submit_and_get_output job.rsl org.ogf.bes

# job with some environment defined
cat > env-script.sh << EOF
#!/bin/sh

echo  Expecting SA2_ENV_VAR to be defined and equal to "FOOBAR"

if [ \$SA2_ENV_VAR = "FOOBAR" ] ; then
    exit 0
else
    echo "Variable not defined or differento to FOOBAR" 1>&2
    exit 1
fi
EOF

cat > job.rsl << EOF
&
(Executable="env-script.sh")
(Environment=(SA2_ENV_VAR "FOOBAR"))
(inputfiles=("env-script.sh" ""))
(stdout="std.out")
(stderr="std.err")
EOF

[ $TEST_GRIDFTPJOB -eq 1 ] &&  submit_and_get_output job.rsl org.nordugrid.gridftpjob
[ $TEST_BES -eq 1 ] &&  submit_and_get_output job.rsl org.ogf.bes


# 5. Cancel a submitted job
echo 
echo "### Cancel job"
cat > job.rsl << EOF
&(Executable="/bin/sleep")(Arguments="30m")
EOF

[ $TEST_GRIDFTPJOB -eq 1 ] &&  submit_and_cancel_job job.rsl org.nordugrid.gridftpjob
[ $TEST_BES -eq 1 ] &&  submit_and_cancel_job job.rsl org.ogf.bes


# XXX
# Missing tests:
# test runtimeenv
# Requires configuration of the CE

# remove whatever is left
arcclean -a

# arc stat should exit with error
arcstat -a && (echo "Expecting error here!?" ; exit 1)

popd
rm -rf $mydir
