# Setup — Traefik + landing

Step-by-step guide to deploy **kostecki-dev-infra** and the landing page on **kostecki.dev**.

- Landing repo details: [LANDING.md](./LANDING.md)
- Other apps: [ADDING-AN-APP.md](./ADDING-AN-APP.md) · Laravel: [household-treasurer.md](./household-treasurer.md) · [root-keeper.md](./root-keeper.md) · Vaultwarden: [vaultwarden.md](./vaultwarden.md) · Backups: [backups.md](./backups.md)

---

## Checklist

### kostecki-dev-infra

- [x] Files in repo (docker-compose, scripts, .env.example)
- [x] Push to GitHub

### kostecki-dev-landing

- [x] Vue 3 project created (`pnpm create vue`)
- [x] Local dev works (`pnpm dev`)
- [x] Push to GitHub
- [x] Add `docker-compose.yml` + `docker/nginx.conf` — see [LANDING.md](./LANDING.md)
- [x] Push Docker files to GitHub

### VPS

- [ ] DNS: `kostecki.dev`, `www.kostecki.dev` → VPS IP
- [ ] Node.js + pnpm on VPS (for build)
- [ ] `./scripts/bootstrap-vps.sh`
- [ ] Clone infra → `/srv/infra`, `docker compose up -d`
- [ ] Clone landing → `/srv/apps/landing`, then `./scripts/deploy-landing.sh`
- [ ] `sudo ./scripts/install-landing-refresh-timer.sh` (daily archive counter refresh — see [LANDING.md](./LANDING.md#daily-archive-counter-refresh))
- [ ] https://kostecki.dev works with SSL

### household-treasurer

- [ ] DNS: `treasurer.kostecki.dev` → VPS IP (Cloudflare Proxied)
- [ ] Clone household-treasurer → `/srv/apps/household-treasurer`
- [ ] Configure `.env.prod` (see [household-treasurer.md](./household-treasurer.md))
- [ ] `docker compose -f docker-compose.prod.yml up -d`
- [ ] https://treasurer.kostecki.dev/up returns 200

### root-keeper

- [ ] DNS: `genealog.kostecki.dev` → VPS IP (Cloudflare Proxied)
- [ ] Clone root-keeper → `/srv/apps/root-keeper`
- [ ] Configure `.env.prod` (see [root-keeper.md](./root-keeper.md))
- [ ] `docker compose --env-file .env.prod -f docker-compose.prod.yml up -d`
- [ ] https://genealog.kostecki.dev/up returns 200

### vaultwarden

- [ ] DNS: `vault.kostecki.dev` → VPS IP (Cloudflare Proxied)
- [ ] Clone kostecki-dev-vaultwarden → `/srv/apps/vaultwarden`
- [ ] Configure `.env` (see [vaultwarden.md](./vaultwarden.md))
- [ ] `docker compose up -d`
- [ ] First user via `/admin` invite
- [ ] https://vault.kostecki.dev works with SSL

### Remove wallet-master (if still on the VPS)

- [ ] Follow [remove-wallet-master.md](./remove-wallet-master.md)

### Remove LiveSync (if still on the VPS)

- [ ] Follow [remove-obsidian-livesync.md](./remove-obsidian-livesync.md)

### Backups (dump + Backrest)

- [ ] `/storage` mounted from the backup host
- [ ] DNS: `backup.kostecki.dev` → VPS IP (Cloudflare **Proxied**)
- [ ] `sudo ./scripts/install-vaultwarden-dump-timer.sh`
- [ ] `./scripts/deploy-backrest.sh` and first-run UI — see [backups.md](./backups.md)

---

## Purpose of this repo

- Traefik (reverse proxy, SSL)
- Deploy scripts
- Documentation
- Stack templates that have no separate app repo (currently Backrest)

**Does not include:** Vue code, Laravel. Landing lives in **kostecki-dev-landing**. Backrest is the documented exception: templates here, config and data on the VPS.

---

## Repo structure

```text
kostecki-dev-infra/
├── README.md
├── .env.example
├── .gitignore
├── docker-compose.yml          # Traefik only
├── docker-compose.dev.yml      # optional, local dev
├── stacks/
│   └── backrest/               # restic UI template copied to the VPS
├── systemd/                    # vaultwarden-dump + landing-refresh timers (installed once on VPS)
├── scripts/
│   ├── lib/
│   ├── bootstrap-vps.sh
│   ├── dump-vaultwarden.sh
│   ├── install-vaultwarden-dump-timer.sh
│   ├── install-landing-refresh-timer.sh
│   ├── refresh-landing.sh      # run by landing-refresh.timer
│   ├── deploy-landing.sh       # uses pnpm
│   ├── uninstall-wallet-master.sh
│   ├── deploy-household-treasurer.sh
│   ├── deploy-root-keeper.sh
│   ├── deploy-vaultwarden.sh
│   └── deploy-backrest.sh
└── docs/
    ├── SETUP.md
    ├── LANDING.md
    ├── ARCHITECTURE.md
    ├── ADDING-AN-APP.md
    ├── backups.md
    ├── remove-wallet-master.md
    ├── remove-obsidian-livesync.md
    ├── wallet-master.md
    ├── household-treasurer.md
    ├── root-keeper.md
    └── vaultwarden.md
```

---

## `.env` (infra only)

```env
ACME_EMAIL=admin@kostecki.dev
VPS_LANDING_DIR=/srv/apps/landing
VPS_TREASURER_DIR=/srv/apps/household-treasurer
VPS_ROOT_KEEPER_DIR=/srv/apps/root-keeper
VPS_BACKREST_DIR=/srv/apps/backrest
DOMAIN=kostecki.dev
DOMAIN_WWW=www.kostecki.dev
```

On VPS: `cp .env.example .env`

---

## VPS — first run

```bash
# Bootstrap (Docker, firewall, proxy network, directories)
git clone git@github.com:USER/kostecki-dev-infra.git /srv/infra
cd /srv/infra
./scripts/bootstrap-vps.sh
cp .env.example .env
docker compose up -d

# Verify
docker compose ps
docker compose logs traefik
```

DNS must point to the VPS **before** Let's Encrypt can issue a certificate.

---

## VPS — landing deploy

Prerequisites: [LANDING.md](./LANDING.md) (Node, pnpm, Docker files in landing repo).

```bash
# One-time on VPS: Node + pnpm
curl -fsSL https://get.docker.com | sh   # if not done by bootstrap
# Install Node (e.g. via nvm) — see LANDING.md

corepack enable
corepack prepare pnpm@latest --activate

# Deploy landing
git clone git@github.com:USER/kostecki-dev-landing.git /srv/apps/landing
/srv/infra/scripts/deploy-landing.sh
```

Updates from `/srv/infra`:

```bash
./scripts/deploy-landing.sh
```

Daily archive counter refresh (once): `sudo ./scripts/install-landing-refresh-timer.sh` — see [LANDING.md](./LANDING.md#daily-archive-counter-refresh).

---

## VPS — wallet-master teardown

wallet-master is **not** a current app. If it is still on the VPS: [remove-wallet-master.md](./remove-wallet-master.md) (`./scripts/uninstall-wallet-master.sh`). Historical labels: [wallet-master.md](./wallet-master.md).

---

## VPS — household-treasurer deploy

Prerequisites: [household-treasurer.md](./household-treasurer.md) (Docker files in household-treasurer repo, Cloudflare DNS).

```bash
# One-time on VPS
git clone git@github.com:sebastian-kostecki/household-treasurer.git /srv/apps/household-treasurer
cd /srv/apps/household-treasurer
git checkout development
cp .env.prod.example .env.prod
# Edit .env.prod with production secrets

docker compose --env-file .env.prod -f docker-compose.prod.yml run --rm app php artisan key:generate
./scripts/deploy.sh
```

Updates from `/srv/infra`:

```bash
./scripts/deploy-household-treasurer.sh
```

---

## VPS — root-keeper deploy

Prerequisites: [root-keeper.md](./root-keeper.md) (Docker files in root-keeper repo, Cloudflare DNS). `scripts/deploy.sh` in the app repo is a follow-up.

```bash
# One-time on VPS
git clone git@github.com:sebastian-kostecki/root-keeper.git /srv/apps/root-keeper
cd /srv/apps/root-keeper
cp .env.prod.example .env.prod
# Edit .env.prod with production secrets

docker compose --env-file .env.prod -f docker-compose.prod.yml run --rm app php artisan key:generate
./scripts/deploy.sh
```

Updates from `/srv/infra`:

```bash
./scripts/deploy-root-keeper.sh
```

---

## VPS — Backrest + Vaultwarden dump

Prerequisites: [backups.md](./backups.md) (Cloudflare **Proxied** for `backup.kostecki.dev`, Vaultwarden already running).

```bash
sudo ./scripts/install-vaultwarden-dump-timer.sh
./scripts/deploy-backrest.sh
```

If CouchDB LiveSync is still running: [remove-obsidian-livesync.md](./remove-obsidian-livesync.md).

---

## Troubleshooting

**403 / 404, but `docker exec landing wget http://127.0.0.1/` works** — Traefik cannot discover containers (Docker API mismatch). Check logs:

```bash
docker logs traefik 2>&1 | grep "client version"
```

If you see `client version 1.24 is too old`, your host runs **Docker 29+** and Traefik must be **v3.6.1+** (this repo uses `traefik:v3.6.6`). `DOCKER_API_VERSION` does **not** fix this.

```bash
cd /srv/infra
git pull
docker compose pull traefik
docker compose up -d --force-recreate traefik
docker logs traefik 2>&1 | tail -10   # should show no ERR about client version
```

**SSL not issued** — DNS → VPS, port 80 open, logs: `docker compose logs traefik`

**Traefik does not see landing** — container on `proxy` network, labels `traefik.enable=true` and `traefik.docker.network=proxy`

**404** — missing `dist/index.html` or missing `try_files` in nginx

**Redirect loop** — landing nginx must not force HTTPS (Traefik handles TLS)

**Build fails on VPS** — check Node version (`^20.19.0 || >=22.12.0` in landing `package.json`), pnpm installed

---

## Next application?

See [ADDING-AN-APP.md](./ADDING-AN-APP.md) — typical apps need **no changes to Traefik compose**, only a new repo + Traefik labels + DNS. Backrest is an exception: templates under `stacks/` plus a deploy script.
