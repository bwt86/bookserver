# Install Guide — Bookserver on a Raspberry Pi

Step-by-step instructions to get **Kavita** (books) and **Audiobookshelf** (audio)
running on a Raspberry Pi (or any Linux host). Follow these in order.

---

## 0. Before you start (one-time hardware/OS prep)

1. **Use a 64-bit OS.** Install **Raspberry Pi OS 64-bit** (or Ubuntu Server arm64).
   The 32-bit default will not run these images.
2. **Attach external storage.** Plug in an SSD/USB drive and mount it. Do **not**
   keep the databases on the SD card — it will wear out and fail under DB writes.
   Example: mount it at `/srv` so media and config live on the SSD.
3. **Give the Pi a fixed IP.** Set a DHCP reservation on your router so the
   address your app talks to never changes.
4. **Update the OS:**
   ```bash
   sudo apt-get update && sudo apt-get upgrade -y
   ```

---

## 1. Clone this repo onto the Pi

```bash
git clone https://github.com/bwt86/bookserver.git
cd bookserver
```

---

## 2. (Optional) Review/adjust configuration

`setup.sh` will auto-create a `.env` for you with sensible defaults. If you want
to customize paths or ports **before** the first run, copy the template and edit it:

```bash
cp .env.example .env
nano .env
```

Key values:

| Variable        | What it is                              | Default                          |
|-----------------|-----------------------------------------|----------------------------------|
| `PUID` / `PGID` | Your user/group id (run `id`)           | auto-detected                    |
| `TZ`            | Timezone                                | auto-detected                    |
| `MEDIA_BOOKS`   | Where your book files live              | `/srv/media/books`               |
| `MEDIA_AUDIO`   | Where your audiobook files live         | `/srv/media/audiobooks`          |
| `KAVITA_CONFIG` | Kavita database/config dir              | `/srv/config/kavita`             |
| `ABS_CONFIG`    | Audiobookshelf config dir               | `/srv/config/audiobookshelf`     |
| `KAVITA_PORT`   | Port for Kavita web UI                  | `5000`                           |
| `ABS_PORT`      | Port for Audiobookshelf web UI          | `13378`                          |

> Point `MEDIA_*` and `*_CONFIG` at paths **on your external SSD** (e.g. under `/srv`).

If you skip this step, `setup.sh` creates `.env` with the defaults above.

---

## 3. Run the setup script

```bash
./setup.sh
```

This will:
1. Install Docker + the Compose plugin if they're missing.
2. Generate `.env` (if you didn't already make one).
3. Create the media + config directories and set ownership.
4. Start both services with `docker compose up -d`.
5. Print the two URLs to open in your browser.

> **First time only:** if the script just installed Docker, it adds you to the
> `docker` group. Log out and back in (or reboot) and re-run `./setup.sh` so the
> group change takes effect.

---

## 4. First-run setup in the browser

Open each URL (replace `<pi-ip>` with your Pi's IP):

1. **Kavita** → `http://<pi-ip>:5000`
   Create the admin account → add a **books** library pointing at `/books` → let it scan.
2. **Audiobookshelf** → `http://<pi-ip>:13378`
   Create the root user → add an **audiobooks** library pointing at `/audiobooks` → let it scan.
3. Generate any API keys/tokens your client app needs.

---

## 5. Capture a baseline backup

Once your libraries and users are set up, save a clean snapshot:

```bash
./scripts/backup.sh
```

Backups land in `~/bookserver-backups/` by default (override with
`BACKUP_DIR=/path ./scripts/backup.sh`). This backs up the **config/databases**
(Kavita config, Audiobookshelf config + metadata) — **not** your media files.

---

## 6. Day-to-day commands

```bash
# View status
docker compose ps

# Follow logs
docker compose logs -f

# Stop / start
docker compose down
docker compose up -d

# Update to the latest images
docker compose pull && docker compose up -d
```

---

## 7. Disaster recovery (new Pi / dead SD card)

1. Set up a fresh 64-bit OS + external storage (Step 0).
2. Clone the repo and run `./setup.sh` (Steps 1–3).
3. Copy your backup `.tar.gz` files into `~/bookserver-backups/` on the new host.
4. Restore:
   ```bash
   ./scripts/restore.sh
   ```
   This stops the services, restores the latest config/metadata backups, and
   restarts everything. Re-point your media libraries if their paths changed.

---

## Troubleshooting

- **"permission denied" talking to Docker** → you're not in the `docker` group yet.
  Log out/in (or reboot) and try again.
- **Web UI won't load** → check `docker compose ps` and `docker compose logs <service>`.
- **Wrong file ownership in containers** → make sure `PUID`/`PGID` in `.env` match
  your host user (`id`), then `docker compose down && docker compose up -d`.
- **Pulled the 32-bit OS by mistake** → reflash with the 64-bit image; the images
  here are arm64.
