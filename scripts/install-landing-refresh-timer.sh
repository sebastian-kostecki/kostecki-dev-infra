#!/usr/bin/env bash
# Installs landing-refresh.timer (daily rebuild of kostecki.dev when the archive counts change).
# Run once on the VPS from the deploy user: sudo ./scripts/install-landing-refresh-timer.sh
#
# The service runs as that user (it owns /srv/apps/landing and is in the docker group).
# Node/pnpm usually come from nvm, which systemd does not load, so their directories are
# detected from the user's interactive shell and written into the unit's PATH.
# Overrides: LANDING_REFRESH_USER, LANDING_NODE_PATH (colon-separated dirs), VPS_LANDING_DIR.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LANDING_DIR="${VPS_LANDING_DIR:-/srv/apps/landing}"

die() {
  echo "ERROR: $*" >&2
  exit 1
}

[[ "$(id -u)" -eq 0 ]] || die "run as root (sudo $0)"

RUN_USER="${LANDING_REFRESH_USER:-${SUDO_USER:-}}"
[[ -n "$RUN_USER" && "$RUN_USER" != "root" ]] ||
  die "cannot tell the deploy user; run via sudo from it or set LANDING_REFRESH_USER"
id -nG "$RUN_USER" | tr ' ' '\n' | grep -qx docker || die "$RUN_USER is not in the docker group"
[[ -f "$LANDING_DIR/package.json" ]] || die "no landing checkout at $LANDING_DIR"
command -v rsync >/dev/null || die "rsync is not installed (apt-get install -y rsync)"

NODE_PATH_DIRS="${LANDING_NODE_PATH:-}"
if [[ -z "$NODE_PATH_DIRS" ]]; then
  # The last line only: interactive shells may print banners before it.
  NODE_PATH_DIRS="$(sudo -iu "$RUN_USER" bash -ic \
    'printf "%s:%s\n" "$(dirname "$(command -v node)")" "$(dirname "$(command -v pnpm)")"' 2>/dev/null |
    tail -n 1)"
fi
for tool in node pnpm; do
  sudo -u "$RUN_USER" env PATH="$NODE_PATH_DIRS:/usr/bin:/bin" bash -c "command -v $tool" >/dev/null ||
    die "$tool not found in [$NODE_PATH_DIRS]; set LANDING_NODE_PATH to the directories holding node and pnpm"
done

sed \
  -e "s|@USER@|$RUN_USER|" \
  -e "s|@NODE_PATH@|$NODE_PATH_DIRS|" \
  -e "s|@LANDING_DIR@|$LANDING_DIR|" \
  -e "s|@INFRA_DIR@|$REPO_ROOT|" \
  "$REPO_ROOT/systemd/landing-refresh.service" >/etc/systemd/system/landing-refresh.service
grep -q '@[A-Z_]*@' /etc/systemd/system/landing-refresh.service &&
  die "unfilled placeholder in /etc/systemd/system/landing-refresh.service"
cp "$REPO_ROOT/systemd/landing-refresh.timer" /etc/systemd/system/

systemctl daemon-reload
systemctl enable --now landing-refresh.timer
systemctl list-timers 'landing-refresh.timer'

echo "==> landing-refresh timer installed (04:30, user $RUN_USER, PATH prefix $NODE_PATH_DIRS)."
echo "    Run now:  sudo systemctl start landing-refresh.service"
echo "    Logs:     journalctl -u landing-refresh.service -n 50"
echo "    Failures: systemctl --failed"
