#!/usr/bin/env bash
set -euo pipefail

echo "==> Updating system..."
sudo apt update && sudo apt upgrade -y

echo "==> Installing Docker..."
if ! command -v docker &>/dev/null; then
  curl -fsSL https://get.docker.com | sh
  sudo usermod -aG docker "$USER"
  echo "Log out and back in for docker group to take effect."
fi

echo "==> Installing restic (CLI restore)..."
if ! command -v restic &>/dev/null; then
  sudo apt-get update
  sudo apt-get install -y restic
fi

echo "==> Installing rsync (landing publish)..."
if ! command -v rsync &>/dev/null; then
  sudo apt-get install -y rsync
fi

echo "==> Configuring firewall..."
sudo ufw allow OpenSSH
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw --force enable

echo "==> Creating directories..."
sudo mkdir -p \
  /srv/infra \
  /srv/apps/landing \
  /srv/apps/vaultwarden \
  /srv/apps/household-treasurer \
  /srv/apps/root-keeper \
  /srv/apps/backrest \
  /storage/household-treasurer-backups \
  /storage/root-keeper-backups \
  /storage/restic/vaultwarden \
  /storage/backup-staging/vaultwarden
sudo chown -R "$USER:$USER" /srv /storage/household-treasurer-backups /storage/root-keeper-backups

echo "==> Creating Docker network..."
docker network create proxy 2>/dev/null || true

echo "==> Done. Next steps:"
echo "  1. Clone kostecki-dev-infra to /srv/infra"
echo "  2. cp .env.example .env && edit ACME_EMAIL"
echo "  3. docker compose up -d"
echo "  4. Clone kostecki-dev-landing to /srv/apps/landing, build & deploy"
echo "  5. Clone kostecki-dev-vaultwarden to /srv/apps/vaultwarden — see docs/vaultwarden.md"
echo "  6. Clone household-treasurer to /srv/apps/household-treasurer — see docs/household-treasurer.md"
echo "  7. Clone root-keeper to /srv/apps/root-keeper — see docs/root-keeper.md"
echo "  8. If wallet-master is still running: docs/remove-wallet-master.md"
echo "  9. If CouchDB LiveSync is still running: docs/remove-obsidian-livesync.md"
echo "  10. Backups: sudo ./scripts/install-vaultwarden-dump-timer.sh then ./scripts/deploy-backrest.sh — see docs/backups.md"
