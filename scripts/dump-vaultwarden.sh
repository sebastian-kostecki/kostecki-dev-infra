#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/backup-lib.sh
source "$SCRIPT_DIR/lib/backup-lib.sh"

APP="vaultwarden"

require_storage_mounted
prepare_staging "$APP"
STAGING="$(app_staging_dir "$APP")"

# Copy attachments/keys first; never copy live sqlite files into staging.
docker run --rm \
  -v "${VAULTWARDEN_VOLUME}:/data:ro" \
  -v "${STAGING}:/staging" \
  "$ALPINE_IMAGE" \
  sh -c 'apk add --no-cache rsync >/dev/null && rsync -a --delete \
    --exclude db.sqlite3 \
    --exclude db.sqlite3-wal \
    --exclude db.sqlite3-shm \
    /data/ /staging/'

# Consistent sqlite snapshot into staging/db.sqlite3 (volume RW for .backup).
docker run --rm \
  -v "${VAULTWARDEN_VOLUME}:/data" \
  -v "${STAGING}:/staging" \
  "$ALPINE_IMAGE" \
  sh -c 'apk add --no-cache sqlite >/dev/null && sqlite3 /data/db.sqlite3 ".backup \"/staging/db.sqlite3\""'

echo "==> Vaultwarden dump complete: ${STAGING}"
