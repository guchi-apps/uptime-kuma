#!/bin/sh
set -u

DB_PATH="/app/data/kuma.db"
INTERVAL="${BACKUP_INTERVAL_SECONDS:-86400}"

do_backup() {
    if [ -z "${BACKUP_UPLOAD_URL:-}" ] || [ -z "${BACKUP_UPLOAD_TOKEN:-}" ]; then
        echo "[backup-push] BACKUP_UPLOAD_URL / BACKUP_UPLOAD_TOKEN 未設定のためスキップ"
        return 0
    fi
    if [ ! -f "$DB_PATH" ]; then
        echo "[backup-push] $DB_PATH が存在しないためスキップ"
        return 0
    fi

    tmpfile="$(mktemp /tmp/kuma-backup.XXXXXX.db)"

    if ! sqlite3 "$DB_PATH" ".backup '$tmpfile'"; then
        echo "[backup-push] sqlite3 backupに失敗"
        rm -f "$tmpfile"
        return 0
    fi

    if curl -fsS -X POST --max-time 60 \
        -H "Authorization: Bearer $BACKUP_UPLOAD_TOKEN" \
        --data-binary "@$tmpfile" \
        "$BACKUP_UPLOAD_URL" > /dev/null; then
        echo "[backup-push] アップロード成功: $(date -Is)"
    else
        echo "[backup-push] アップロード失敗: $(date -Is)"
    fi

    rm -f "$tmpfile"
}

wait_for_db() {
    max_wait=300
    waited=0
    while [ ! -f "$DB_PATH" ] && [ "$waited" -lt "$max_wait" ]; do
        sleep 5
        waited=$((waited + 5))
    done
}

while true; do
    wait_for_db
    do_backup
    sleep "$INTERVAL"
done
