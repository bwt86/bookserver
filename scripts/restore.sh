#!/usr/bin/env bash
set -euo pipefail

# Restores the config/database captured by backup.sh:
#   - Kavita config         -> $KAVITA_CONFIG (bind mount)
#   - Audiobookshelf config -> $ABS_CONFIG    (bind mount)
#   - Audiobookshelf metadata -> audiobookshelf_metadata (named volume)
# Uses the most recent backup of each type unless overridden.

# --- resolve repo + load .env (for the host config paths) ---
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$REPO_DIR/.env"
[ -f "$ENV_FILE" ] && { set -a; source "$ENV_FILE"; set +a; }

# --- config ---
BACKUP_DIR="${BACKUP_DIR:-$HOME/bookserver-backups}"
KAVITA_CONFIG="${KAVITA_CONFIG:-/srv/config/kavita}"
ABS_CONFIG="${ABS_CONFIG:-/srv/config/audiobookshelf}"
ABS_META_VOL="audiobookshelf_metadata"

# --- helpers ---
log() { echo "[$(date '+%H:%M:%S')] $*"; }
die() { log "ERROR: $*"; exit 1; }

# --- pick latest backup files ---
KAVITA_BACKUP=$(ls -t "$BACKUP_DIR"/kavita-config-*.tar.gz 2>/dev/null | head -1 || true)
ABS_BACKUP=$(ls -t "$BACKUP_DIR"/abs-config-*.tar.gz 2>/dev/null | head -1 || true)
ABS_META_BACKUP=$(ls -t "$BACKUP_DIR"/abs-metadata-*.tar.gz 2>/dev/null | head -1 || true)

[ -n "$KAVITA_BACKUP" ]   || die "No Kavita backup found in $BACKUP_DIR"
[ -n "$ABS_BACKUP" ]      || die "No ABS config backup found in $BACKUP_DIR"
[ -n "$ABS_META_BACKUP" ] || die "No ABS metadata backup found in $BACKUP_DIR"

log "Using backups:"
log "  Kavita:      $KAVITA_BACKUP"
log "  ABS config:  $ABS_BACKUP"
log "  ABS meta:    $ABS_META_BACKUP"

# --- stop services so nothing is mid-write ---
log "Stopping services..."
(cd "$REPO_DIR" && docker compose down) || true

# Restore an archive into a host directory.
restore_dir() {
  local dest="$1" archive="$2"
  log "Restoring $archive -> $dest"
  mkdir -p "$dest" 2>/dev/null || sudo mkdir -p "$dest"
  docker run --rm \
    -v "${dest}:/data" \
    -v "$(dirname "$archive"):/backup:ro" \
    alpine \
    sh -c "rm -rf /data/* /data/.[!.]* /data/..?* 2>/dev/null; tar xzf /backup/$(basename "$archive") -C /data"
}

# Restore an archive into a named docker volume.
restore_volume() {
  local vol="$1" archive="$2"
  log "Restoring $archive -> volume $vol"
  docker volume create "$vol" >/dev/null 2>&1 || true
  docker run --rm \
    -v "${vol}:/data" \
    -v "$(dirname "$archive"):/backup:ro" \
    alpine \
    sh -c "rm -rf /data/* /data/.[!.]* /data/..?* 2>/dev/null; tar xzf /backup/$(basename "$archive") -C /data"
}

restore_dir    "$KAVITA_CONFIG" "$KAVITA_BACKUP"
restore_dir    "$ABS_CONFIG"    "$ABS_BACKUP"
restore_volume "$ABS_META_VOL"  "$ABS_META_BACKUP"

# --- restart services ---
log "Starting services..."
(cd "$REPO_DIR" && docker compose up -d)

PI_IP=$(hostname -I 2>/dev/null | awk '{print $1}'); PI_IP="${PI_IP:-<pi-ip>}"
log "Restore complete. Verify at:"
log "  Kavita:         http://${PI_IP}:${KAVITA_PORT:-5000}"
log "  Audiobookshelf: http://${PI_IP}:${ABS_PORT:-13378}"
