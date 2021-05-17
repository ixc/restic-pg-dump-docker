#!/bin/bash

set -e

setup.sh

max_pg_wait_count=120
work_area=${PGDUMP_BACKUP_AREA:-/pg_dump}

for i in {1..5}; do
	export HOSTNAME_VAR="HOSTNAME_$i"
	export PGHOST_VAR="PGHOST_$i"
	export PGPASSWORD_VAR="PGPASSWORD_$i"
	export PGPORT_VAR="PGPORT_$i"
	export PGUSER_VAR="PGUSER_$i"

	export HOSTNAME="${!HOSTNAME_VAR:-$PGHOST_$i}"
	export PGHOST="${!PGHOST_VAR}"
	export PGPASSWORD="${!PGPASSWORD_VAR}"
	export PGPORT="${!PGPORT_VAR:-5432}"
	export PGUSER="${!PGUSER_VAR}"

	# No more databases.
	for var in PGHOST PGUSER; do
		[[ -z "${!var}" ]] && {
			echo 'Finished backup successfully'
			exit 0
		}
	done

	echo "Dumping database cluster $i: $PGUSER@$PGHOST:$PGPORT"

	# Wait for PostgreSQL to become available.
	count=0
	until psql -l > /dev/null 2>&1; do
		if [[ "$count" == 0 ]]; then
			echo "Waiting for PostgreSQL to become available..."
		fi
		(( count += 1 ))
		[ $count -lt $max_pg_wait_count ] || break
		sleep 1
	done
	if (( count > 0 )); then
		echo "Waited $count seconds."
		psql -l > /dev/null 2>&1 || {
			echo "PostgreSQL still not available, trying next backup."
			continue
		}
	fi

	mkdir "$work_area" || exit 1

	# Dump individual databases directly to restic repository.
	dblist=$(psql -d postgres -q -t -c "SELECT datname FROM pg_database WHERE datname NOT IN ('postgres', 'rdsadmin', 'template0', 'template1')")
	for dbname in $dblist; do
		echo "Dumping database '$dbname'"
		pg_dump --file="$work_area/$dbname.sql" --no-owner --no-privileges --dbname="$dbname" || true  # Ignore failures
	done

	# echo "Dumping global objects for '$PGHOST'"
	# pg_dumpall --file="$work_area/!globals.sql" --globals-only

	echo "Sending database dumps to S3"
	while ! restic backup --host "$HOSTNAME" "$work_area"; do
		echo "Sleeping for 10 seconds before retry..."
		sleep 10
	done

	echo 'Finished sending database dumps to S3'

	rm -rf "$work_area"
done
