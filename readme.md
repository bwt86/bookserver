# Unified Library — Server Infra

Reproducible setup for the **two backend servers** the app talks to — **Kavita** (books/EPUB, `:5000`) and **Audiobookshelf** (audio, `:13378`). Clone this onto the host (e.g. a Raspberry Pi), run one script, and you have both servers up. This repo is the *executable how* for the server-side setup checklist.

> **Scope:** infra/ops only. The React Native client lives in a separate repo. This repo never contains app code — just compose files, config, and setup/backup scripts.

---

## What this repo is for
- **Reproducibility** — rebuild the whole backend from scratch (new Pi, dead SD card, host migration) with `clone → ./setup.sh → restore volumes`.
- **One source of truth for infra** — ports, volumes, restart policy, and host config live in version control, not in someone's memory.
- **Disaster recovery** — paired with volume backups, this is your "get back to working state fast" path.

---

## Repo layout
```
.
├── docker-compose.yml      # Kavita + Audiobookshelf services
├── .env.example            # host-specific config template (copy → .env)
├── .gitignore              # ignores .env and any local secrets
├── setup.sh                # one-shot bootstrap (install Docker, make dirs, up -d)
├── scripts/
│   ├── backup.sh           # back up config/db volumes (NOT media)
│   └── restore.sh          # restore volumes from a backup
├── proxy/                  # (optional) Caddyfile / reverse-proxy config
│   └── Caddyfile
└── README.md               # runbook (this file)
```

---

## Core files

### `docker-compose.yml`
Defines both services side by side:
- **Kavita** — config volume + books library path, expose `5000`.
- **Audiobookshelf** — config + metadata volumes + audiobooks library path, expose `13378`.
- Both: `restart: unless-stopped`, `PUID`/`PGID`/`TZ` pulled from `.env`.
- Pin **arm64-compatible image tags** so it runs on the Pi.

### `.env.example`
All host-specific bits, so the compose file stays generic. Copy to `.env` (which is git-ignored) and fill in:
```
PUID=1000
PGID=1000
TZ=America/New_York
MEDIA_BOOKS=/srv/media/books
MEDIA_AUDIO=/srv/media/audiobooks
KAVITA_CONFIG=/srv/config/kavita
ABS_CONFIG=/srv/config/audiobookshelf
KAVITA_PORT=5000
ABS_PORT=13378
```

### `setup.sh`
Turns the manual checklist into one command on a fresh host:
1. Install Docker + Compose plugin if missing.
2. Create media + config dirs (`/srv/media/...`, `/srv/config/...`) with correct ownership.
3. Copy `.env.example` → `.env` if not present (then prompt the user to edit it).
4. `docker compose up -d`.
5. Print the two URLs to finish first-run setup in the browser.

### `scripts/backup.sh` / `restore.sh`
Back up and restore each app's **config/database volume** (where libraries, users, and progress live) — *not* the media itself. This is the part that's painful to recreate.

---

## Pi-specific notes
- **64-bit OS** — use Raspberry Pi OS 64-bit or Ubuntu arm64, not the 32-bit default. Both apps publish arm64 images.
- **Don't run off the SD card** — put media *and* the config/DB volumes on an external SSD/USB. SD cards fail under DB write load.
- **Transcoding** — fine for personal-scale audio streaming; a Pi won't love heavy video/audio transcoding, but ABS playback is light.
- **Static/reserved IP** — give the Pi a DHCP reservation so the app's API clients don't break on lease changes.

---

## First-run flow (after `setup.sh`)
1. Open `http://<pi-ip>:5000` → create Kavita admin → add books library → let it scan.
2. Open `http://<pi-ip>:13378` → create ABS root user → add libraries → let it scan.
3. Verify APIs respond; generate API keys/tokens for the app.
4. Run `scripts/backup.sh` once libraries are set up — capture a clean baseline.

---

## What's intentionally NOT here
- **App code** — separate client repo.
- **A BFF / server frontend** — deferred until there's a concrete need (multi-client, off-LAN, server-side merge). See the server-side checklist's stretch goals.
- **Secrets** — `.env` is git-ignored; never commit tokens or keys.