#!/bin/sh


FINAL_STATES="DONE-OK DONE-FAILED CANCELLED  ABORTED"
RUNNING_STATES="RUNNING REALLY-RUNNING"
IDLE_STATES="REGISTERED PENDING IDLE"
UNEXPECTED_STATES="HELD UNKNOWN"

# submits a job
# $1 -> jdl
# sets JOBID_FILE
submit_job() {
    jdl=$1
    echo "### Job to be submitted:"
    cat $jdl
    JOBID_FILE=jobid
    echo "##CREAMJOBS##" > $JOBID_FILE
    glite-ce-job-submit -r $CEID -o $JOBID_FILE -D $DELEGID $jdl
}

get_status() {
    JOB_STATUS=`glite-ce-job-status -L 0 -i $JOBID_FILE | \
                    grep "^\s*Status" | sed -e "s/.*\[\([^]]*\)\].*/\1/"`
    echo $JOB_STATUS
    if [ "x$JOB_STATUS" = "x" ] ; then
        echo "Something went wrong checking the status!?"
        glite-ce-job-status -i $JOBID_FILE
        exit 1
    fi
}

wait_for_job() {
    while [ /bin/true ] ; do
        get_status
        for st in $FINAL_STATES ; do
            if [ $JOB_STATUS = $st ] ; then
                return
            fi  
        done
        for st in $UNEXPECTED_STATES ; do
            if [ $JOB_STATUS = $st ] ; then
                return
            fi  
        done
        # I guess it's in a running state or pending, just wait a bit
        sleep 30
    done
}

# submits and waits for completion
# $1 -> jdl
submit_job_and_wait() {
    submit_job $1
    wait_for_job
    if [ $JOB_STATUS = "DONE-OK" ] ; then
        echo "### OK!"
    else
        echo "### Job is not finished OK and it should!"
        glite-ce-job-status -i $JOBID_FILE
    fi
}

submit_and_get_output() {
    submit_job_and_wait $1
    osb=`glite-ce-job-status -L 2 -i $JOBID_FILE | grep "CREAM OSB URI" | cut -d"/" -f4- | cut -d"]" -f1`
    uberftp $CE "cd /$osb; get std.out; get std.err"
    echo "### Job output"
    cat std.out
    echo "### Job error"
    cat std.err
 
}

# submits a job and then cancels it
# $1 -> jdl
# sets JOBID_FILE
submit_and_cancel_job() {
    jdl=$1
    echo "### Job to be submitted:"
    cat $jdl
    JOBID_FILE=jobid
    echo "##CREAMJOBS##" > $JOBID_FILE
    glite-ce-job-submit -r $CEID -o $JOBID_FILE -D $DELEGID $jdl
    glite-ce-job-status -i $JOBID_FILE
    # is this enough!?
    sleep 90
    glite-ce-job-cancel -N -i $JOBID_FILE
    wait_for_job
    if [ $JOB_STATUS = "CANCELLED" ] ; then 
        echo "### OK!"
    else
        echo "### Job is not cancelled and it should!"
        glite-ce-job-status -i $JOBID_FILE
    fi
}


init() {
    if [ "x$1" != "x" ]; then
        CE=$1
    else
        CE=$DEFAULT_CE
    fi
    echo 
    echo "### Get CE id from ldap"
    CEID=`ldapsearch -LLL -x -h $CE -p 2170 -b o=grid "(&(GlueCEAccessControlBaseRule=VO:$VO)(GlueCEInfoHostName=$CE))" | grep "^GlueCEUniqueID:" | tail -1 | cut -f2 -d" "`
    echo "### -> $CEID"
    # Create proxy if not there
    echo 
    echo "### Check user proxy and delegate at CE"
    VOMS_INFO=`mktemp`
    DELEGID=`basename $VOMS_INFO`
    VALID_PROXY=0
    voms-proxy-info --all > $VOMS_INFO 2> /dev/null
    if [ $? -eq 0 ] ; then
        cat $VOMS_INFO | grep "^VO" | grep "\<$VO\>" > /dev/null
        if [ $? -eq 0 ] ; then
            h=`cat $VOMS_INFO | grep "^timeleft" | tail -1 | cut -f2 -d":"`
            if [ $h -gt 1 ] ; then
                VALID_PROXY=1
            fi
        fi
    fi
    if [ $VALID_PROXY -eq 0 ] ; then
        voms-proxy-init --voms $VO
    fi

    glite-ce-delegate-proxy -e $CE $DELEGID
}
