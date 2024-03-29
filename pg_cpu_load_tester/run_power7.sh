#!/bin/bash
#set -e
#/sar.sh &
#SARPID=$!
export PGDATA=${PGDATA:-/var/lib/pgsql/11/data}
PGWAL=${PGWAL:-"${PGDATA}/pg_wal"}
PGCONF=${PGCONF:-/host/conf.d}
PCL_PARALLEL=${PCL_PARALLEL:-10}

PCL_TYPES=${PCL_TYPES:-"empty simple temp_read temp_write read write"}
read -ra ARR_PCL_TYPES <<< "${PCL_TYPES}"
PCL_MODES=${PCL_MODES:-"direct prepared transactional prepared_transactional"}
read -ra ARR_PCL_MODES <<< "${PCL_MODES}"

pg_ctl stop || echo "Postgres was not running from $PGDATA"
rm -rf "${PGDATA}"
mkdir -p "${PGDATA}"
#sudo chown -R postgres: "${PGDATA}"
if [ "${PGWAL}" != "${PGDATA}/pg_wal" ]; then
  PGWALOPTS=" --waldir=${PGWAL}"
  rm -rf "${PGWAL}"
  mkdir -p "${PGWAL}"
else
  PGWALOPTS=""
fi
PCL_LOGDIR=${PCL_LOGDIR:-/host/logs/${PCL_PARALLEL}}
mkdir -p "${PCL_LOGDIR}"
chmod 777 "${PCL_LOGDIR}"
initdb -D ${PGDATA} ${PGWALOPTS}
if [ -d "${PGCONF}" ]; then
	PGCONFDEST="${PGDATA}/"$(basename "${PGCONF}")
	cp -av "${PGCONF}" "${PGCONFDEST}"
	cp -av "${PGCONF}" "${PCL_LOGDIR}"
	#chown -R postgres: "${PGCONFDEST}"
	echo "include_dir '${PGCONFDEST}'" >> "${PGDATA}/postgresql.conf"
fi
echo "max_connections = $((PCL_PARALLEL+20))" >> "${PGDATA}/postgresql.conf"
pg_ctl start
until pg_isready; do 
  sleep 1
done
psql -tc "select name||'='''||setting||'''''' from pg_settings;" > "${PCL_LOGDIR}/pg_config"
set > "${PCL_LOGDIR}/env"
set +e
#exit 1
for PCL_TYPE in "${ARR_PCL_TYPES[@]}"; do
	for PCL_MODE in "${ARR_PCL_MODES[@]}"; do
		[ "${PCL_TYPE}" = 'empty' -a \( "${PCL_MODE}" = 'direct' -o "${PCL_MODE}" = 'prepared' \) ] && continue
		LOGFILE="${PCL_LOGDIR}/pg_cpu_load_${PCL_TYPE}_${PCL_MODE}.log"
		[ -f "${LOGFILE}" ] && continue
		CMD="./pg_cpu_load_p7"
		CMD+=" --parallel ${PCL_PARALLEL:-10}"
		CMD+=" --num_secs ${PCL_NUMSEC:-600}"
		CMD+=" --query_type ${PCL_TYPE}"
		CMD+=" --statement_type ${PCL_MODE}"
		echo "${LOGFILE}"
		bash -c "${CMD}" >> "${LOGFILE}" 2>&1
	done
done
pg_ctl stop -D ${PGDATA}
#kill ${SARPID} > /dev/null 2>&1
#sar -A >> "${PCL_LOGDIR}/sar"
#cp --backup=t /var/log/sa/sa* "${PCL_LOGDIR}/"
