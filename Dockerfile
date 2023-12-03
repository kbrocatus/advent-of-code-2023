FROM php:8.2-fpm-alpine AS app_php

# Installing composer
ENV COMPOSER_ALLOW_SUPERUSER=1
ENV COMPOSER_MEMORY_LIMIT=-1
COPY --from=composer/composer:2-bin --link /composer /usr/bin/composer

# Installing PHP extensions.
# Check https://github.com/mlocati/docker-php-extension-installer for available extensions to install
COPY --from=mlocati/php-extension-installer /usr/bin/install-php-extensions /usr/local/bin/
RUN install-php-extensions apcu bcmath gd intl opcache pdo_pgsql redis soap xdebug zip amqp

# Set ini files
RUN mv "$PHP_INI_DIR/php.ini-development" "$PHP_INI_DIR/php.ini"
COPY --link docker/php/conf.d/app.ini $PHP_INI_DIR/conf.d/
COPY --link docker/php/conf.d/xdebug.ini $PHP_INI_DIR/conf.d/

# Install ACL for setting directory permissions and other dependencies.
RUN apk add --no-cache \
    acl \
    fcgi \
    curl \
    wget \
    vim

WORKDIR /srv/app

# avoid the var directory being mounted
VOLUME /srv/app/var/backup/
VOLUME /srv/app/var/cache/
VOLUME /srv/app/var/test/

# copy source files and remove docker directory (don't need it anymore)
COPY --link  . .

COPY composer.* symfony.* ./
RUN composer install --prefer-dist --no-autoloader --no-scripts --no-progress
RUN composer clear-cache

RUN mkdir -p var/cache var/log
RUN composer dump-autoload

COPY --link docker/php/php-fpm.d/zz-docker.conf /usr/local/etc/php-fpm.d/zz-docker.conf
RUN mkdir -p /var/run/php

# Add bash
RUN apk add --no-cache bash

# Setting flag file
RUN touch /var/log/newly-built.lock

COPY --link --chmod=755 docker/php/docker-healthcheck.sh /usr/local/bin/docker-healthcheck
HEALTHCHECK --start-period=1m --retries=30 CMD docker-healthcheck

CMD ["php-fpm"]

FROM nginx:1.22-alpine as app_nginx
COPY --link docker/nginx/conf.d/default.conf /etc/nginx/conf.d

# create cert
RUN apk add openssl
RUN mkdir -p /etc/nginx/certs
RUN echo -e '\
[ v3_ca ]\n\
subjectAltName = DNS:localhost'\
>> /etc/ssl/openssl.cnf
RUN openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/nginx/certs/nginx-selfsigned.key -out /etc/nginx/certs/nginx-selfsigned.crt -subj "/C=NL/ST=Noord-Brabant/L=Tilburg/O=TRAVIS /OU=IT Department/CN=localhost" -config /etc/ssl/openssl.cnf

WORKDIR /srv/app

COPY --link  . .
