#!/bin/bash

# Just an example of running the tests
export PCL_TYPES=empty
export PCL_MODES=transactional
export PCL_NUMSEC=600
export PGDATA=/pgsql
for PCL_PARALLEL in 1 2 5 10 20 50 100 200 500 1000 2000 ; do
  export PCL_PARALLEL
  docker run -ti --rm -v $PWD:/host -e PCL_PARALLEL -e PCL_TYPES -e PCL_MODES -e PCL_NUMSEC -e PGDATA --name pg_cpu_load_tester --mount type=tmpfs,destination=/pgsql pg_cpu_load_tester:latest
done
