#!/bin/bash
#set -e
/sar.sh &
SARPID=$!
PGDATA=${PGDATA:-/var/lib/pgsql/11/data}
PGWAL=${PGWAL:-"${PGDATA}/pg_wal"}
PGCONF=${PGCONF:-/host/conf.d}
PCL_PARALLEL=${PCL_PARALLEL:-10}
PCL_POOLER=${PCL_POOLER:-postgres}

PCL_TYPES=${PCL_TYPES:-"empty simple temp_read temp_write read write"}
read -ra ARR_PCL_TYPES <<< "${PCL_TYPES}"
PCL_MODES=${PCL_MODES:-"direct prepared transactional prepared_transactional"}
read -ra ARR_PCL_MODES <<< "${PCL_MODES}"

mkdir -p "${PGDATA}"
chown -R postgres: "${PGDATA}"
if [ "${PGWAL}" != "${PGDATA}/pg_wal" ]; then
  PGWALOPTS=" --waldir=${PGWAL}"
else
  PGWALOPTS=""
fi
PCL_LOGDIR=${PCL_LOGDIR:-/host/logs/${PCL_PARALLEL}}
mkdir -p "${PCL_LOGDIR}"
chmod 777 "${PCL_LOGDIR}"
su - postgres bash -c "initdb -D ${PGDATA} ${PGWALOPTS}"
if [ -d "${PGCONF}" ]; then
	PGCONFDEST="${PGDATA}/"$(basename "${PGCONF}")
	cp -av "${PGCONF}" "${PGCONFDEST}"
	cp -av "${PGCONF}" "${PCL_LOGDIR}"
	chown -R postgres: "${PGCONFDEST}"
	echo "include_dir '${PGCONFDEST}'" >> "${PGDATA}/postgresql.conf"
fi
if [ "${PCL_POOLER}" = "pgbouncer" ]; then
  cp /etc/pgbouncer/pgbouncer{,_run}.ini
  BOUNCERCONF=/etc/pgbouncer/pgbouncer_run.ini
  sed -i 's/auth_type *=.*/auth_type = any/
          s/max_client_conn *=.*/max_client_conn = '$((PCL_PARALLEL+10))'/
          s/;?max_db_connections *=.*/max_db_connections = 90/' ${BOUNCERCONF}
  sed -ie "/\[databases\]/a\\
postgres = host=127.0.0.1 user=postgres password=p" ${BOUNCERCONF}
  echo "Starting PGBouncer"
  su - pgbouncer bash -c "/usr/bin/pgbouncer ${BOUNCERCONF} 2>&1" >> "${PCL_LOGDIR}/pgbouncer.log" &
  export PGPORT=6432
elif [ "${PCL_POOLER}" = "pgpool" ]; then
  cp /etc/pgpool-II-11/pgpool.conf{.sample,}
  PGPOOLCONF=/etc/pgpool-II-11/pgpool.conf
  PGPOOLMULTIPLIER=$((PCL_PARALLEL/99))
  [ "${PGPOOLMULTIPLIER}" -lt 2 ] && PGPOOLMULTIPLIER=2
  sed -i "s/listen_addresses *=.*/listen_addresses = '127.0.0.1'/
          s/pool_passwd *=.*/pool_passwd = ''/
          s/listen_backlog_multiplier *=.*/listen_backlog_multiplier = ${PGPOOLMULTIPLIER}/
          s/connection_cache *=.*/connection_cache = on/
          s/num_init_children *=.*/num_init_children = 100/" ${PGPOOLCONF}
  echo "Starting PGPool-II"
  su - postgres bash -c "/usr/pgpool-11/bin/pgpool -f /etc/pgpool-II-11/pgpool.conf  -n -D" &
  export PGPORT=9999
else
  echo "max_connections = $((PCL_PARALLEL+20))" >> "${PGDATA}/postgresql.conf"
  export PGPORT=5432
fi
su - postgres bash -c "pg_ctl start -D ${PGDATA} && { until pg_isready; do sleep 1; done ; }"
su - postgres bash -c "psql -tc \"select name||'='''||setting||'''''' from pg_settings;\"" > "${PCL_LOGDIR}/pg_config"

set > "${PCL_LOGDIR}/env"
set +e
for PCL_TYPE in "${ARR_PCL_TYPES[@]}"; do
	for PCL_MODE in "${ARR_PCL_MODES[@]}"; do
		[ "${PCL_TYPE}" = 'empty' -a \( "${PCL_MODE}" = 'direct' -o "${PCL_MODE}" = 'prepared' \) ] && continue
		LOGFILE="${PCL_LOGDIR}/pg_cpu_load_${PCL_TYPE}_${PCL_MODE}.log"
		[ -f "${LOGFILE}" ] && continue
		CMD="/pg_cpu_load_c7"
		CMD+=" --parallel ${PCL_PARALLEL:-10}"
		CMD+=" --num_secs ${PCL_NUMSEC:-600}"
		CMD+=" --query_type ${PCL_TYPE}"
		CMD+=" --statement_type ${PCL_MODE}"
		CMD+=" --port ${PGPORT}"
		echo "${LOGFILE}"
		su - postgres bash -c "${CMD}" >> "${LOGFILE}" 2>&1
	done
done
su - postgres bash -c "pg_ctl stop -D ${PGDATA}"
kill ${SARPID} > /dev/null 2>&1
sar -A >> "${PCL_LOGDIR}/sar"
cp --backup=t /var/log/sa/sa* "${PCL_LOGDIR}/"
