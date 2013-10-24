Job Execution
=============

This category covers Computing Elements products (CREAM, ARC-CE, QCG-COMP, ...)


# Interaction with the batch system

Job execution appliances must be able to perform basic management jobs in a batch system:

* create new jobs,
* retrieve the status of the jobs submitted by the appliance,
* cancel jobs, and
* (optionally) hold and resume jobs 

The Appliance may perform these operations for individual jobs or for set of jobs in order to improve its performance (e.g. for retrieving the status instead of querying each of the individual jobs, do a single query for all jobs submitted for the appliance)

Verification must be performed for at least one of the following batch systems:
* Torque/PBS
* GE
* SLURM
* LSF 

## How to test

* Submit simple jobs (e.g. sleep for a couple of minutes) to the Job Execution Appliance and check:
 * the jobs are correctly executed in the batch system
 * the status of the job is retrieved correctly and in a timely manner (i.e. status may not be updated in real-time, but it should be available within a short period of time)
 * cancel the jobs in the Appliance removes the job in the batch system 
* Submit jobs with some input/output files and assure that the files are correctly transferred. 

Sample jobs for some CEs are available at the subdirectories.

# Multi-node/multi-core jobs

Job Execution Appliances should support multi-node/-core jobs. Different support modes are considered:

* multi-slot request: the job specifies the number of slots, which will be allocated following a default policiy defined by the site (e.g. filling up machines, using free slots of any machine, etc.)
* single-machine multi-core request: the job specifies number of required slots that get allocated within a single machine.
* multi-node multi-core request: job can specify the number of cores and the number of hosts to use (e.g. 4-cores at 2 different hosts)
* Exclusive request: job request specifies the hosts to be used exclusively. 

## How to test

Submit jobs for testing the different modes listed above and check in the batch system that the allocated slots are as specified.

Sample jobs for some CEs are available at the subdirectories. 

# Parallel jobs (with mpi-start)

mpi-start should be able to detect the batch system and execute parallel jobs with different MPI implementations.
## How to test

Submit mpi-start jobs with different slot requirements (see possible cases in the multi-node/multi-core test), using different parallel jobs (dummy, MPI and OpenMP), and check that:
* mpi-start detects the batch system
* input and executables is transferred to the nodes involved in the job
* MPI execution works without issues 

Sample tests are available at the mpi-start subdirectory.
