#!/bin/sh

set -x
voms-proxy-info -all || (env; exit 1)

USER_PROXY=`voms-proxy-info -path`
export GLEXEC_CLIENT_CERT=$USER_PROXY
export GLEXEC_SOURCE_PROXY=$USER_PROXY

/usr/sbin/glexec /usr/bin/id -a 
