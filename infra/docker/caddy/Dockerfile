# syntax=docker/dockerfile:1.7

FROM node:22-bookworm-slim AS frontend-deps

WORKDIR /app
ENV CI=true NG_CLI_ANALYTICS=false

COPY package.json package-lock.json ./
RUN npm ci --no-audit --no-fund
COPY . .

FROM frontend-deps AS frontend-test

CMD ["npx", "ng", "test", "--watch=false"]

FROM frontend-deps AS frontend-build

COPY --from=caddy-config docker/caddy/csp-hashes.mjs /tmp/csp-hashes.mjs
RUN npm run build \
    && node /tmp/csp-hashes.mjs dist/frontend/browser/index.html /tmp/csp-script-hashes

FROM caddy:2 AS production

COPY --from=caddy-config Caddyfile /etc/caddy/Caddyfile
COPY --from=caddy-config --chmod=0755 docker/caddy/entrypoint.sh /usr/local/bin/caddy-entrypoint
COPY --from=frontend-build /tmp/csp-script-hashes /etc/caddy/csp-script-hashes
COPY --from=frontend-build /app/dist/frontend/browser /srv/frontend

RUN caddy-entrypoint caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile

ENTRYPOINT ["caddy-entrypoint"]
CMD ["caddy", "run", "--config", "/etc/caddy/Caddyfile", "--adapter", "caddyfile"]
