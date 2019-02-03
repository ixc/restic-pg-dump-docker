#!/bin/bash

set -e

for i in {0..10}; do
	export HOSTNAME="${HOSTNAME_$i:-$PGHOST_$i}"
	export PGHOST="$PGHOST_$i"
	export PGPORT="${PGPORT_$i:-5432}"
	export PGUSER="$PGUSER_$i"

	# Wait for PostgreSQL to become available.
	COUNT=0
	until psql -l > /dev/null 2>&1; do
		if [[ "$COUNT" == 0 ]]; then
			echo "Waiting for PostgreSQL ($PGUSER@$PGHOST:$PGPORT)..."
		fi
		(( COUNT += 1 ))
		sleep 1
	done
	if (( COUNT > 0 )); then
		echo "Waited $COUNT seconds for PostgreSQL."
	fi

	mkdir -p "/pg_dump"

	# Dump individual databases directly to restic repository.
	DBLIST=$(psql -d postgres -q -t -c "SELECT datname FROM pg_database WHERE datname NOT IN ('postgres', 'rdsadmin', 'template0', 'template1')")
	for dbname in $DBLIST; do
		echo "Dumping database '$dbname'"
		time pg_dump --file="/pg_dump/$dbname.sql" --no-owner --no-privileges --dbname="$dbname" || true  # Ignore failures
	done

	# echo "Dumping global objects for '$PGHOST'"
	# time pg_dumpall --file="/pg_dump/!globals.sql" --globals-only

	echo "Sending database dumps to S3"
	time restic backup --host "$HOSTNAME" "/pg_dump"

	rm -rf "/pg_dump"
done
