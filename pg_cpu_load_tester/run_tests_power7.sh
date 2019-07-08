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
    TEST_LOGS_DIR="./logs.${PCL_SYSTEMNAME}/logs.${TESTNAME}"
    mkdir -p "${TEST_LOGS_DIR}"

    for PCL_PARALLEL in 1 2 5 10 20 50 100 200 500 1000 ; do
      export PCL_LOGDIR=${TEST_LOGS_DIR}/${PCL_PARALLEL}
      echo "Running $TESTNAME with $PCL_PARALLEL threads"
      export PCL_PARALLEL
      ./run_power7.sh
    done
}

# Just an example of running the tests
export PCL_TYPES="empty simple read write"
export PCL_MODES="direct prepared transactional prepared_transactional"
export PCL_NUMSEC=600
export PCL_SYSTEMNAME=${PCL_SYSTEMNAME:-unknown}
export TMPFS_DIR=${TMPFS_DIR:-/run/user/$(id -u)/pg_cpu_load_tester}
export SSD_DIR=${SSD_DIR:-${HOME}/pg_cpu_load_tester}
export PGPORT=${PGPORT:-5432}
export PGDATABASE=postgres
export PGUSER=$(id -un)

pg_ctl stop -D "$SSD_DIR/pg_data" || echo "Postgres was not running from $SSD_DIR"
pg_ctl stop -D "$TMPFS_DIR/pg_data" || echo "Postgres was not running from $TMPFS_DIR"

export PGDATA=${SSD_DIR}/pg_data
echo "port = $PGPORT" > conf.d/network.conf

echo 'fsync = on' > conf.d/fsync.conf
run_tests "baseline"

echo 'fsync = off' > conf.d/fsync.conf
run_tests "no_fsync"
echo 'fsync = on' > conf.d/fsync.conf

exit

export PGDATA=${TMPFS_DIR}/pg_data
run_tests "tmpfs" "--tmpfs /pgsql"
export PGDATA=${SSD_DIR}/pg_data

export PGWAL=${TMPFS_DIR}/pg_wal
run_tests "wal_tmpfs" "--tmpfs /pgsql"
unset PGWAL
export PGWAL

export PGDATA=${TMPFS_DIR}/pg_data
echo 'fsync = off' > conf.d/fsync.conf
run_tests "no_fsync_tmpfs" "--tmpfs /pgsql"
echo 'fsync = on' > conf.d/fsync.conf
export PGDATA=${SSD_DIR}/pg_data
