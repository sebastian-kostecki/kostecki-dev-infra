#!/usr/bin/env bash
set -euo pipefail

TREASURER_DIR="${VPS_TREASURER_DIR:-/srv/apps/household-treasurer}"

cd "$TREASURER_DIR"

echo "==> Deploying household-treasurer..."
./scripts/deploy.sh

echo "==> Done. Check https://treasurer.kostecki.dev"
