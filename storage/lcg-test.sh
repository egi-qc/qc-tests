#!/bin/bash -e

VO=`voms-proxy-info -vo`

SE_HOST=$1
# this may not be true for non StoRM, is there any 
# easy way to check this
SRM_BASE=srm://$SE_HOST:8444/$VO

export LCG_GFAL_INFOSYS=$SE_HOST:2170

FILE=`mktemp`
FILE2=`mktemp`

echo > $FILE << EOF
Hello world!
$RANDOM
$RANDOM
$RANDOM
EOF

REMOTE_FILE=test_`date +%s`

set -x
lcg-ls -vl $SRM_BASE

lcg-cp -v file:$FILE $SRM_BASE/$REMOTE_FILE

lcg-gt -v $SRM_BASE/$REMOTE_FILE gsiftp 

lcg-gt -v $SRM_BASE/$REMOTE_FILE https

lcg-gt -v $SRM_BASE/$REMOTE_FILE file

lcg-ls -vl $SRM_BASE | grep $REMOTE_FILE 

lcg-cp -v $SRM_BASE/$REMOTE_FILE file:$FILE2

diff $FILE $FILE2

lcg-del -vl $SRM_BASE/$REMOTE_FILE

set +x
echo "Tests succeded!"
rm -rf $FILE
rm -rf $FILE2
