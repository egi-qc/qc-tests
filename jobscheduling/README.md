Job Scheduling
==============

This category covers WMS, GridWay and qcg-broker.

## Interaction with job execution appliances

No standard interface is enforced for Job Scheduling appliances. The job scheduling appliances may be able to manage work items in one or more kinds of Job Execution appliances, support is expected for at least one of the following:
* ARC-CE gridFTP
* BES
* CREAM
* EMI-ES
* Globus GRAM5
* UNICORE
* QCG-comp

The appliance must be able to perform the following operations against the supported Job Execution interfaces:
* create new jobs,
* retrieve the status of the jobs submitted by the appliance,
* cancel jobs, and
* (optionally) hold and resume jobs

The Appliance may perform these operations for individual jobs or for set of jobs in order to improve its performance (e.g. for retrieving the status instead of querying each of the individual jobs, do a single query for all jobs submitted for the appliance)

Any information needed for performing scheduling of jobs is expected to be discovered through the Information Discovery Appliances available in UMD, which use GlueSchema 1.3 or GlueSchema 2.0 with LDAP interface.

### How to test
* (If supported) Perform a list-match for jobs with no requirements. This should return a list with all available resources.
* Submit simple jobs (e.g. sleep for a couple of minutes) to the Job Scheduling Appliance and check:
  * the jobs are correctly executed in the execution appliance (CE)
  * the status of the job is retrieved correctly and in a timely manner (i.e. status may not be updated in real-time, but it should be available within a short period of time)
  * cancelling jobs in the Appliance removes the job in the underlying system
* Submit jobs with some input/output files and assure that the files are correctly transferred.
* If the appliance supports it, submit:
  * DAG jobs
  * Parametric jobs
  * Job Collections

See subdirs for sample jobs.

## Multi-node/multi-core jobs
Job Scheduling Appliances should also support multi-node/-core jobs. Check the JobScheduling section for more information. Sample jobs for are available at subdirs.

## WMS

For WMS check:
* Proxy renewal features work (submit a long job with a short renewable proxy and assure that it ends)
* Multiple role/group proxy is supported
* Proxies with long chains should be supported (such as the ones created by myproxy C=[...]/CN=proxy/CN=proxy/CN=proxy/...)

