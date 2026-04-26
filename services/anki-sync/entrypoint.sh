#!/bin/sh
set -o errexit
set -o nounset
set -o pipefail

export PUID=${PUID:-1000}
export PGID=${PGID:-1000}

export SYNC_PORT=8080
export SYNC_BASE=/anki_data

if ! getent group anki-group >/dev/null 2>&1; then
  addgroup -g "$PGID" anki-group
fi

if ! id -u anki >/dev/null 2>&1; then
  adduser -D -H -u "$PUID" -G anki-group anki
fi

mkdir -p /anki_data
chown anki:anki-group /anki_data

exec su-exec anki "$@"
