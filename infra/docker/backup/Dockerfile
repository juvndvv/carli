FROM postgres:18

RUN apt-get update \
    && apt-get install -y --no-install-recommends restic tzdata ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY --chmod=0755 backup.sh /usr/local/bin/backup.sh

ENV TZ=Europe/Madrid \
    BACKUP_DIR=/backups \
    BACKUP_TIME=03:00 \
    BACKUP_KEEP_DAILY=7 \
    BACKUP_KEEP_WEEKLY=4 \
    BACKUP_KEEP_MONTHLY=12

ENTRYPOINT ["backup.sh"]
CMD ["schedule"]
