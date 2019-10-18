#!/bin/bash

set -e

setup.sh

echo "Forgetting old snapshots"
while ! restic forget \
		--compact \
		--keep-hourly="${RESTIC_KEEP_HOURLY:-24}" \
		--keep-daily="${RESTIC_KEEP_DAILY:-7}" \
		--keep-weekly="${RESTIC_KEEP_WEEKLY:-4}" \
		--keep-monthly="${RESTIC_KEEP_MONTHLY:-12}"; do
	echo "Sleeping for 10 seconds before retry..."
	sleep 10
done

echo "Pruning old snapshots"
while ! restic prune; do
	echo "Sleeping for 10 seconds before retry..."
	sleep 10
done

# Test repository and remove unwanted cache.
restic check --no-lock
rm -rf /tmp/restic-check-cache-*

echo 'Finished prune successfully'
