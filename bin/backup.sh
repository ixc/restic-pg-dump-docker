#!/bin/bash

set -e

PG_DUMP_DIR="${PG_DUMP_DIR:-/pg_dump}"

trim_whitespace() {
	local value="$1"
	value="${value#"${value%%[![:space:]]*}"}"
	value="${value%"${value##*[![:space:]]}"}"
	printf '%s' "$value"
}

sql_quote_literal() {
	local value="$1"
	value="${value//\'/\'\'}"
	printf "'%s'" "$value"
}

cleanup_dump_files() {
	[[ -d "$PG_DUMP_DIR" ]] || return 0
	find "$PG_DUMP_DIR" -maxdepth 1 -type f -name '*.sql' -delete
}

setup.sh

for i in {1..5}; do
	export HOSTNAME_VAR="HOSTNAME_$i"
	export PGHOST_VAR="PGHOST_$i"
	export PGPASSWORD_VAR="PGPASSWORD_$i"
	export PGPORT_VAR="PGPORT_$i"
	export PGUSER_VAR="PGUSER_$i"

	export HOST="${!HOSTNAME_VAR:-${!PGHOST_VAR}}"
	export PGHOST="${!PGHOST_VAR}"
	export PGPASSWORD="${!PGPASSWORD_VAR}"
	export PGPORT="${!PGPORT_VAR:-5432}"
	export PGUSER="${!PGUSER_VAR:-postgres}"

	# No more databases.
	for var in PGHOST PGUSER; do
		[[ -z "${!var}" ]] && {
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

	mkdir -p "$PG_DUMP_DIR"

	# Dump individual databases directly to restic repository.
	export EXCLUDED_DATABASES_VAR="EXCLUDED_DATABASES_$i"
	cluster_excluded_raw="$(trim_whitespace "${!EXCLUDED_DATABASES_VAR:-}")"
	if [[ -n "$cluster_excluded_raw" ]]; then
		effective_excluded_raw="$cluster_excluded_raw"
	else
		effective_excluded_raw="${EXCLUDED_DATABASES:-}"
	fi

	exclusions=(postgres rdsadmin template0 template1)
	IFS=',' read -r -a extra_exclusions <<< "$effective_excluded_raw"
	for raw_name in "${extra_exclusions[@]}"; do
		trimmed_name="$(trim_whitespace "$raw_name")"
		[[ -z "$trimmed_name" ]] && continue
		exclusions+=("$trimmed_name")
	done
	declare -A excluded_lookup=()
	for name in "${exclusions[@]}"; do
		excluded_lookup["$name"]=1
	done

	sql_not_in_list=""
	for name in "${exclusions[@]}"; do
		quoted_name="$(sql_quote_literal "$name")"
		if [[ -n "$sql_not_in_list" ]]; then
			sql_not_in_list+=", "
		fi
		sql_not_in_list+="$quoted_name"
	done

	query="SELECT datname FROM pg_database WHERE datname NOT IN ($sql_not_in_list)"
	DBLIST=$(psql -d postgres -A -q -t -c "$query")
	while IFS= read -r dbname; do
		[[ -z "$dbname" ]] && continue
		[[ -n "${excluded_lookup[$dbname]:-}" ]] && continue
		echo "Dumping database '$dbname'"
		pg_dump --file="$PG_DUMP_DIR/$dbname.sql" --no-owner --no-privileges --dbname="$dbname" || true  # Ignore failures
	done <<< "$DBLIST"

	# echo "Dumping global objects for '$PGHOST'"
	# pg_dumpall --file="/pg_dump/!globals.sql" --globals-only

	echo "Sending database dumps to S3"
	while ! restic backup --host "$HOST" "$PG_DUMP_DIR"; do
		echo "Sleeping for 10 seconds before retry..."
		sleep 10
	done

	echo 'Finished sending database dumps to S3'

	cleanup_dump_files
done
