#!/bin/bash
set -e
chmod +x /builder.sh /run.sh /pg_cpu_load_c7

yum install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm
yum install -y postgresql11-server
echo 'export PGDATA=/var/lib/pgsql/11/data
export PGDATABASE=postgres
export PGHOST=127.0.0.1
export PGUSER=postgres
export PGPORT=5432
export PGSSLMODE=disable

export PATH=/usr/pgsql-11/bin:$PATH' > ~postgres/.bash_postgres
echo '. ~/.bash_postgres' >> ~postgres/.bash_profile

