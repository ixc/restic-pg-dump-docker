#!/bin/bash

set -e

setup.sh

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
			echo "Forgetting old snapshots"
			while ! restic forget \
					--keep-hourly="${RESTIC_KEEP_HOURLY:-24}" \
					--keep-daily="${RESTIC_KEEP_DAILY:-7}" \
					--keep-weekly="${RESTIC_KEEP_WEEKLY:-4}" \
					--keep-monthly="${RESTIC_KEEP_MONTHLY:-12}"; do
				echo "Sleeping for 1 second before retry..."
				sleep 1
			done

			restic check --no-lock

			echo 'Finished backup successfully'

			exit 0
		}
	done

	echo "Dumping database cluster $i: $PGUSER@$PGHOST:$PGPORT"

	# Wait for PostgreSQL to become available.
	COUNT=0
	until psql -l > /dev/null 2>&1; do
		if [[ "$COUNT" == 0 ]]; then
			echo "Waiting for PostgreSQL to become available..."
		fi
		(( COUNT += 1 ))
		sleep 1
	done
	if (( COUNT > 0 )); then
		echo "Waited $COUNT seconds."
	fi

	mkdir -p "/pg_dump"

	# Dump individual databases directly to restic repository.
	DBLIST=$(psql -d postgres -q -t -c "SELECT datname FROM pg_database WHERE datname NOT IN ('postgres', 'rdsadmin', 'template0', 'template1')")
	for dbname in $DBLIST; do
		echo "Dumping database '$dbname'"
		pg_dump --file="/pg_dump/$dbname.sql" --no-owner --no-privileges --dbname="$dbname" || true  # Ignore failures
	done

	# echo "Dumping global objects for '$PGHOST'"
	# pg_dumpall --file="/pg_dump/!globals.sql" --globals-only

	echo "Sending database dumps to S3"
	while ! restic backup --host "$HOSTNAME" "/pg_dump"; do
		echo "Sleeping for 1 second before retry..."
		sleep 1
	done

	echo 'Finished sending database dumps to S3'

	rm -rf "/pg_dump"
done
