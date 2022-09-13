#!/bin/bash

set -e

# Get config for first database from environment variables with no counter.
export PGHOST_1="${PGHOST_1:-${PGHOST:-postgres}}"
export PGPASSWORD_1="${PGPASSWORD_1:-$PGPASSWORD}"
export PGPORT_1="${PGPORT_1:-${PGPORT:-5432}}"
export PGUSER_1="${PGUSER_1:-${PGUSER:-postgres}}"

exec "$@"
