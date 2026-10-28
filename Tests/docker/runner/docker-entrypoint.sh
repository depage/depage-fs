#!/bin/bash
set -e

SERVER_HOST="${TEST_SERVER_HOST:-server}"

# {{{ wait_for_port
wait_for_port() {
    local host="$1" port="$2" timeout="${3:-60}"

    echo "waiting for ${host}:${port} ..."
    for ((i = 0; i < timeout; i++)); do
        if (exec 3<>"/dev/tcp/${host}/${port}") 2>/dev/null; then
            return 0
        fi
        sleep 1
    done

    echo "timeout waiting for ${host}:${port}" >&2
    return 1
}
# }}}

wait_for_port "$SERVER_HOST" 22
wait_for_port "$SERVER_HOST" 21

# keep vendor/ in sync with composer.lock (fast no-op if nothing changed)
composer install --no-interaction --prefer-dist --no-progress

exec "$@"
