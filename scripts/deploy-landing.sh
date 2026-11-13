#!/usr/bin/env bash
# Manual deploy of kostecki.dev: pull, build into dist/, then publish dist/ to www/.
# The daily landing-refresh.timer (refresh-landing.sh) rebuilds without pulling.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/landing-lib.sh
source "$SCRIPT_DIR/lib/landing-lib.sh"

landing_lock
cd "$LANDING_DIR"

echo "==> Pulling latest..."
git pull

echo "==> Building..."
pnpm install --frozen-lockfile
pnpm build

echo "==> Publishing..."
publish_landing

echo "==> Done. Check https://kostecki.dev"
