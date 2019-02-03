#!/bin/bash

set -e

# Get first host from environment variables with no counter.
export PGHOST_1="${PGHOST_1:-${PGHOST:-postgres}}"
export PGPORT_1="${PGPORT_1:-${PGPORT:-5432}}"
export PGUSER_1="${PGUSER_1:-${PGUSER:-postgres}}"
