# Grav 2.2.32 source build (single container: Apache + mod_php 8.3).
#
# The core repo at the tag is a full site tree but ships no vendor/ and no
# Dockerfile, and the Grav 2.x admin panel is plugin code pinned separately:
#   admin2 2.2.16, api 1.1.23, login 3.13.5, form 9.2.2, email 5.3.5,
#   shortcode-core 6.2.9, flex-objects 1.4.18 (trilbymedia), error 2.0.5,
#   problems 3.0.2, theme quark2 1.1.25
# Those are checked out into user/plugins and user/themes of this build context
# at those tags (see DEPLOY-SMA.md), so this file only adds the PHP runtime and
# the composer vendor tree.
#
# Layer order is chosen for mutation rebuilds: the PHP extensions and the
# composer vendor tree (installed from the committed composer.lock without an
# autoloader) sit below the source COPY, so a PHP/JS/content mutation re-runs
# only `composer dump-autoload` plus the file copy.

FROM php:8.3-apache

# Extensions required by composer.json (gd, zip, curl, dom, fileinfo, session,
# openssl, ctype, json, libxml) plus mbstring/pdo_sqlite used by the panel and
# its audit store. curl/dom/fileinfo/session/openssl/ctype/json/libxml are
# already compiled into the official image.
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        git unzip libzip-dev libpng-dev libjpeg62-turbo-dev libfreetype6-dev libonig-dev libsqlite3-dev; \
    docker-php-ext-configure gd --with-freetype --with-jpeg; \
    docker-php-ext-install -j"$(nproc)" gd zip mbstring pdo_sqlite opcache; \
    a2enmod rewrite headers; \
    rm -rf /var/lib/apt/lists/*

# Grav's shipped root .htaccess needs AllowOverride for rewrite + security rules.
RUN sed -ri 's/^\s*AllowOverride\s+None/    AllowOverride All/' /etc/apache2/apache2.conf

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /tmp/build
COPY composer.json composer.lock ./
RUN --mount=type=cache,target=/root/.composer/cache \
    COMPOSER_CACHE_DIR=/root/.composer/cache \
    composer install --no-dev --no-scripts --no-autoloader --no-interaction --no-progress

WORKDIR /var/www/html
COPY . /var/www/html
RUN set -eux; \
    mv /tmp/build/vendor /var/www/html/vendor; \
    composer dump-autoload --no-dev -o --no-scripts --no-interaction; \
    mkdir -p cache logs tmp backup images assets; \
    chown -R www-data:www-data user cache logs tmp backup images assets; \
    rm -rf /tmp/build

EXPOSE 80
