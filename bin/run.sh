#!/bin/bash

set -e

for var in AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY RESTIC_PASSWORD RESTIC_REPOSITORY; do
	eval [[ -z \${$var+1} ]] && {
		>&2 echo "ERROR: Missing required environment variable: $var"
		exit 1
	}
done

if ! restic snapshots; then
	time restic init
fi

time pg_dump.sh

time restic forget \
	--prune \
	--keep-last="${RESTIC_KEEP_LAST:-5}" \
	--keep-daily="${RESTIC_KEEP_DAILY:-7}" \
	--keep-weekly="${RESTIC_KEEP_WEEKLY:-4}"

time restic check

echo 'Finished.'
