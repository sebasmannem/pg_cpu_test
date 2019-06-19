#!/bin/bash
set -e
PGDATA=${PGDATA:-/var/lib/pgsql/11/data}
PGCONF=${PGCONF:-/host/conf.d}
PCL_PARALLEL=${PCL_PARALLEL:-10}
mkdir -p "${PGDATA}"
chown -R postgres: "${PGDATA}"
PCL_LOGDIR=${PCL_LOGDIR:-/host/logs/$(date +%s)}
mkdir -p "${PCL_LOGDIR}"
chmod 777 "${PCL_LOGDIR}"
su - postgres bash -c "initdb -D ${PGDATA}"
if [ -d "${PGCONF}" ]; then
	PGCONFDEST="${PGDATA}/"$(basename "${PGCONF}")
	cp -av "${PGCONF}" "${PGCONFDEST}"
	cp -av "${PGCONF}" "${PCL_LOGDIR}"
	chown -R postgres: "${PGCONFDEST}"
	echo "include_dir '${PGCONFDEST}'" >> "${PGDATA}/postgresql.conf"
fi
echo "max_connections = $((PCL_PARALLEL+20))" >> "${PGDATA}/postgresql.conf"
su - postgres bash -c "pg_ctl start -D ${PGDATA} && { until pg_isready; do sleep 1; done ; }"
set > "${PCL_LOGDIR}/env"
for PCL_TYPE in empty simple temp_read temp_write read write; do
	for PCL_MODE in direct prepared transactional prepared_transactional; do
		[ "${PCL_TYPE}" = 'empty' -a "${PCL_MODE}" = 'direct' -o "${PCL_MODE}" = 'prepared' ] && continue
		CMD="/pg_cpu_load_c7"
		CMD+=" --parallel ${PCL_PARALLEL:-10}"
		CMD+=" --num_secs ${PCL_NUMSEC:-600}"
		CMD+=" --query_type ${PCL_TYPE}"
		CMD+=" --statement_type ${PCL_MODE}"
		LOGFILE="${PCL_LOGDIR}/pg_cpu_load_${PCL_TYPE}_${PCL_MODE}.log"
		echo "${LOGFILE}"
		su - postgres bash -c "${CMD}" >> "${LOGFILE}" 2>&1
	done
done
su - postgres bash -c 'pg_ctl stop'
