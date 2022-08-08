#!/bin/bash

set -e

ok=1
for var in AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY RESTIC_PASSWORD RESTIC_REPOSITORY; do
	eval [[ -z \${$var+1} ]] && {
		>&2 echo "ERROR: Missing required environment variable: $var"
		ok=
	}
done
[ $ok ] || exit 1

if ! restic unlock; then
	restic init
fi
