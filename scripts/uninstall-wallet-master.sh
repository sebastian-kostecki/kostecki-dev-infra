#!/usr/bin/env bash
set -euo pipefail

WALLET_DIR="${VPS_WALLET_DIR:-/srv/apps/wallet-master}"
BACKUP_HOST_DIR="${BACKUP_HOST_DIR:-/storage/wallet-master-backups}"
UNINSTALL_SCRIPT="${WALLET_DIR}/scripts/uninstall.sh"

export BACKUP_HOST_DIR

if [[ ! -x "${UNINSTALL_SCRIPT}" ]]; then
  echo "ERROR: Uninstall script not found or not executable: ${UNINSTALL_SCRIPT}" >&2
  echo "" >&2
  echo "Manual cleanup if the app directory is already gone:" >&2
  echo "  docker rm -f wallet-app wallet-mysql wallet-redis wallet-typesense 2>/dev/null || true" >&2
  echo "  docker volume ls | grep -E 'wallet-(mysql|redis|typesense)'" >&2
  echo "  docker rmi wallet-master-app:prod 2>/dev/null || true" >&2
  echo "  rm -rf ${WALLET_DIR} ${BACKUP_HOST_DIR}" >&2
  exit 1
fi

echo "==> Uninstalling wallet-master from ${WALLET_DIR}..."
exec "${UNINSTALL_SCRIPT}" "$@"
