#!/bin/bash

set -e

dockerize -template /opt/restic-pg-dump/crontab.tmpl:/var/spool/cron/crontabs/root

crond -f -L /dev/stdout
