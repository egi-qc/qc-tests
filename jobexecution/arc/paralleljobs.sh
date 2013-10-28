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
TEST_GRIDFTPJOB=1
TEST_BES=0
arcinfo -c $CE | grep -q "org\.nordugrid\.gridftpjob" && TEST_GRIDFTPJOB=1
# arcinfo -c $CE | grep -q "org\.ogf\.bes" && TEST_BES=1

if [ $TEST_GRIDFTPJOB -eq 1 ] ; then
    echo "Will test org.nordugrid.gridftpjob interface"
fi
if [ $TEST_BES -eq 1 ] ; then
    echo "Will test org.ogf.bes interface"
fi

# this will work only for PBS, for other systems we need something similar
cat > pbs-counter.sh << EOF
#/bin/sh

EXPECTED_COUNT=\$1
shift
EXPECTED_NODES=\$2

COUNT=`cat \$PBS_NODEFILE | wc -l`
echo COUNT=\$COUNT
[ \$EXPECTED_COUNT -eq \$COUNT ] || (echo "Expecting \$EXPECTED_COUNT, got \$COUNT"; exit 1)
NODES=`cat \$PBS_NODEFILE | sort -u | wc -l`
echo NODES=\$NODES
if [ "x$EXPECTED_NODES" != "x" ] ; then
    [ \$EXPECTED_NODES -eq \$NODES ] || (echo "Expecting \$EXPECTED_NODES, got \$NODES"; exit 1)
fi
exit 0
EOF

echo
echo "### 2 slots"

cat > job.rsl << EOF
&
(Executable="pbs-counter.sh")
(Arguments="2")
(count=2)
(inputfiles=("pbs-counter.sh" ""))
(stdout="std.out")
(stderr="std.err")
EOF

[ $TEST_GRIDFTPJOB -eq 1 ] &&  submit_and_get_output job.rsl org.nordugrid.gridftpjob
[ $TEST_BES -eq 1 ] &&  submit_and_get_output job.rsl org.ogf.bes

# XXX: exclusive execution

popd
rm -rf $mydir
