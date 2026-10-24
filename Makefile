COMPOSE ?= docker compose
SET_ENV := ./infra/scripts/set-env.sh
PHP_RUN := $(COMPOSE) run --rm --no-deps -T -e SKIP_ENTRYPOINT=true app
ARGS ?=

.DEFAULT_GOAL := help

.PHONY: help setup env keys build up down restart ps logs migrate seed-demo create-user test-backend test-frontend test-e2e shell backup

help:
	@echo "Targets: setup build up down restart ps logs migrate seed-demo create-user test-backend test-frontend test-e2e shell backup"

setup: env build keys
	@echo "Setup complete. Run 'make up' and open $$(grep -E '^APP_URL=' .env | cut -d= -f2-)"

env:
	@test -f .env || { cp .env.example .env; echo "Created .env from .env.example"; }

build: env
	$(COMPOSE) build

keys: env
	@if grep -Eq '^APP_KEY=.+' .env; then \
		echo "APP_KEY already set"; \
	else \
		key=$$($(PHP_RUN) php -r 'echo "base64:".base64_encode(random_bytes(32));') && \
		$(SET_ENV) .env APP_KEY "$$key" && echo "APP_KEY generated"; \
	fi
	@if grep -Eq '^VAPID_PUBLIC_KEY=.+' .env && grep -Eq '^VAPID_PRIVATE_KEY=.+' .env; then \
		echo "VAPID keys already set"; \
	else \
		keys=$$($(PHP_RUN) php -r 'require "vendor/autoload.php"; $$k = Minishlink\WebPush\VAPID::createVapidKeys(); echo $$k["publicKey"], " ", $$k["privateKey"];') && \
		$(SET_ENV) .env VAPID_PUBLIC_KEY "$${keys%% *}" && \
		$(SET_ENV) .env VAPID_PRIVATE_KEY "$${keys##* }" && echo "VAPID keys generated"; \
	fi

up: env
	$(COMPOSE) up -d --build

down:
	$(COMPOSE) down

restart:
	$(COMPOSE) restart app worker scheduler caddy

ps:
	$(COMPOSE) ps

logs:
	$(COMPOSE) logs -f --tail=200 $(ARGS)

migrate:
	$(COMPOSE) exec app php artisan migrate --force

seed-demo:
	$(COMPOSE) exec -e SEED_DEMO_USER=true app php artisan db:seed --force

create-user:
	$(COMPOSE) exec app php artisan app:create-user $(ARGS)

test-backend:
	$(COMPOSE) --profile test run --rm --build backend-test php artisan test $(ARGS)

test-frontend:
	$(COMPOSE) --profile test run --rm --build frontend-test npx ng test --watch=false $(ARGS)

test-e2e:
	cd frontend && npx playwright install chromium && E2E_BASE_URL=$$(grep -E '^APP_URL=' ../.env | cut -d= -f2-) npx playwright test $(ARGS)

shell:
	$(COMPOSE) exec app sh

backup:
	$(COMPOSE) run --rm backup run
