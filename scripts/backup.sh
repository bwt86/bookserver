#!/usr/bin/env bash
set -euo pipefail

# --- config ---
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="${BACKUP_DIR:-$HOME/bookserver-backups}"
KAVITA_VOL="kavita_config"
ABS_VOL="audiobookshelf_config"
ABS_META_VOL="audiobookshelf_metadata"

# --- helpers ---
log() { echo "[$(date '+%H:%M:%S')] $*"; }

# --- create backup dir ---
mkdir -p "$BACKUP_DIR"

# --- backup Kavita config ---
log "Backing up Kavita config volume ($KAVITA_VOL)..."
docker run --rm \
  -v "${KAVITA_VOL}:/data:ro" \
  -v "${BACKUP_DIR}:/backup" \
  alpine \
  tar czf "/backup/kavita-config-${TIMESTAMP}.tar.gz" -C /data .

# --- backup Audiobookshelf config + metadata ---
log "Backing up Audiobookshelf config volume ($ABS_VOL)..."
docker run --rm \
  -v "${ABS_VOL}:/data:ro" \
  -v "${BACKUP_DIR}:/backup" \
  alpine \
  tar czf "/backup/abs-config-${TIMESTAMP}.tar.gz" -C /data .

log "Backing up Audiobookshelf metadata volume ($ABS_META_VOL)..."
docker run --rm \
  -v "${ABS_META_VOL}:/data:ro" \
  -v "${BACKUP_DIR}:/backup" \
  alpine \
  tar czf "/backup/abs-metadata-${TIMESTAMP}.tar.gz" -C /data .

log "Backup complete → $BACKUP_DIR"
ls -lh "$BACKUP_DIR"/*-"${TIMESTAMP}".tar.gz