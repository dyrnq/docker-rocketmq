#!/usr/bin/env bash
set -eo pipefail

_main() {
    if [ -n "$TZ" ]; then
        ( ln -snf "/usr/share/zoneinfo/$TZ" /etc/localtime && echo "$TZ" > /etc/timezone ) || true
    fi
    chown -R rocketmq:rocketmq /home/rocketmq/logs
    chown -R rocketmq:rocketmq /home/rocketmq/store
    exec gosu rocketmq "$@"
}

_main "$@"