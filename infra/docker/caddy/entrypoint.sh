#!/bin/sh
set -eu

if [ -z "${CSP_SCRIPT_HASHES:-}" ] && [ -f /etc/caddy/csp-script-hashes ]; then
    CSP_SCRIPT_HASHES="$(cat /etc/caddy/csp-script-hashes)"
fi
export CSP_SCRIPT_HASHES="${CSP_SCRIPT_HASHES:-}"

exec "$@"
