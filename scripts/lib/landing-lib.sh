#!/usr/bin/env bash
# Shared by deploy-landing.sh (manual: pull + build + publish) and refresh-landing.sh
# (landing-refresh.timer: rebuild only when the archive counts on GitHub changed).
#
# Layout inside the landing checkout:
#   dist/                    build output (pnpm build), never served directly
#   www/                     what nginx serves; synced from dist/ only after a successful build
#   .deploy/archive.json     archive counts of the build currently in www/
#   .deploy/lock             flock, so a manual deploy and the timer never build at once

LANDING_DIR="${VPS_LANDING_DIR:-/srv/apps/landing}"

landing_state_dir() {
  echo "$LANDING_DIR/.deploy"
}

# Holds an exclusive lock on fd 9 until the calling script exits. Fails instead of waiting.
landing_lock() {
  local dir
  dir="$(landing_state_dir)"
  mkdir -p "$dir"
  exec 9>"$dir/lock"
  if ! flock -n 9; then
    echo "ERROR: another landing deploy/refresh holds $dir/lock" >&2
    return 1
  fi
}

# Prints the per-repo counts of an archive result (generatedAt is ignored), so two results
# compare equal when the counts are equal. Prints nothing for a missing file; fails with
# the parse error for a file that is not a valid result.
archive_signature() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  node -e '
    const data = JSON.parse(require("node:fs").readFileSync(process.argv[1], "utf8"))
    if (!Array.isArray(data?.repos)) throw new Error(`${process.argv[1]}: no "repos" array`)
    process.stdout.write(JSON.stringify(data.repos.map(({ repo, count }) => ({ repo, count }))))
  ' "$file"
}

# Syncs a finished dist/ into www/, (re)starts the container and records the published counts.
# --delay-updates and --delete-delay keep the switch to the new build close to atomic.
publish_landing() {
  if ! command -v rsync >/dev/null; then
    echo "ERROR: rsync is not installed (sudo apt-get install -y rsync)" >&2
    return 1
  fi
  if [[ ! -f "$LANDING_DIR/dist/index.html" ]]; then
    echo "ERROR: $LANDING_DIR/dist/index.html is missing, refusing to publish" >&2
    return 1
  fi
  mkdir -p "$LANDING_DIR/www" "$(landing_state_dir)"
  rsync -a --delay-updates --delete-delay "$LANDING_DIR/dist/" "$LANDING_DIR/www/"
  (cd "$LANDING_DIR" && docker compose up -d)
  cp "$LANDING_DIR/src/generated/archive.json" "$(landing_state_dir)/archive.json"
}
