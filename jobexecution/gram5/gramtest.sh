#!/bin/sh 

TORQUE_SETUP=1
HOST=test27.egi.cesga.es

OSTYPE="sl5"
OSTYPE="sl6"
OSTYPE="deb6"

# the DN of the user 
USER_CERT="usercert.pem"
USER_KEY="userkey.pem"
USER_DN=`openssl x509 -in ~/.globus/usercert.pem -noout -subject | sed 's/subject= //'`


if [ $TORQUE_SETUP -eq 1 ] ; then
	echo "Set up torque..."
	#yum install torque-server  torque-scheduler torque-mom torque-client
	#create-munge-key
	#service munge start

	if [ $OSTYPE = "sl5" ] ; then 
		TORQUE_VAR=/var/torque
	elif [ $OSTYPE = "sl6" ] ; then
		TORQUE_VAR=/var/lib/torque
	elif [ $OSTYPE = "deb6" ] ; then
		TORQUE_VAR=/var/spool/torque/
	fi

	echo "$HOST" > $TORQUE_VAR/server_name
	echo "$HOST np=2" > $TORQUE_VAR/server_priv/nodes

	if [ -f $TORQUE_VAR/mom_priv/config ] ; then
		sed -i "s/localhost/$HOST/" $TORQUE_VAR/mom_priv/config
	fi

	if [ $OSTYPE = deb6 ] ; then
		service torque-server restart
		service torque-mom restart
		service torque-scheduler restart
	else
		service pbs_server start
		service pbs_mom start
		service pbs_sched start
	fi

	qmgr << EOF
create queue testq
set queue testq queue_type = Execution
set queue testq resources_max.cput = 48:00:00
set queue testq resources_max.walltime = 72:00:00
set queue testq acl_group_enable = False
set queue testq enabled = True
set queue testq started = True
#
# Set server attributes.
#
set server scheduling = True
set server acl_host_enable = False
set server acl_hosts = $HOST
set server managers = root@$HOST
set server operators = root@$HOST
set server default_queue = testq
set server log_events = 511
set server mail_from = adm
set server query_other_jobs = True
set server scheduler_iteration = 600
set server node_check_rate = 150
set server tcp_timeout = 6
set server node_pack = False
set server mail_domain = never
set server kill_delay = 10
EOF

	exit 0
fi

# use sha2 certs
if [ ! -f /etc/grid-security/hostcert-SHA1.pem ] ; then
	cp -f /etc/grid-security/hostcert.pem /etc/grid-security/hostcert-SHA1.pem
	cp -f /etc/grid-security/hostkey.pem /etc/grid-security/hostkey-SHA1.pem
fi
cp -f /etc/grid-security/hostcert-SHA2.pem /etc/grid-security/hostcert.pem
cp -f /etc/grid-security/hostkey-SHA2.pem /etc/grid-security/hostkey.pem
chmod 400 /etc/grid-security/hostkey.pem
chmod 644 /etc/grid-security/hostcert.pem

set -x
service globus-gatekeeper
service globus-gatekeeper status
service globus-gatekeeper start
service globus-gatekeeper status
ps aux | grep gatekeeper
service globus-gatekeeper stop
service globus-gatekeeper status
ps aux | grep gatekeeper
service globus-gatekeeper start
tail /var/log/globus-gatekeeper.log
set +x

echo ""
echo ""
echo ""

set -x
globus-gatekeeper-admin -l
globus-gatekeeper-admin -e jobmanager-fork-poll -n jobmanager
globus-gatekeeper-admin -e jobmanager-pbs-poll -n jobmanager-pbs
globus-gatekeeper-admin -e jobmanager-pbs-seg -n jobmanager-pbs2
globus-gatekeeper-admin -l

globus-scheduler-event-generator-admin -e pbs
globus-scheduler-event-generator-admin -l
service globus-scheduler-event-generator status
service globus-scheduler-event-generator start
service globus-scheduler-event-generator status
set +x

echo ""
id sa2user &> /dev/null || adduser -m sa2user
id test &> /dev/null || adduser -m test

echo '"'$USER_DN'" test' > /etc/grid-security/grid-mapfile

mkdir -p /home/sa2user/.globus

if [ ! -f /home/sa2user/.globus/userkey.pem ] ; then
	cp $USER_CERT /home/sa2user/.globus/usercert.pem
	cp $USER_KEY /home/sa2user/.globus/userkey.pem
fi
if [ ! -f /home/sa2user/testjob.sh ] ; then
	cp testjob.sh /home/sa2user/testjob.sh 
fi

chmod +x /home/sa2user/testjob.sh

chown -R sa2user:sa2user /home/sa2user

echo "+ grid-proxy-init -rfc"
su - sa2user -c "grid-proxy-init -rfc"

echo "+ grid-proxy-info"
su - sa2user -c "grid-proxy-info"

su - sa2user -c "./testjob.sh jobmanager"

echo "" 
su - sa2user -c "./testjob.sh jobmanager-pbs"

echo ""
su - sa2user -c "./testjob.sh jobmanager-pbs2"


echo "World Writable files"
find / -xdev -type f -perm -o+w -exec ls -l {} \;

