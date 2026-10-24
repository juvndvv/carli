# syntax=docker/dockerfile:1.7

FROM php:8.4-fpm AS base

ARG APP_UID=1000
ARG APP_GID=1000

COPY --from=mlocati/php-extension-installer:2 /usr/bin/install-php-extensions /usr/local/bin/
COPY --from=composer:2 /usr/bin/composer /usr/local/bin/composer

RUN install-php-extensions pdo_pgsql pgsql intl bcmath gmp zip opcache pcntl \
    && apt-get update \
    && apt-get install -y --no-install-recommends unzip \
    && rm -rf /var/lib/apt/lists/*

RUN groupadd --gid "${APP_GID}" app \
    && useradd --uid "${APP_UID}" --gid app --create-home --shell /bin/sh app

COPY --from=php-config conf/php.ini /usr/local/etc/php/conf.d/zz-app.ini
COPY --from=php-config conf/fpm-pool.conf /usr/local/etc/php-fpm.d/zz-app.conf
COPY --from=php-config --chmod=0755 entrypoint.sh /usr/local/bin/app-entrypoint
COPY --from=php-config --chmod=0755 wait-for-db.php /usr/local/bin/wait-for-db.php

ENV COMPOSER_HOME=/tmp/composer \
    APP_ENV=production \
    LOG_CHANNEL=stderr

WORKDIR /var/www/html

ENTRYPOINT ["app-entrypoint"]
CMD ["php-fpm"]
EXPOSE 9000

FROM base AS dev

RUN cp /usr/local/etc/php/php.ini-development /usr/local/etc/php/php.ini
COPY --from=php-config conf/php-dev.ini /usr/local/etc/php/conf.d/zzz-dev.ini

COPY --chown=app:app composer.json composer.lock ./
RUN chown app:app /var/www/html
USER app
RUN composer install --no-interaction --prefer-dist --no-scripts --no-autoloader --no-progress
COPY --chown=app:app . ./
RUN mkdir -p storage/app/public storage/framework/cache/data storage/framework/sessions storage/framework/views storage/logs bootstrap/cache \
    && touch .env \
    && composer dump-autoload --optimize --no-interaction

ENV APP_ENV=local

FROM base AS vendor

ENV COMPOSER_ALLOW_SUPERUSER=1

COPY composer.json composer.lock ./
RUN composer install --no-dev --no-interaction --prefer-dist --no-scripts --no-autoloader --no-progress

FROM base AS production

ENV COMPOSER_ALLOW_SUPERUSER=1

RUN cp /usr/local/etc/php/php.ini-production /usr/local/etc/php/php.ini
COPY --from=php-config conf/php-prod.ini /usr/local/etc/php/conf.d/zzz-prod.ini

COPY --from=vendor /var/www/html/vendor ./vendor
COPY . ./
RUN mkdir -p storage/app/public storage/framework/cache/data storage/framework/sessions storage/framework/views storage/logs bootstrap/cache \
    && composer dump-autoload --optimize --no-dev --no-interaction \
    && rm -f bootstrap/cache/config.php bootstrap/cache/routes-*.php bootstrap/cache/events.php \
    && chown -R app:app storage bootstrap/cache

USER app
