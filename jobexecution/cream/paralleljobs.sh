#!/bin/sh
# Tests parallel jobs (uses mpi-start!)

DEFAULT_CE=test19.egi.cesga.es
VO=dteam

. utils.sh

mydir=`mktemp -d`
pushd $mydir

init $*


submit_job() {
    jdl=$1
    echo "### Job to be submitted:"
    cat $jdl
    JOBID_FILE=jobid
    echo "##CREAMJOBS##" > $JOBID_FILE
    glite-ce-job-submit -r $CEID -o $JOBID_FILE -D $DELEGID $jdl
    glite-ce-job-status -i $JOBID_FILE
    sleep 10m 
    glite-ce-job-status -i $JOBID_FILE | grep "DONE-OK" > /dev/null
    if [ $? -ne 0 ] ; then
        echo "### Job is not finished OK and it should!"
        glite-ce-job-status -i $JOBID_FILE
    else
        echo "### OK!"
    fi
}

submit_and_get_output() {
    submit_job $1
    # ugly way of getting the stdout and stderr
    osb=`glite-ce-job-status -L 2 -i $JOBID_FILE | grep "CREAM OSB URI" | cut -d"/" -f4- | cut -d"]" -f1`
    uberftp $CE "cd /$osb; get std.out; get std.err"

    echo "### Job output"
    cat std.out
    echo "### Job error"
    cat std.err
}

# Get info about the CE
echo "### Show CE info"
glite-ce-service-info $CE 

# 3 Submit simple job (assume all things are here!)
echo
echo "### Submit parallel job 2 CPUs"

cat > counter.sh << EOF
#!/bin/sh
echo NP: \$MPI_START_NP
echo HOSTS: \$MPI_START_NHOSTS 
echo SLOTS: \$MPI_START_NSLOTS

echo HOSTS-SLOTS:
cat \$MPI_START_HOST_SLOTS_FILE 

if [ "x\$0" = "xcpus" ] ; then
    if [ "x\$1" != "x$MPI_START_NSLOTS" ] ; then
        echo "NOT MATCHING EXPECTED SLOTS!"
        exit 1
    fi
elif [ "x\$0" = "xnodes" ] ; then
    if [ "x\$1" != "x$MPI_START_NHOSTS" ] ; then
        echo "NOT MATCHING EXPECTED HOSTS!"
        exit 1
    fi
fi

exit 0
EOF

cat > job.jdl << EOF
[
Executable = "/usr/bin/mpi-start";
CPUNumber  = 2;
Arguments  = "-t dummy -- counter.sh cpus 2";
InputSandbox = {"counter.sh"};
OutputSandbox = {"std.out", "std.err"};
StdOutput = "std.out";
StdError = "std.err";
OutputSandboxBaseDestUri = "gsiftp://localhost";
]
EOF

submit_and_get_output job.jdl

echo
echo "### Submit parallel job 4 CPUs"

cat > job.jdl << EOF
[
Executable = "/usr/bin/mpi-start";
CPUNumber  = 4;
Arguments  = "-t dummy -- counter.sh cpus 4";
InputSandbox = {"counter.sh"};
OutputSandbox = {"std.out", "std.err"};
StdOutput = "std.out";
StdError = "std.err";
OutputSandboxBaseDestUri = "gsiftp://localhost";
]
EOF

submit_and_get_output job.jdl

echo
echo "### Submit parallel job WholeNode"

cat > job.jdl << EOF
[
Executable = "/usr/bin/mpi-start";
WholeNodes = True;
HostNumber = 1;
Arguments  = "-t dummy -- counter.sh nodes 1";
InputSandbox = {"counter.sh"};
OutputSandbox = {"std.out", "std.err"};
StdOutput = "std.out";
StdError = "std.err";
OutputSandboxBaseDestUri = "gsiftp://localhost";
]
EOF

submit_and_get_output job.jdl

echo
echo "### Submit parallel job WholeNode 2 Hosts"

cat > job.jdl << EOF
[
Executable = "/usr/bin/mpi-start";
WholeNodes = True;
HostNumber = 2;
Arguments  = "-t dummy -- counter.sh nodes 2";
InputSandbox = {"counter.sh"};
OutputSandbox = {"std.out", "std.err"};
StdOutput = "std.out";
StdError = "std.err";
OutputSandboxBaseDestUri = "gsiftp://localhost";
]
EOF

submit_and_get_output job.jdl

echo
echo "### Submit parallel job MPI 2 Processes"

cat > cpi.c << EOF
#include "mpi.h"
#include <stdio.h>
#include <math.h>

double f( double );
double f( double a )
{
    return (4.0 / (1.0 + a*a));
}

