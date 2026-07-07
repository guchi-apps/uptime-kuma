#!/bin/sh
set -e

/usr/local/bin/backup-push.sh &

exec extra/entrypoint.sh "$@"
