# household-treasurer deployment

Deployment guide for Laravel + Inertia (Vue) + PostgreSQL on **treasurer.kostecki.dev**.

Related: [ADDING-AN-APP.md](./ADDING-AN-APP.md) · [ARCHITECTURE.md](./ARCHITECTURE.md)

---

## Not wallet-master

wallet-master was a previous Laravel app on this VPS (`budget.kostecki.dev`) and has been removed. household-treasurer is the current Laravel + PostgreSQL pattern. root-keeper copies the same production shape (own repo, `genealog.kostecki.dev`).

Keep Sail (`compose.yaml`) **local only**. On the VPS use `docker-compose.prod.yml`.

---

## DNS

```text
treasurer.kostecki.dev  →  VPS IP (Cloudflare Proxied)
```

---

## Cloudflare (Proxied)

- A record for `treasurer` → VPS IP, **Proxied** (orange cloud)
- SSL/TLS mode: **Full (strict)**
- Origin TLS is handled by Traefik (Let's Encrypt)

---

## VPS directory

```bash
sudo mkdir -p /srv/apps/household-treasurer
git clone git@github.com:sebastian-kostecki/household-treasurer.git /srv/apps/household-treasurer
```

`bootstrap-vps.sh` creates this directory automatically.

---

## Traefik labels

Labels live on the **app** container in household-treasurer's `docker-compose.prod.yml`. You do **not** change Traefik's compose in this infra repo.

```yaml
labels:
  - traefik.enable=true
  - traefik.docker.network=proxy
  - traefik.http.routers.treasurer.rule=Host(`treasurer.kostecki.dev`)
  - traefik.http.routers.treasurer.entrypoints=websecure
  - traefik.http.routers.treasurer.tls.certresolver=letsencrypt
  - traefik.http.services.treasurer.loadbalancer.server.port=80
```

---

## Production stack

| File | Purpose |
|------|---------|
| `docker-compose.prod.yml` | app + pgsql + Traefik labels |
| `docker/8.5/Dockerfile.prod` | Multi-stage build: composer + npm + PHP runtime |
| `docker/8.5/supervisord.prod.conf` | artisan serve, queue:work, schedule:work |
| `scripts/deploy.sh` | Pull, build, up, migrate, cache |
| `scripts/artisan.sh` | Run Artisan in the production `app` container |

```text
services:
  app       supervisord (serve :80, queue worker, scheduler)
            networks: treasurer-internal + proxy
            volumes: storage, backups, .env.prod → /.env
  pgsql     persistent data, healthcheck

networks:
  treasurer-internal   bridge
  proxy                external (Traefik discovery)

volumes:
  treasurer-pgsql
```

---

## Laravel `.env.prod`

Production values live in `household-treasurer/.env.prod` (gitignored). Start from `.env.prod.example`. Compose loads `.env.prod` (`--env-file`) and mounts it into the app container as `.env`.

On the VPS, fill at least:

- `APP_KEY` (`php artisan key:generate`)
- `DB_PASSWORD`
- SMTP (`MAIL_HOST`, `MAIL_USERNAME`, `MAIL_PASSWORD`) if you want backup mail

---

## Backups

Backups use [spatie/laravel-backup](https://github.com/spatie/laravel-backup). The scheduler runs `backup:run` daily at 03:00 Europe/Warsaw in production (see `bootstrap/app.php`).

On the VPS, archives are stored **outside the app directory**:

```text
/storage/household-treasurer-backups/   ← host (persistent)
        ↓ mounted into container as
/var/www/html/storage/app/backups/
```

`docker-compose.prod.yml` mounts the host path via `BACKUP_HOST_DIR` (default `/storage/household-treasurer-backups`).

### One-time setup (VPS)

```bash
sudo mkdir -p /storage/household-treasurer-backups
sudo chown -R "$USER:$USER" /storage/household-treasurer-backups
```

`bootstrap-vps.sh` creates this directory automatically on new servers.

### Test a backup manually

```bash
cd /srv/apps/household-treasurer
./scripts/artisan.sh backup:run --only-db
ls -la /storage/household-treasurer-backups/
```

---

## Deploy

### First deploy (on VPS)

```bash
cd /srv/apps/household-treasurer
git checkout development
cp .env.prod.example .env.prod
# Edit .env.prod: DB_PASSWORD, mail, then generate APP_KEY

docker compose --env-file .env.prod -f docker-compose.prod.yml run --rm app php artisan key:generate
./scripts/deploy.sh
```

`scripts/deploy.sh` deploys the `development` branch by default (`PRODUCTION_BRANCH`).

### Updates (from household-treasurer repo)

```bash
cd /srv/apps/household-treasurer
./scripts/deploy.sh
```

### Updates (from infra repo)

```bash
cd /srv/infra
./scripts/deploy-household-treasurer.sh
```

Uses `VPS_TREASURER_DIR` from infra `.env` (default `/srv/apps/household-treasurer`).

---

## Verify

```bash
curl -I https://treasurer.kostecki.dev/up
```

Expected: `HTTP/2 200`

Check supervisord processes:

```bash
docker compose --env-file .env.prod -f docker-compose.prod.yml exec -T app supervisorctl status
```

Expected: `php`, `queue`, `scheduler` all `RUNNING`.

---

## Local dev — Sail

In household-treasurer repo:

```bash
./vendor/bin/sail up -d
./vendor/bin/sail npm run dev
```

Sail and Traefik on VPS operate independently.
