#!/bin/sh
set -eu

if [ "${SKIP_ENTRYPOINT:-false}" = "true" ]; then
    exec "$@"
fi

if [ -z "${APP_KEY:-}" ]; then
    cat >&2 <<'MSG'
ERROR: APP_KEY is empty.
Run "make setup" in the repository root (it generates APP_KEY and VAPID keys into .env),
or set APP_KEY in .env with a value like "base64:<32 random bytes in base64>".
MSG
    exit 1
fi

php /usr/local/bin/wait-for-db.php

if [ "${RUN_MIGRATIONS:-false}" = "true" ]; then
    php artisan migrate --force --no-interaction
fi

if [ "${APP_ENV:-production}" = "production" ]; then
    php artisan optimize --no-interaction
else
    php artisan optimize:clear --no-interaction >/dev/null
fi

exec "$@"
