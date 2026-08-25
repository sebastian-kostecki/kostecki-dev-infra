#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BACKUP_STORAGE="${BACKUP_STORAGE:-/storage}"

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Run as root (sudo $0)" >&2
  exit 1
fi

mkdir -p \
  "$BACKUP_STORAGE/restic/vaultwarden" \
  "$BACKUP_STORAGE/backup-staging/vaultwarden"

cp "$REPO_ROOT/systemd/vaultwarden-dump.service" /etc/systemd/system/
cp "$REPO_ROOT/systemd/vaultwarden-dump.timer" /etc/systemd/system/

systemctl daemon-reload
systemctl enable --now vaultwarden-dump.timer

if systemctl is-enabled backup-vaultwarden.timer &>/dev/null; then
  echo "==> Disabling obsolete restic systemd timers"
  systemctl disable --now backup-vaultwarden.timer || true
  systemctl disable --now backup-obsidian-livesync.timer || true
fi

systemctl list-timers 'vaultwarden-dump.timer'

echo "==> Vaultwarden dump timer installed (03:00)."
echo "    Manual: systemctl start vaultwarden-dump.service"
