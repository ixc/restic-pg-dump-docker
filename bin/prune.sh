#!/bin/bash

set -e

setup.sh

echo "Pruning old snapshots"
while ! restic prune; do
	echo "Sleeping for 1 second before retry..."
	sleep 1
done

restic check --no-lock

echo 'Finished prune successfully'
