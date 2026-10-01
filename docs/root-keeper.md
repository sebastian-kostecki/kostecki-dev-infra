# root-keeper deployment

Deployment guide for Laravel + Inertia (React) + PostgreSQL on **genealog.kostecki.dev**.

Related: [ADDING-AN-APP.md](./ADDING-AN-APP.md) · [ARCHITECTURE.md](./ARCHITECTURE.md)

`docker-compose.prod.yml`, `docker/8.5/Dockerfile.prod`, `scripts/deploy.sh`, and `.env.prod.example` live in the [root-keeper](https://github.com/sebastian-kostecki/root-keeper) repo. `deploy-root-keeper.sh` calls `./scripts/deploy.sh`.

Keep Sail (`compose.yaml`, `docker/8.5/Dockerfile`) **local only**. On the VPS use `docker-compose.prod.yml`. Do not build production from the Sail Dockerfile (xdebug / Playwright).

---

## DNS

```text
genealog.kostecki.dev  →  VPS IP (Cloudflare Proxied)
```

---

## Cloudflare (Proxied)

- A record for `genealog` → VPS IP, **Proxied** (orange cloud) — kept intentionally for Cloudflare's DDoS / bot protection in front of the origin
- SSL/TLS mode: **Full (strict)**
- Origin TLS is handled by Traefik (Let's Encrypt)
- Note: this means traffic and uploaded sources pass through Cloudflare as a third party. That trade-off (DDoS/bot protection vs. no third parties) is tracked against root-keeper's PRD NFR separately — see `context/changes/production-data-safety/plan.md` in the root-keeper repo.

Verify:

```bash
curl -svI https://genealog.kostecki.dev/up
# expected: HTTP/2 200, server: cloudflare, cf-ray present (confirms traffic is going through Cloudflare as intended)
```

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
| `scripts/deploy.sh` | Pull, build, up, migrate, cache |
| `scripts/artisan.sh` | Run Artisan in the production `app` container |

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

Production values live in `root-keeper/.env.prod` (must be gitignored). Start from `.env.prod.example`. Compose loads `.env.prod` (`--env-file`) and mounts it into the app container as `.env`.

Set `DB_CONNECTION=pgsql` — do not copy the local Sail `.env` (`sqlite`).

On the VPS, fill at least:

- `APP_KEY` (`php artisan key:generate`)
- `DB_PASSWORD`
- SMTP (`MAIL_HOST`, `MAIL_USERNAME`, `MAIL_PASSWORD`) if you want backup mail

---

## Backups

[spatie/laravel-backup](https://github.com/spatie/laravel-backup) backs up **PostgreSQL and `storage/app`** (source files), same shape as household-treasurer — not DB-only. Schedule: `backup:run` at **03:45**, `backup:clean` at **04:15**, `backup:monitor` at **04:45** Europe/Warsaw so it does not collide with treasurer (03:00), Vaultwarden dump (03:00), or Backrest (03:15).

On the VPS, archives go **outside the app directory**:

```text
/storage/root-keeper-backups/   ← host (persistent, network mount)
        ↓ mounted into container as
/var/www/html/storage/app/backups/
```

`docker-compose.prod.yml` mounts the host path via `BACKUP_HOST_DIR` (default `/storage/root-keeper-backups`).

Archives are encrypted (`backup.backup.encryption` = `default`, AES-256 ZIP) using `BACKUP_ARCHIVE_PASSWORD` from `.env.prod` — keep a copy of that password off this VPS (password manager, etc.); it's the only way to decrypt backups if this host is lost. `scripts/deploy.sh` refuses to deploy if `BACKUP_ARCHIVE_PASSWORD`, `MAIL_HOST`, or `BACKUP_NOTIFICATION_MAIL` is empty, or if `BACKUP_OFFSITE_ENABLED` is truthy (`production_assert_env_ready` in `scripts/lib/production-deploy.sh`). It also runs `backup:run --only-db` against the running `app` container before `up -d`/`migrate --force`, so every migration has a fresh DB-only backup ahead of it.

### One-time setup (VPS)

```bash
sudo mkdir -p /storage/root-keeper-backups
sudo chown -R "$USER:$USER" /storage/root-keeper-backups
```

`bootstrap-vps.sh` creates this directory automatically on new servers.

---

## Restore

Drilled on 2026-09-22 and again on 2026-10-01 (after the scans → sources rename, with the 8 domain tables, `migrations` and a source original + thumbnail compared by sha256). 2026-09-22 run: decrypted an archive with the off-VPS password, restored the DB dump into a throwaway Postgres 18, and confirmed a test file survives a rebuild. Steps below are what was actually run, not a generic tutorial — repeat them for a real restore.

### Where things are

- Archives: `/storage/root-keeper-backups/<APP_NAME>/<timestamp>.zip` (note the `APP_NAME` subfolder, e.g. `Root Keeper` — not directly under `root-keeper-backups/`)
- Inside the archive: `db-dumps/postgresql-<DB_DATABASE>.sql` (plain `pg_dump` SQL, owned by the `DB_USERNAME` role) and source originals and thumbnails under `private/sources/<tree_id>/` and `private/sources/<tree_id>/thumbnails/` (`relative_path` is `storage/app`, so paths inside the zip mirror `storage/app/`)
- Password: `BACKUP_ARCHIVE_PASSWORD` from `.env.prod` — **only** the off-VPS copy can be trusted if the VPS itself is compromised or lost

### Decrypt an archive

`encryption=default` is ZIP **AES-256** — `unzip` cannot open it, use `7z` (no host install needed, run it in a throwaway container):

```bash
mkdir -p /tmp/restore-drill
docker run --rm \
  -v "/storage/root-keeper-backups/<APP_NAME>/<archive>.zip:/archive.zip:ro" \
  -v /tmp/restore-drill:/out \
  alpine sh -c "apk add --no-cache p7zip >/dev/null && 7z x -p'<password from off-VPS copy>' -o/out /archive.zip"
```

Verify a restored file bit-for-bit against the original with `sha256sum`.

### Load the DB dump — Postgres 18 only

`Dockerfile.prod` pins `postgresql-client-18` to server `postgres:18-alpine` — never restore into a different major version. Use a disposable container, **not** the `keeper-pgsql` volume or the `proxy` network:

```bash
docker run -d --name restore-drill-pg \
  -e POSTGRES_PASSWORD=<any-temp-password> \
  -e POSTGRES_USER=<DB_USERNAME from .env.prod, e.g. keeper> \
  -e POSTGRES_DB=<DB_DATABASE from .env.prod, e.g. root_keeper> \
  postgres:18-alpine

docker cp /tmp/restore-drill/db-dumps/postgresql-<DB_DATABASE>.sql restore-drill-pg:/tmp/dump.sql
docker exec -e PGPASSWORD=<temp-password> restore-drill-pg \
  psql -U <DB_USERNAME> -d <DB_DATABASE> -v ON_ERROR_STOP=1 -f /tmp/dump.sql
```

The dump's `ALTER TABLE ... OWNER TO <DB_USERNAME>` statements fail under `ON_ERROR_STOP=1` if the container's `POSTGRES_USER` doesn't match `DB_USERNAME` in `.env.prod` — match it and re-run.

Compare table list and row counts against production. Run the same query on both (throwaway container with `psql`, production via `./scripts/artisan.sh tinker` or `psql`):

```sql
select 'users' t, count(*) from users union all
select 'trees', count(*) from trees union all
select 'people', count(*) from people union all
select 'events', count(*) from events union all
select 'event_participants', count(*) from event_participants union all
select 'sources', count(*) from sources union all
select 'event_source', count(*) from event_source union all
select 'parent_child_relations', count(*) from parent_child_relations union all
select 'migrations', count(*) from migrations;
```

```bash
docker exec -e PGPASSWORD=<temp-password> restore-drill-pg psql -U <DB_USERNAME> -d <DB_DATABASE> -c '\dt'
```

The full drill checklist (what to record, the `scans/%` leftover check, the cadence and the drill log) lives in root-keeper `context/foundation/test-plan.md` §6.3.

### Restore `private/` source files into a running app

Copy the extracted `private/` tree back into `storage/app/private` on the VPS (bind-mounted `./storage`, survives rebuilds — confirmed in the 2026-09-22 drill with `docker compose ... up -d --build` + `sha256sum` before/after).

### Full production restore (not drilled — do in this order if it's ever real)

1. `docker compose --env-file .env.prod -f docker-compose.prod.yml stop app`
2. Restore the DB dump into the **real** `pgsql` service/volume (same `psql -v ON_ERROR_STOP=1` approach, against `keeper-pgsql`, not a throwaway container)
3. Restore `private/` files into `storage/app/private`
4. `./scripts/deploy.sh` (or `docker compose ... up -d`)
5. Repeat the drill's verification (checksums, table counts, `curl -I https://genealog.kostecki.dev/up`) against the real restore before trusting it

### Cleanup after a drill

```bash
docker rm -f restore-drill-pg
rm -rf /tmp/restore-drill
```

---

## Deploy

### First deploy (on VPS)

Requires `scripts/deploy.sh` and `.env.prod.example` in the app repo.

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
