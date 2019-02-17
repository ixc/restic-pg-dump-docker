#!/bin/bash

set -e

setup.sh

echo "Pruning old snapshots"
while ! restic forget \
		--prune \
		--keep-hourly="${RESTIC_KEEP_HOURLY:-24}" \
		--keep-daily="${RESTIC_KEEP_DAILY:-7}" \
		--keep-weekly="${RESTIC_KEEP_WEEKLY:-4}" \
		--keep-monthly="${RESTIC_KEEP_MONTHLY:-12}"; do
	echo "Sleeping for 1 second before retry..."
	sleep 1
done

restic check --no-lock

echo 'Finished prune successfully'
