#!/usr/bin/env bash
# Scheduled refresh of kostecki.dev, run by landing-refresh.timer (see docs/LANDING.md).
# Fetches the archive counts from GitHub and rebuilds the current checkout only when they
# differ from the counts of the published build. No git pull: code changes still go
# through deploy-landing.sh.
#
# ARCHIVE_STRICT=1 makes a GitHub outage fail this job (visible in systemctl/journal)
# instead of silently rebuilding with a stale count. The site keeps its last build.
# LANDING_REFRESH_FORCE=1 rebuilds even when the counts did not change.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/landing-lib.sh
source "$SCRIPT_DIR/lib/landing-lib.sh"

landing_lock
cd "$LANDING_DIR"
export ARCHIVE_STRICT=1

echo "==> Fetching archive counts from GitHub..."
pnpm --silent generate:archive

current="$(archive_signature src/generated/archive.json)"
state="$(landing_state_dir)/archive.json"
if ! published="$(archive_signature "$state")"; then
  echo "WARN: $state is not a valid archive result, rebuilding" >&2
  published=""
fi

if [[ -n "$published" && "$current" == "$published" && "${LANDING_REFRESH_FORCE:-0}" != "1" ]]; then
  echo "==> Archive counts unchanged, nothing to do: $current"
  exit 0
fi

echo "==> Archive counts changed: ${published:-<nothing published yet>} -> $current"
echo "==> Building..."
pnpm install --frozen-lockfile
pnpm build

echo "==> Publishing..."
publish_landing

echo "==> Done. Published: $(archive_signature "$state")"
