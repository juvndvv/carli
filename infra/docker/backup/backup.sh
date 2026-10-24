#!/bin/sh
set -eu

: "${PGHOST:=postgres}"
: "${PGPORT:=5432}"
: "${PGDATABASE:=personal}"
: "${PGUSER:=personal}"
export PGHOST PGPORT PGDATABASE PGUSER

log() {
    printf '%s [backup] %s\n' "$(date '+%Y-%m-%d %H:%M:%S %Z')" "$*"
}

prune() {
    directory="$1"
    keep="$2"
    find "$directory" -maxdepth 1 -type f -name '*.dump' -printf '%f\n' \
        | sort -r \
        | tail -n "+$((keep + 1))" \
        | while read -r file; do
            rm -f "$directory/$file"
            log "pruned $directory/$file"
        done
}

push_to_restic() {
    if [ -z "${RESTIC_REPOSITORY:-}" ]; then
        return 0
    fi
    if ! restic cat config >/dev/null 2>&1; then
        log "initialising restic repository"
        restic init
    fi
    restic backup --tag postgres --host personal-app "$1"
    restic forget --tag postgres --host personal-app \
        --keep-daily "$BACKUP_KEEP_DAILY" \
        --keep-weekly "$BACKUP_KEEP_WEEKLY" \
        --keep-monthly "$BACKUP_KEEP_MONTHLY" \
        --prune
    log "restic snapshot stored in $RESTIC_REPOSITORY"
}

run_backup() {
    mkdir -p "$BACKUP_DIR/daily" "$BACKUP_DIR/weekly" "$BACKUP_DIR/monthly"
    today="$(date +%F)"
    target="$BACKUP_DIR/daily/$PGDATABASE-$today.dump"
    partial="$target.partial"

    until pg_isready -q; do
        log "waiting for postgres at $PGHOST:$PGPORT"
        sleep 5
    done

    log "dumping $PGDATABASE to $target"
    pg_dump --format=custom --compress=9 --no-owner --file="$partial"
    mv "$partial" "$target"

    if [ "$(date +%u)" = "1" ]; then
        cp "$target" "$BACKUP_DIR/weekly/$PGDATABASE-$today.dump"
    fi
    if [ "$(date +%d)" = "01" ]; then
        cp "$target" "$BACKUP_DIR/monthly/$PGDATABASE-$today.dump"
    fi

    prune "$BACKUP_DIR/daily" "$BACKUP_KEEP_DAILY"
    prune "$BACKUP_DIR/weekly" "$BACKUP_KEEP_WEEKLY"
    prune "$BACKUP_DIR/monthly" "$BACKUP_KEEP_MONTHLY"

    push_to_restic "$target"
    log "backup finished"
}

seconds_until_next_run() {
    now="$(date +%s)"
    next="$(date -d "today $BACKUP_TIME" +%s)"
    if [ "$next" -le "$now" ]; then
        next="$(date -d "tomorrow $BACKUP_TIME" +%s)"
    fi
    echo $((next - now))
}

schedule() {
    log "scheduler started; daily backup at $BACKUP_TIME ($TZ), keeping $BACKUP_KEEP_DAILY daily / $BACKUP_KEEP_WEEKLY weekly / $BACKUP_KEEP_MONTHLY monthly"
    trap 'log "stopping"; exit 0' TERM INT
    while true; do
        wait_seconds="$(seconds_until_next_run)"
        log "next backup in ${wait_seconds}s"
        sleep "$wait_seconds" &
        wait $!
        run_backup || log "ERROR: backup failed"
    done
}

case "${1:-schedule}" in
    schedule) schedule ;;
    run) run_backup ;;
    *) exec "$@" ;;
esac
