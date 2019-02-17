#!/bin/bash

set -e

setup.sh

echo "Pruning old snapshots"
while ! restic prune; do
	echo "Sleeping for 10 seconds before retry..."
	sleep 10
done

restic check --no-lock

echo 'Finished prune successfully'
