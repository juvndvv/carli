#!/usr/bin/env bash
# Deploys the backend on the server. With no argument it deploys origin/production, the
# branch CI fast-forwards once a main commit passes Pint, PHPStan and the tests, and does
# nothing when the checkout is already there (carli-deploy.timer runs it every 2 minutes).
# With a commit sha it deploys that commit, which must be on origin/main.
set -euo pipefail

readonly REPO_DIR="${DEPLOY_REPO_DIR:-$HOME/carli}"
readonly PREDEPLOY_DIR="backups/predeploy"
readonly PREDEPLOY_KEEP=5
readonly HEALTH_URL="http://127.0.0.1:${APP_PORT:-8180}/up"

log() { printf '[deploy %s] %s\n' "$(date -u +%H:%M:%S)" "$*"; }

main() {
    cd "$REPO_DIR"
    exec 9> .deploy.lock
    flock --nonblock 9 || { log "another deploy is running"; exit 0; }

    local sha="${1:-}"
    if [[ -z "$sha" ]]; then
        git fetch --quiet origin main
        # Nothing to do until CI has promoted a first commit.
        git fetch --quiet origin production 2> /dev/null || exit 0
        sha="$(git rev-parse origin/production)"
    elif [[ "$sha" =~ ^[0-9a-f]{40}$ ]]; then
        git fetch --quiet origin main
    else
        echo "usage: deploy.sh [<40-char commit sha>]" >&2
        exit 64
    fi

    if ! git merge-base --is-ancestor "$sha" origin/main; then
        echo "commit $sha is not on origin/main" >&2
        exit 65
    fi
    # Already deployed, or older than what runs (a manual deploy got ahead of production).
    git merge-base --is-ancestor "$sha" HEAD && exit 0
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
