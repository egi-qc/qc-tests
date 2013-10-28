#!/bin/sh


FINAL_STATES="Finished Failed Deleted Killed"
RUNNING_STATES="Running" 
IDLE_STATES="Accepted Preparing Submitting Queuing Finishing NOTYETTHERE"
UNEXPECTED_STATES="Hold Other"


# submits a job
# $1 -> rsl
# $2 -> interface
# sets JOBID_FILE
submit_job() {
    rsl=$1
    echo "### Job to be submitted:"
    cat $rsl
    shift
    EXTRA_ARGS=""
    if [ "x$1" != "x" ] ;  then
        EXTRA_ARGS="-S $1"
        echo "  -> to interface $1"
    fi
    JOBID_FILE=jobid
    echo "" > $JOBID_FILE
    arcsub -c $CE -o $JOBID_FILE $EXTRA_ARGS $rsl
    JOBID=`cat $JOBID_FILE`
    # give some time to have the job there
    sleep 1m
}

get_status() {
    JOB_STATUS=`arcstat $JOBID 2> err | grep "^\sState:" | \
                    sed -e "s/.*State: \(\w*\).*/\1/"`
    if [ "x$JOB_STATUS" = "x" ] ; then
        cat err | grep -q "This job was very recently submitted" && JOB_STATUS="NOTYETTHERE"
        # Sometimes the job just disappears !?
        cat err | grep -q "WARNING" && JOB_STATUS="NOTYETTHERE"
    fi
    if [ "x$JOB_STATUS" = "x" ] ; then
        echo "Something went wrong checking the status!?"   
        arcstat $JOBID
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
# $1 -> rsl
# $2 -> iface
submit_job_and_wait() {
    submit_job $*
    wait_for_job
    if [ $JOB_STATUS = "Finished" ] ; then
        echo "### OK!"
    else
        echo "### Job is not finished OK and it should!"
        arcstat $JOBID
    fi
}


submit_and_get_output() {
    submit_job_and_wait $*
    arcget $JOBID > out || (echo "### Something went wrong getting out?!"; exit 1)
    DIR=`cat out | grep "^Results stored" | cut -f2 -d":" | tr -d " "`
    echo "### Job output"
    cat $DIR/std.out
    echo "### Job error"
    cat $DIR/std.err
}


# submits a job and then cancels it
# sets JOBID
submit_and_cancel_job() {
    submit_job $*
    # enough?
    sleep 2m
    arckill -k $JOBID
    wait_for_job
    if [ $JOB_STATUS = "Killed" ] ; then
        echo "### OK!"
    else
        echo "### Job is not cancelled and it should!"
        arcstat $JOBID
        exit 1
    fi
}


init() {
    if [ "x$1" != "x" ]; then
        CE=$1
    else
        CE=$DEFAULT_CE
    fi
    # Create proxy 
    echo
    echo "### Create user proxy"
    arcproxy -S $VO
}
