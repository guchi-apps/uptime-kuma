#!/bin/sh
set -e

DB_PATH="/app/data/kuma.db"

restore_if_missing() {
    if [ -f "$DB_PATH" ]; then
        return 0
    fi
    if [ -z "${BACKUP_UPLOAD_URL:-}" ] || [ -z "${BACKUP_UPLOAD_TOKEN:-}" ]; then
        echo "[restore] BACKUP_UPLOAD_URL / BACKUP_UPLOAD_TOKEN 未設定のため復元をスキップ"
        return 0
    fi

    mkdir -p "$(dirname "$DB_PATH")"
    tmpfile="$(mktemp /tmp/kuma-restore.XXXXXX.db)"

    echo "[restore] 最新バックアップの取得を試みます"
    if curl -fsS --max-time 30 \
        -H "Authorization: Bearer $BACKUP_UPLOAD_TOKEN" \
        "$BACKUP_UPLOAD_URL" -o "$tmpfile"; then
        if head -c 16 "$tmpfile" | grep -qa "SQLite format 3"; then
            mv "$tmpfile" "$DB_PATH"
            echo "[restore] 復元成功: $DB_PATH"
        else
            echo "[restore] 取得したファイルがSQLite形式ではないため復元しません"
            rm -f "$tmpfile"
        fi
    else
        echo "[restore] バックアップの取得に失敗しました（まだバックアップが無い可能性があります）"
        rm -f "$tmpfile"
    fi
}

restore_if_missing

/usr/local/bin/backup-push.sh &

exec extra/entrypoint.sh "$@"
