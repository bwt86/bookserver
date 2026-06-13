#!/usr/bin/env bash
set -euo pipefail

# Backs up the config/database that's painful to recreate:
#   - Kavita config        (bind mount: $KAVITA_CONFIG)
#   - Audiobookshelf config (bind mount: $ABS_CONFIG)
#   - Audiobookshelf metadata (named volume: audiobookshelf_metadata)
# Media libraries are NOT backed up here.

# --- resolve repo + load .env (for the host config paths) ---
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$REPO_DIR/.env"
[ -f "$ENV_FILE" ] && { set -a; source "$ENV_FILE"; set +a; }

# --- config ---
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="${BACKUP_DIR:-$HOME/bookserver-backups}"
KAVITA_CONFIG="${KAVITA_CONFIG:-/srv/config/kavita}"
ABS_CONFIG="${ABS_CONFIG:-/srv/config/audiobookshelf}"
ABS_META_VOL="audiobookshelf_metadata"

# --- helpers ---
log() { echo "[$(date '+%H:%M:%S')] $*"; }
die() { log "ERROR: $*"; exit 1; }

mkdir -p "$BACKUP_DIR"

# Tar a host directory (runs in a throwaway alpine container so root can read
# files owned by PUID/PGID, and so behavior matches restore.sh).
backup_dir() {
  local src="$1" out="$2"
  [ -d "$src" ] || die "Config dir not found: $src (has setup.sh run?)"
  log "Backing up $src -> $out"
  docker run --rm \
    -v "${src}:/data:ro" \
    -v "${BACKUP_DIR}:/backup" \
    alpine \
    tar czf "/backup/${out}" -C /data .
}

# Tar a named docker volume.
backup_volume() {
  local vol="$1" out="$2"
  log "Backing up volume $vol -> $out"
  docker run --rm \
    -v "${vol}:/data:ro" \
    -v "${BACKUP_DIR}:/backup" \
    alpine \
    tar czf "/backup/${out}" -C /data .
}

backup_dir    "$KAVITA_CONFIG" "kavita-config-${TIMESTAMP}.tar.gz"
backup_dir    "$ABS_CONFIG"    "abs-config-${TIMESTAMP}.tar.gz"
backup_volume "$ABS_META_VOL"  "abs-metadata-${TIMESTAMP}.tar.gz"

log "Backup complete -> $BACKUP_DIR"
ls -lh "$BACKUP_DIR"/*-"${TIMESTAMP}".tar.gz
