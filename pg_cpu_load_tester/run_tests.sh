#!/bin/bash

# Just an example of running the tests
export PCL_TYPES=empty
export PCL_MODES=transactional
export PCL_NUMSEC=60
for PCL_PARALLEL in 5000 10000 ; do export PCL_PARALLEL; docker run -ti --rm -v $PWD:/host -e PCL_PARALLEL -e PCL_TYPES -e PCL_MODES -e PCL_NUMSEC --name pg_cpu_load_tester pg_cpu_load_tester:latest; done
