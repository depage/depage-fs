FROM debian:trixie-slim

ENV DEBIAN_FRONTEND=noninteractive \
    COMPOSER_HOME=/tmp/composer \
    COMPOSER_ALLOW_SUPERUSER=1

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        composer \
        php-cli \
        php-curl \
        php-mbstring \
        php-ssh2 \
        php-xml \
        php-zip \
        unzip \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# pre-install dependencies so the vendor volume starts out populated
# copy composer.json (+ composer.lock, if present); vendor/ is seeded
# into a named volume and kept in sync by the entrypoint
COPY composer.* ./
RUN composer install --no-interaction --prefer-dist --no-progress

COPY Tests/docker/runner/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod 755 /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["vendor/bin/phpunit", "--configuration", "Tests/PHPUnit.xml"]
