#!/usr/bin/env bash
set -euo pipefail

readonly REPO_DIR="${DEPLOY_REPO_DIR:-$HOME/carli}"
readonly PREDEPLOY_DIR="${DEPLOY_DUMP_DIR:-$HOME/predeploy-dumps}"
readonly PREDEPLOY_KEEP=5
readonly HEALTH_URL="http://127.0.0.1:${APP_PORT:-8180}/up"

log() { printf '[deploy %s] %s\n' "$(date -u +%H:%M:%S)" "$*"; }

main() {
    local sha="${SSH_ORIGINAL_COMMAND:-${1:-}}"
    if [[ ! "$sha" =~ ^[0-9a-f]{40}$ ]]; then
        echo "usage: deploy.sh <40-char commit sha>" >&2
        exit 64
    fi

    cd "$REPO_DIR"

    log "fetching origin/main"
    git fetch --quiet origin main
    if ! git merge-base --is-ancestor "$sha" origin/main; then
        echo "commit $sha is not on origin/main" >&2
        exit 65
    fi
    git merge --ff-only --quiet "$sha"
    log "at $(git log --oneline -1)"

    log "building images"
    docker compose build --quiet

    log "dumping the database before migrating"
    mkdir -p "$PREDEPLOY_DIR"
    local dump
    dump="$PREDEPLOY_DIR/personal-$(date -u +%Y%m%dT%H%M%SZ)-${sha:0:7}.dump"
    docker compose exec -T postgres sh -c 'pg_dump -U "$POSTGRES_USER" -Fc "$POSTGRES_DB"' > "$dump"
    find "$PREDEPLOY_DIR" -name '*.dump' | sort -r | tail -n +$((PREDEPLOY_KEEP + 1)) | xargs -r rm --

    log "starting the stack (app runs the migrations)"
    docker compose up -d --remove-orphans --wait --wait-timeout 180

    log "checking $HEALTH_URL"
    curl --fail --silent --show-error --retry 10 --retry-delay 3 --retry-all-errors "$HEALTH_URL" > /dev/null

    docker image prune --force > /dev/null
    log "deployed ${sha:0:7}"
}

main "$@"
exit
