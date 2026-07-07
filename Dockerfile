FROM louislam/uptime-kuma:1

RUN apt-get update \
    && apt-get install -y --no-install-recommends curl ca-certificates sqlite3 \
    && rm -rf /var/lib/apt/lists/*

COPY docker/backup-push.sh /usr/local/bin/backup-push.sh
COPY docker/entrypoint-wrapper.sh /usr/local/bin/entrypoint-wrapper.sh
RUN chmod +x /usr/local/bin/backup-push.sh /usr/local/bin/entrypoint-wrapper.sh

ENTRYPOINT ["/usr/bin/dumb-init", "--", "/usr/local/bin/entrypoint-wrapper.sh"]
CMD ["node", "server/server.js"]
