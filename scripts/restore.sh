#!/usr/bin/env bash
set -euo pipefail

# --- config ---
BACKUP_DIR="${BACKUP_DIR:-$HOME/bookserver-backups}"
KAVITA_VOL="kavita_config"
ABS_VOL="audiobookshelf_config"
ABS_META_VOL="audiobookshelf_metadata"

# --- helpers ---
log() { echo "[$(date '+%H:%M:%S')] $*"; }
die()  { log "ERROR: $*"; exit 1; }

# --- pick backup files ---
KAVITA_BACKUP=$(ls -t "$BACKUP_DIR"/kavita-config-*.tar.gz 2>/dev/null | head -1)
ABS_BACKUP=$(ls -t "$BACKUP_DIR"/abs-config-*.tar.gz 2>/dev/null | head -1)
ABS_META_BACKUP=$(ls -t "$BACKUP_DIR"/abs-metadata-*.tar.gz 2>/dev/null | head -1)

[ -n "$KAVITA_BACKUP" ] || die "No Kavita backup found in $BACKUP_DIR"
[ -n "$ABS_BACKUP" ]   || die "No ABS config backup found in $BACKUP_DIR"
[ -n "$ABS_META_BACKUP" ] || die "No ABS metadata backup found in $BACKUP_DIR"

log "Using backups:"
log "  Kavita:      $KAVITA_BACKUP"
log "  ABS config:  $ABS_BACKUP"
log "  ABS meta:    $ABS_META_BACKUP"

# --- stop services ---
log "Stopping services..."
docker compose down || true

# --- restore volumes ---
restore_vol() {
  local vol="$1"
  local archive="$2"
  log "Restoring $vol from $archive..."
  docker volume create "$vol" 2>/dev/null || true
  docker run --rm \
    -v "${vol}:/data" \
    -v "$(dirname "$archive"):/backup:ro" \
    alpine \
    sh -c "rm -rf /data/* /data/.[!.]* /data/..?* 2>/dev/null; tar xzf /backup/$(basename "$archive") -C /data"
}

restore_vol "$KAVITA_VOL" "$KAVITA_BACKUP"
restore_vol "$ABS_VOL" "$ABS_BACKUP"
restore_vol "$ABS_META_VOL" "$ABS_META_BACKUP"

# --- restart services ---
log "Starting services..."
docker compose up -d

log "Restore complete. Verify at:"
log "  Kavita:         http://<pi-ip>:5000"
log "  Audiobookshelf: http://<pi-ip>:13378"