#!/usr/bin/env bash
# Shared helpers for Vaultwarden dumps to /storage staging. Sourced, not executed.

BACKUP_STORAGE="${BACKUP_STORAGE:-/storage}"
BACKUP_SKIP_MOUNT_CHECK="${BACKUP_SKIP_MOUNT_CHECK:-0}"
VAULTWARDEN_VOLUME="${VAULTWARDEN_VOLUME:-vaultwarden_vw-data}"
ALPINE_IMAGE="${ALPINE_IMAGE:-alpine:3.20}"

app_staging_dir() {
  local app="$1"
  printf '%s' "${BACKUP_STORAGE}/backup-staging/${app}"
}

app_restic_repo() {
  local app="$1"
  printf '%s' "${BACKUP_STORAGE}/restic/${app}"
}

require_storage_mounted() {
  if [[ "$BACKUP_SKIP_MOUNT_CHECK" == "1" ]]; then
    return 0
  fi
  if ! mountpoint -q "$BACKUP_STORAGE"; then
    echo "ERROR: ${BACKUP_STORAGE} is not a mountpoint" >&2
    return 1
  fi
}

prepare_staging() {
  local app="$1"
  local dir
  dir="$(app_staging_dir "$app")"
  rm -rf "$dir"
  mkdir -p "$dir"
}