int main( int argc, char *argv[])
{
   int n_intervals = 16384;

   int done = 0, n, myid, numprocs, i, k;
   double PI25DT = 3.141592653589793238462643;
   double mypi, pi, h, sum, x, y;
   double startwtime = 0.0, endwtime;
   int  namelen;
   char processor_name[MPI_MAX_PROCESSOR_NAME];

   MPI_Init(&argc,&argv);
   MPI_Comm_size(MPI_COMM_WORLD,&numprocs);
   MPI_Comm_rank(MPI_COMM_WORLD,&myid);
   MPI_Get_processor_name(processor_name,&namelen);

  fprintf(stderr,"Process %d on %s: n=%d\n",myid, processor_name,n);
   if (numprocs >= 1) {
       if( myid == 0 ) fprintf(stderr,"Using %d intervals\n",n_intervals);

       n = 0;
       while (!done)
       {
      if (myid == 0) {
         startwtime = MPI_Wtime();
      }
      if( n == 0  ) n = n_intervals; else n = 0;
      MPI_Bcast(&n, 1, MPI_INT, 0, MPI_COMM_WORLD);
      if (n == 0)
         done = 1;
      else
      {
         h   = 1.0 / (double) n;
         sum = 0.0;
         for (i = myid + 1; i <= n; i += numprocs)
         {
        x = h * ((double)i - 0.5);
        sum += f(x);
		for (k = 0; k < 10000; k++) {
			y = y + sqrt(abs(pow(x, 9)) + 1);
		}	
		printf("Y: %d\n", y);
         }
         mypi = h * sum;

         MPI_Reduce(&mypi, &pi, 1, MPI_DOUBLE, MPI_SUM, 0, MPI_COMM_WORLD);

         if (myid == 0)
         {
        printf("pi is approximately %.16f, Error is %.16f\n",
               pi, fabs(pi - PI25DT));
        endwtime = MPI_Wtime();
        printf("wall clock time = %f\n",
        endwtime-startwtime);
         }
      }
      }
   } else {
       fprintf(stderr,"Only 1 process, not doing anything");
   }
   MPI_Finalize();

   return 0;
}
EOF

cat > hooks.sh << EOF
pre_run_hook () {
  # Compile the program.
  echo "Compiling \${I2G_MPI_APPLICATION}"

  # Actually compile the program.
  cmd="\$MPI_MPICC \${MPI_MPICC_OPTS} -o \${I2G_MPI_APPLICATION} \${I2G_MPI_APPLICATION}.c -lm"
  \$cmd
  if [ ! \$? -eq 0 ]; then
    echo "Error compiling program.  Exiting..."
    return 1
  fi

  # Everything's OK.
  echo "Successfully compiled \${I2G_MPI_APPLICATION}"

  return 0
}
EOF

cat > job.jdl << EOF
[
Executable = "/usr/bin/mpi-start";
CpuNumber = 2;
Arguments  = "-t openmpi -pre hooks.sh -- cpi";
InputSandbox = {"cpi.c", "hooks.sh"};
OutputSandbox = {"std.out", "std.err"};
StdOutput = "std.out";
StdError = "std.err";
OutputSandboxBaseDestUri = "gsiftp://localhost";
]
EOF

submit_and_get_output job.jdl

echo
echo "### Submit Open MP parallel job, whole node!"

cat > omp.c << EOF
#include <omp.h>
#include <stdio.h>
#include <stdlib.h>
#define CHUNKSIZE   10
#define N       100

int main (int argc, char *argv[]) {
    int nthreads, tid, i, chunk, k;
    float a[N], b[N], c[N];

    /* Some initializations */
    for (i=0; i < N; i++)
        a[i] = b[i] = i * 1.0;
    chunk = CHUNKSIZE;

    #pragma omp parallel shared(a,b,c,nthreads,chunk) private(i,tid)
    {
        tid = omp_get_thread_num();
        if (tid == 0)
        {
            nthreads = omp_get_num_threads();
            printf("Number of threads = %d\n", nthreads);
        }
        fprintf(stderr, "Thread %d starting...\n",tid);

        #pragma omp for schedule(dynamic,chunk)
        for (i=0; i<N; i++)
        {
            c[i] = a[i] + b[i];
            //fprintf(stderr, "Thread %d: c[%d]= %f\n",tid,i,c[i]);
        }
        fprintf(stderr, "Thread %d stopping...\n",tid);
    }  /* end of parallel section */
    return 0;
}
EOF

cat > hooks.sh << EOF
pre_run_hook () {
  # Compile the program.
  echo "Compiling \${I2G_MPI_APPLICATION}"

  # Actually compile the program.
  cmd="gcc -fopenmp -o \${I2G_MPI_APPLICATION} \${I2G_MPI_APPLICATION}.c"
  \$cmd
  if [ ! \$? -eq 0 ]; then
    echo "Error compiling program.  Exiting..."
    return 1
  fi

  # Everything's OK.
  echo "Successfully compiled \${I2G_MPI_APPLICATION}"

  return 0
}
EOF


cat > job.jdl << EOF
[
Executable = "/usr/bin/mpi-start";
WholeNodes = True;
HostNumber = 1;
Arguments  = "-t dummy -pre hooks.sh -- omp";
InputSandbox = {"omp.c", "hooks.sh"};
OutputSandbox = {"std.out", "std.err"};
StdOutput = "std.out";
StdError = "std.err";
OutputSandboxBaseDestUri = "gsiftp://localhost";
]
EOF

submit_and_get_output job.jdl

# end!
popd
rm -rf $mydir


