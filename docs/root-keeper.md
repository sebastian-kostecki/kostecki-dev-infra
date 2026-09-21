# root-keeper deployment

Deployment guide for Laravel + Inertia (React) + PostgreSQL on **genealog.kostecki.dev**.

Related: [ADDING-AN-APP.md](./ADDING-AN-APP.md) · [ARCHITECTURE.md](./ARCHITECTURE.md)

`docker-compose.prod.yml` and `docker/8.5/Dockerfile.prod` live in the [root-keeper](https://github.com/sebastian-kostecki/root-keeper) repo. `scripts/deploy.sh` and `.env.prod.example` are a follow-up in that repo — `deploy-root-keeper.sh` calls `./scripts/deploy.sh` once it exists.

Keep Sail (`compose.yaml`, `docker/8.5/Dockerfile`) **local only**. On the VPS use `docker-compose.prod.yml`. Do not build production from the Sail Dockerfile (xdebug / Playwright).

---

## DNS

```text
genealog.kostecki.dev  →  VPS IP (Cloudflare Proxied)
```

---

## Cloudflare (Proxied)

- A record for `genealog` → VPS IP, **Proxied** (orange cloud)
- SSL/TLS mode: **Full (strict)**
- Origin TLS is handled by Traefik (Let's Encrypt)

---

## VPS directory

```bash
sudo mkdir -p /srv/apps/root-keeper
git clone git@github.com:sebastian-kostecki/root-keeper.git /srv/apps/root-keeper
```

`bootstrap-vps.sh` creates this directory automatically on new servers.

---

## Traefik labels

Labels live on the **app** container in root-keeper's `docker-compose.prod.yml`. You do **not** change Traefik's compose in this infra repo.

```yaml
labels:
  - traefik.enable=true
  - traefik.docker.network=proxy
  - traefik.http.routers.genealog.rule=Host(`genealog.kostecki.dev`)
  - traefik.http.routers.genealog.entrypoints=websecure
  - traefik.http.routers.genealog.tls.certresolver=letsencrypt
  - traefik.http.services.genealog.loadbalancer.server.port=80
```

---

## Production stack

| File | Purpose |
|------|---------|
| `docker-compose.prod.yml` | app + pgsql + Traefik labels |
| `docker/8.5/Dockerfile.prod` | Multi-stage build: composer + npm + PHP runtime |
| `docker/8.5/supervisord.prod.conf` | artisan serve, queue:work, schedule:work |
| `scripts/deploy.sh` | Pull, build, up, migrate, cache (follow-up in the app repo) |
| `scripts/artisan.sh` | Run Artisan in the production `app` container (follow-up) |

```text
services:
  app       supervisord (serve :80, queue worker, scheduler)
            networks: root-keeper-internal + proxy
            volumes: storage, backups, .env.prod → /.env
  pgsql     persistent data, healthcheck

networks:
  root-keeper-internal   bridge
  proxy                  external (Traefik discovery)

volumes:
  keeper-pgsql
```

---

## Laravel `.env.prod`

Production values live in `root-keeper/.env.prod` (must be gitignored). Start from `.env.prod.example` when that file exists. Compose loads `.env.prod` (`--env-file`) and mounts it into the app container as `.env`.

Set `DB_CONNECTION=pgsql` — do not copy the local Sail `.env` (`sqlite`).

On the VPS, fill at least:

- `APP_KEY` (`php artisan key:generate`)
- `DB_PASSWORD`
- SMTP (`MAIL_HOST`, `MAIL_USERNAME`, `MAIL_PASSWORD`) if you want backup mail

---

## Backups

Intended path: [spatie/laravel-backup](https://github.com/spatie/laravel-backup) backing up **PostgreSQL and `storage/app`** (scans), same shape as household-treasurer — not DB-only. Schedule at **03:45** Europe/Warsaw so it does not collide with treasurer (03:00), Vaultwarden dump (03:00), or Backrest (03:15). Package + schedule are a follow-up in the app repo.

On the VPS, archives go **outside the app directory**:

```text
/storage/root-keeper-backups/   ← host (persistent, network mount)
        ↓ mounted into container as
/var/www/html/storage/app/backups/
```

`docker-compose.prod.yml` mounts the host path via `BACKUP_HOST_DIR` (default `/storage/root-keeper-backups`).

### One-time setup (VPS)

```bash
sudo mkdir -p /storage/root-keeper-backups
sudo chown -R "$USER:$USER" /storage/root-keeper-backups
```

`bootstrap-vps.sh` creates this directory automatically on new servers.

---

## Deploy

### First deploy (on VPS)

Requires `scripts/deploy.sh` and `.env.prod.example` in the app repo (follow-up).

```bash
cd /srv/apps/root-keeper
cp .env.prod.example .env.prod
# Edit .env.prod: DB_PASSWORD, mail, then generate APP_KEY

docker compose --env-file .env.prod -f docker-compose.prod.yml run --rm app php artisan key:generate
./scripts/deploy.sh
```

### Updates (from root-keeper repo)

```bash
cd /srv/apps/root-keeper
./scripts/deploy.sh
```

### Updates (from infra repo)

```bash
cd /srv/infra
./scripts/deploy-root-keeper.sh
```

Uses `VPS_ROOT_KEEPER_DIR` from infra `.env` (default `/srv/apps/root-keeper`).

---

## Verify

```bash
curl -I https://genealog.kostecki.dev/up
```

Expected: `HTTP/2 200`

Check supervisord processes:

```bash
docker compose --env-file .env.prod -f docker-compose.prod.yml exec -T app supervisorctl status
```

Expected: `php`, `queue`, `scheduler` all `RUNNING`.

After first deploy: upload a test scan, rebuild (`docker compose up -d --build`), confirm the scan is still there.

---

## Local dev — Sail

In the root-keeper repo:

```bash
./vendor/bin/sail up -d
./vendor/bin/sail npm run dev
```

Sail and Traefik on VPS operate independently.
