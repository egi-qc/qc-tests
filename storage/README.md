Storage Management Appliances
=============================

This category covers Storage Elements products (DPM, dCache, StoRM, ARC-SE,...)

# SRM compliance

Execute tests with a SRM client that:
* pings the SRM interface
* creates a directory
* puts a file in that directory using different transfer methods (gsiftp, http)
* gets back the file
* copy file
* moves file
* removes file
* deletes files and directory

## How to test

See srm-test.sh for a sample test suite using the StoRM SRM client.

# lcg-utils test

Perform various operations using the lcg-utils commands that use the SRM interface.

## How to test

See lcg-test.sh for a sample test

# WebDAV 

If the SE supports WebDAV, execute the following operations:
* create directory
* list directory
* put file
* get file
* copy file
* move file
* remove file
* remove directory

## How to test 

See webdav-test.sh for sample test.
