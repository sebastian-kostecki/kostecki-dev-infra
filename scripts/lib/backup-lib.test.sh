#!/usr/bin/env bash
set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=backup-lib.sh
source "$TEST_DIR/backup-lib.sh"

fail=0
assert_eq() {
  local name="$1" expected="$2" actual="$3"
  if [[ "$actual" != "$expected" ]]; then
    echo "FAIL: $name (expected [$expected] got [$actual])" >&2
    fail=1
  else
    echo "PASS: $name"
  fi
}

BACKUP_STORAGE="/tmp/fake-storage"
assert_eq "app_staging_dir vaultwarden" \
  "/tmp/fake-storage/backup-staging/vaultwarden" \
  "$(app_staging_dir vaultwarden)"

assert_eq "app_restic_repo vaultwarden" \
  "/tmp/fake-storage/restic/vaultwarden" \
  "$(app_restic_repo vaultwarden)"

BACKUP_SKIP_MOUNT_CHECK=1
if require_storage_mounted; then
  echo "PASS: require_storage_mounted skip"
else
  echo "FAIL: require_storage_mounted skip" >&2
  fail=1
fi

tmpdir="$(mktemp -d)"
BACKUP_STORAGE="$tmpdir"
prepare_staging vaultwarden
echo hello >"$(app_staging_dir vaultwarden)/x"
prepare_staging vaultwarden
if [[ -e "$(app_staging_dir vaultwarden)/x" ]]; then
  echo "FAIL: prepare_staging should recreate empty dir" >&2
  fail=1
else
  echo "PASS: prepare_staging recreates empty dir"
fi
rm -rf "$tmpdir"

if [[ "$fail" -ne 0 ]]; then
  exit 1
fi
echo "All backup-lib tests passed"
