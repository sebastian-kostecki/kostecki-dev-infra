#!/usr/bin/env bash
set -euo pipefail

KEEPER_DIR="${VPS_ROOT_KEEPER_DIR:-/srv/apps/root-keeper}"

cd "$KEEPER_DIR"

echo "==> Deploying root-keeper..."
./scripts/deploy.sh

echo "==> Done. Check https://genealog.kostecki.dev"
