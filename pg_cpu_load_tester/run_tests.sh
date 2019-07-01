#!/bin/bash
set -e

function cleanup_old_dir() {
  DIR="${1}"
  if [ -L "${DIR}" ]; then
    rm "${DIR}"
  elif [ -e "${DIR}" ]; then
    mv "${DIR}"{,.$(date +%s)}
  fi
}

function run_tests() {
    TESTNAME=$1
    DOCKEREXTRAOPTS="$2"
    cleanup_old_dir "${TESTNAME}"
    mkdir "./logs.${TESTNAME}"
    cleanup_old_dir "logs"

    ln -s "./logs.${TESTNAME}" logs
    for PCL_PARALLEL in 1 2 5 10 20 50 100 200 500 1000 ; do
      echo "Running $TESTNAME with $PCL_PARALLEL threads"
      export PCL_PARALLEL
      docker run -ti --rm -v $PWD:/host -e PCL_PARALLEL -e PCL_TYPES -e PCL_MODES -e PCL_NUMSEC -e PGDATA --name pg_cpu_load_tester $DOCKEREXTRAOPTS pg_cpu_load_tester:latest
    done
}

# Just an example of running the tests
export PCL_TYPES="empty simple read write"
export PCL_MODES="transactional prepared_transactional"
export PCL_NUMSEC=600

docker rm pg_cpu_load_tester || true

echo 'fsync = on' > conf.d/fsync.conf
run_tests "baseline"

echo 'fsync = off' > conf.d/fsync.conf
run_tests "no_fsync"
echo 'fsync = on' > conf.d/fsync.conf

export PGDATA=/pgsql
run_tests "tmpfs" "--mount type=tmpfs,destination=/pgsql"
unset PDATA
export PGDATA

export PGWAL=/pgsql/pg_wal
run_tests "wal_tmpfs" "--mount type=tmpfs,destination=/pgsql"
unset PGWAL
export PGWAL

export PGDATA=/pgsql
echo 'fsync = off' > conf.d/fsync.conf
run_tests "no_fsync_tmpfs" "--mount type=tmpfs,destination=/pgsql"
echo 'fsync = on' > conf.d/fsync.conf
unset PDATA
export PGDATA
