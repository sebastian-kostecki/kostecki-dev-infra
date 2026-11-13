#!/usr/bin/env bash
set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=landing-lib.sh
source "$TEST_DIR/landing-lib.sh"

fail=0
pass() { echo "PASS: $1"; }
failed() {
  echo "FAIL: $1" >&2
  fail=1
}
assert_eq() {
  local name="$1" expected="$2" actual="$3"
  if [[ "$actual" != "$expected" ]]; then failed "$name (expected [$expected] got [$actual])"; else pass "$name"; fi
}

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

result() { # generatedAt rk ht
  printf '{"generatedAt":"%s","total":%d,"repos":[{"repo":"o/rk","count":%d},{"repo":"o/ht","count":%d}]}\n' \
    "$1" "$(($2 + $3))" "$2" "$3"
}

# --- archive_signature ---
result 2026-11-01T00:00:00Z 71 50 >"$tmp/a.json"
result 2026-11-13T04:30:00Z 71 50 >"$tmp/b.json"
result 2026-11-13T04:30:00Z 71 72 >"$tmp/c.json"

assert_eq "archive_signature ignores generatedAt" \
  "$(archive_signature "$tmp/a.json")" "$(archive_signature "$tmp/b.json")"
if [[ "$(archive_signature "$tmp/a.json")" != "$(archive_signature "$tmp/c.json")" ]]; then
  pass "archive_signature differs when a count changes"
else
  failed "archive_signature differs when a count changes"
fi
assert_eq "archive_signature of a missing file is empty" "" "$(archive_signature "$tmp/missing.json")"
echo '{"generatedAt":"x"' >"$tmp/broken.json"
if archive_signature "$tmp/broken.json" 2>/dev/null; then
  failed "archive_signature fails on invalid JSON"
else
  pass "archive_signature fails on invalid JSON"
fi

# --- publish_landing (docker stubbed) ---
LANDING_DIR="$tmp/landing"
mkdir -p "$LANDING_DIR/dist/assets" "$LANDING_DIR/www" "$LANDING_DIR/src/generated"
echo new >"$LANDING_DIR/dist/index.html"
echo new >"$LANDING_DIR/dist/assets/app-new.js"
echo old >"$LANDING_DIR/www/stale.html"
cp "$tmp/c.json" "$LANDING_DIR/src/generated/archive.json"
docker() { echo "$PWD docker $*" >>"$tmp/docker.log"; }

publish_landing
assert_eq "publish_landing copies dist into www" "new" "$(cat "$LANDING_DIR/www/assets/app-new.js")"
if [[ -e "$LANDING_DIR/www/stale.html" ]]; then failed "publish_landing removes stale files"; else pass "publish_landing removes stale files"; fi
assert_eq "publish_landing runs compose in the landing dir" "$LANDING_DIR docker compose up -d" "$(cat "$tmp/docker.log")"
assert_eq "publish_landing records the published counts" \
  "$(archive_signature "$tmp/c.json")" "$(archive_signature "$(landing_state_dir)/archive.json")"

rm "$LANDING_DIR/dist/index.html" "$tmp/docker.log"
if publish_landing 2>/dev/null; then
  failed "publish_landing refuses an incomplete dist"
else
  pass "publish_landing refuses an incomplete dist"
fi
assert_eq "publish_landing keeps www when dist is incomplete" "new" "$(cat "$LANDING_DIR/www/index.html")"
if [[ -e "$tmp/docker.log" ]]; then failed "publish_landing skips compose for an incomplete dist"; else pass "publish_landing skips compose for an incomplete dist"; fi

# --- landing_run_user ---
unset SUDO_USER LANDING_REFRESH_USER
owner="$(id -un)" # $LANDING_DIR was created by this test, so the current user owns it
assert_eq "landing_run_user defaults to the checkout owner (root on a root-only VPS)" \
  "$owner" "$(landing_run_user)"
assert_eq "landing_run_user accepts the sudo caller who owns the checkout" \
  "$owner" "$(SUDO_USER="$owner" landing_run_user)"
assert_eq "landing_run_user accepts an explicit owner" \
  "$owner" "$(LANDING_REFRESH_USER="$owner" landing_run_user)"
if (SUDO_USER=not-the-owner landing_run_user) 2>/dev/null; then
  failed "landing_run_user rejects a sudo caller who does not own the checkout"
else
  pass "landing_run_user rejects a sudo caller who does not own the checkout"
fi
if (LANDING_REFRESH_USER=not-the-owner landing_run_user) 2>/dev/null; then
  failed "landing_run_user rejects an explicit user who does not own the checkout"
else
  pass "landing_run_user rejects an explicit user who does not own the checkout"
fi

# --- landing_lock ---
(
  landing_lock
  touch "$tmp/locked"
  sleep 2
) &
holder=$!
for _ in $(seq 50); do [[ -e "$tmp/locked" ]] && break; sleep 0.05; done
if (landing_lock) 2>/dev/null; then
  failed "landing_lock fails while another holder runs"
else
  pass "landing_lock fails while another holder runs"
fi
wait "$holder"
if (landing_lock); then pass "landing_lock succeeds after the holder exits"; else failed "landing_lock succeeds after the holder exits"; fi

if [[ "$fail" -ne 0 ]]; then
  exit 1
fi
echo "All landing-lib tests passed"
