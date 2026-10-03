#!/bin/sh
set -eu

CONFIG_FILE=${NEXTCLOUD_CONFIG:-/etc/super-aio/nextcloud.conf}

if [ ! -r "$CONFIG_FILE" ]; then
  echo "Nextcloud configuration is missing: $CONFIG_FILE" >&2
  exit 1
fi

# shellcheck disable=SC1090
. "$CONFIG_FILE"

: "${NEXTCLOUD_URL:?NEXTCLOUD_URL is not set}"
: "${NEXTCLOUD_ROOT:?NEXTCLOUD_ROOT is not set}"

exec /usr/local/bin/nextcloudcmd -s -n "$NEXTCLOUD_ROOT" "$NEXTCLOUD_URL"
