#!/bin/bash 

if [ "x$1" = "x" ] ; then
	# XXX: this is hardcoded, how to get the port?
	BASE_URL=https://test27.egi.cesga.es:8443
else
	BASE_URL=$1
fi

voms-proxy-info -exists > /dev/null 2>&1
if [ $? -ne 0 ] ; then
	echo "Proxy does not exist?"
	voms-proxy-info -exists
	exit 1
fi

VO=`voms-proxy-info -vo`
PROXY_FILE=`voms-proxy-info -path`
USER_CERT=$HOME/.globus/usercert.pem
CA_PATH=/etc/grid-security/certificates

CURL_ARGS="-f --cacert $USER_CERT --capath $CA_PATH --cert $PROXY_FILE"

STDOUT=`mktemp`
DIR=`basename $STDOUT`

BASE_URL=$BASE_URL/$VO

TEST_FILE=`mktemp`
cat > $TEST_FILE << EOF
This is a simple test
$RANDOM
$RANDOM
$RANDOM
EOF

execute() {
        echo ">> Executing $@"
        eval $@ 2>&1 > $STDOUT 2>&1
        if [ $? -ne 0 ] ; then
                echo "[ERROR]"
                cat $STDOUT
                exit 1
        fi
        echo "[OK]"
}

echo ">> Proxy info:"
voms-proxy-info -all
echo ""

# mkdir (MKCOL)
execute curl $CURL_ARGS -X MKCOL $BASE_URL/$DIR

# put a file in created dir
execute curl $CURL_ARGS -X PUT -T $TEST_FILE $BASE_URL/$DIR/test00.txt

# get the file back and compare
GET_TEST_FILE=`mktemp`
execute curl $CURL_ARGS -X GET -o $GET_TEST_FILE $BASE_URL/$DIR/test00.txt
diff -u $TEST_FILE $GET_TEST_FILE
if [ $? -ne 0 ] ; then
	echo "<< Files differ!?"
	exit 1
fi
rm $GET_TEST_FILE

# ls (PROPFIND)
execute curl $CURL_ARGS -X PROPFIND  $BASE_URL/$DIR
# search the file in the ls
cat $STDOUT | grep -q test00.txt
if [ $? -ne 0 ] ; then
	echo "<< File test00.txt not in PROPFIND!?"
	exit 1
fi

# COPY 
execute curl $CURL_ARGS -X COPY -H "Destination: $BASE_URL/$DIR/test01.txt" \
	     $BASE_URL/$DIR/test00.txt 
# recheck again the files
execute curl $CURL_ARGS -X PROPFIND  $BASE_URL/$DIR
cat $STDOUT | grep -q test01.txt
if [ $? -ne 0 ] ; then
	echo "<< File test01.txt not in PROPFIND!?"
	exit 1
fi
cat $STDOUT | grep -q test00.txt
if [ $? -ne 0 ] ; then
	echo "<< File text00.txt not in PROPFIND!?"
	exit 1
fi

# MOVE
execute curl $CURL_ARGS -X MOVE -H "Destination: $BASE_URL/$DIR/test02.txt" \
	     $BASE_URL/$DIR/test00.txt 
# recheck again the files
execute curl $CURL_ARGS -X PROPFIND  $BASE_URL/$DIR
cat $STDOUT | grep -q test01.txt
if [ $? -ne 0 ] ; then
	echo "<< File test01.txt not in PROPFIND!?"
	exit 1
fi
cat $STDOUT | grep -q test02.txt
if [ $? -ne 0 ] ; then
	echo "<< File test01.txt not in PROPFIND!?"
	exit 1
fi
cat $STDOUT | grep -v -q test00.txt 
if [ $? -ne 0 ] ; then
	echo "<< File text00.txt still in PROPFIND!?"
	exit 1
fi

# get the file again and compare
GET_TEST_FILE=`mktemp`
execute curl $CURL_ARGS -X GET -o $GET_TEST_FILE $BASE_URL/$DIR/test02.txt
diff -u $TEST_FILE $GET_TEST_FILE
if [ $? -ne 0 ] ; then
	echo "<< Files differ!?"
	exit 1
fi
rm $GET_TEST_FILE

# DELETE the mess
execute curl $CURL_ARGS -X DELETE $BASE_URL/$DIR/test02.txt
execute curl $CURL_ARGS -X DELETE $BASE_URL/$DIR/test01.txt
execute curl $CURL_ARGS -X DELETE $BASE_URL/$DIR

execute curl $CURL_ARGS -X PROPFIND  $BASE_URL
cat $STDOUT | grep -v -q $DIR
if [ $? -ne 0 ] ; then
	echo "<< Dir $DIR still in PROPFIND!?"
	exit 1
fi

rm -f $STDOUT $TESTFILE

echo ""
echo ""
echo "<< All tests succeded!"

exit 0
