#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
STACK_SRC="$REPO_ROOT/stacks/backrest"

if [[ -f "$REPO_ROOT/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "$REPO_ROOT/.env"
  set +a
fi

APP_DIR="${VPS_BACKREST_DIR:-/srv/apps/backrest}"

if [[ ! -f "$STACK_SRC/docker-compose.yml" ]]; then
  echo "error: stack templates not found at $STACK_SRC" >&2
  exit 1
fi

mkdir -p "$APP_DIR/data" "$APP_DIR/config" "$APP_DIR/cache" "$APP_DIR/tmp"
mkdir -p /storage/restic/vaultwarden /storage/backup-staging/vaultwarden

cp "$STACK_SRC/docker-compose.yml" "$APP_DIR/docker-compose.yml"

cd "$APP_DIR"

echo "==> Updating Backrest image..."
docker compose pull
docker compose up -d

echo "==> Done. Open https://backup.kostecki.dev (set the instance password on first visit)."
echo "    UI config in ${APP_DIR}/config is not overwritten by this script."
