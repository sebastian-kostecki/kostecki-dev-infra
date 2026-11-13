# kostecki-dev-landing

Guide for the **kostecki-dev-landing** repo — local development and production deploy behind Traefik.

Infra / Traefik: [SETUP.md](./SETUP.md)

---

## Stack (current project)

| Layer | Choice |
|-------|--------|
| Package manager | **pnpm** |
| Runtime | **Node.js** `^20.19.0 \|\| >=22.12.0` |
| Language | **TypeScript** |
| Framework | **Vue 3** + **Vite** |
| Routing | **vue-router** |
| Lint | ESLint + Prettier + oxlint |

Tailwind (or other CSS) can be added later — not required for deploy.

---

## Prerequisites — local machine

You need **Node.js** and **pnpm** to develop and build. Docker is only required for production-style serving (nginx container on VPS).

### Install Node.js

Use [nvm](https://github.com/nvm-sh/nvm) or [fnm](https://github.com/Schniz/fnm), then:

```bash
nvm install --lts
node -v   # must satisfy engines in package.json
```

### Enable pnpm

```bash
corepack enable
corepack prepare pnpm@latest --activate
pnpm -v
```

---

## Local development

```bash
git clone git@github.com:USER/kostecki-dev-landing.git
cd kostecki-dev-landing
pnpm install
pnpm dev
# → http://localhost:5173
```

Other scripts:

```bash
pnpm build      # production build → dist/
pnpm preview    # preview production build locally
pnpm lint       # ESLint + oxlint
```

Traefik on the VPS is **not required** for day-to-day work.

---

## Production build

```bash
pnpm install --frozen-lockfile
pnpm build
```

Output: `dist/` — static HTML, JS, CSS served by nginx in Docker.

Optional env (in landing repo `.env`):

```env
VITE_APP_URL=https://treasurer.kostecki.dev
```

Use for “Sign in” links to household-treasurer (can 404 until the app exists).

---

## Docker — add to landing repo (before VPS deploy)

These files are **not in the repo yet**. Add them to **kostecki-dev-landing**, commit, push.

### `docker-compose.yml`

```yaml
services:
  landing:
    image: nginx:alpine
    container_name: landing
    restart: unless-stopped
    volumes:
      - ./www:/usr/share/nginx/html:ro   # copy of dist/, synced by the deploy scripts
      - ./docker/nginx.conf:/etc/nginx/conf.d/default.conf:ro
    networks:
      - proxy
    labels:
      - traefik.enable=true
      - traefik.docker.network=proxy
      - traefik.http.routers.landing.rule=Host(`kostecki.dev`) || Host(`www.kostecki.dev`)
      - traefik.http.routers.landing.entrypoints=websecure
      - traefik.http.routers.landing.tls.certresolver=letsencrypt
      - traefik.http.services.landing.loadbalancer.server.port=80

networks:
  proxy:
    external: true
```

### `docker/nginx.conf`

```nginx
server {
    listen 80;
    root /usr/share/nginx/html;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }
}
```

vue-router history mode requires the SPA fallback above.

### `.gitignore`

Ensure `dist/` is **not** ignored if you deploy by building on VPS. Default Vue `.gitignore` often excludes `dist/` — that is fine when you always build on the server.

---

## VPS deploy

Requires Traefik running from **kostecki-dev-infra** ([SETUP.md](./SETUP.md)).

```bash
# One-time: Node + pnpm on VPS
corepack enable && corepack prepare pnpm@latest --activate

git clone git@github.com:USER/kostecki-dev-landing.git /srv/apps/landing
/srv/infra/scripts/deploy-landing.sh
```

Updates (from infra repo):

```bash
/srv/infra/scripts/deploy-landing.sh
```

The deploy builds into `dist/` and only then syncs it into `www/` (what nginx serves) with `rsync --delay-updates --delete-delay`, so a running or failed build never takes the site down. A failed build leaves the previous `www/` in place. Requires `rsync` (installed by `bootstrap-vps.sh`).

State in the landing checkout (all gitignored): `www/`, `.deploy/archive.json` (archive counts of the published build), `.deploy/lock` (a manual deploy and the timer never run at once; the second one fails instead of waiting).

---

## Daily archive counter refresh

The landing shows the number of folders in `context/archive` of root-keeper and household-treasurer. The number is fetched from the GitHub API **at build time only**, so without a rebuild it goes stale.

`landing-refresh.timer` runs `scripts/refresh-landing.sh` daily at 04:30 as the owner of `/srv/apps/landing` (root on the current VPS):

1. `ARCHIVE_STRICT=1 pnpm generate:archive` — fetches the counts. In strict mode a GitHub outage **fails the job** instead of falling back to the old count, and the site keeps its last build.
2. Compares the counts with `.deploy/archive.json`. Unchanged → exits 0, nothing is built.
3. Changed → `pnpm install --frozen-lockfile`, `pnpm build`, publish (same as the deploy above).

It does **not** `git pull`: code changes still go out only through `deploy-landing.sh`.

Install once, as root. The service runs as the owner of `/srv/apps/landing`; if that is not root, it must be in the `docker` group, and `LANDING_REFRESH_USER` must match it when set:

```bash
cd /srv/infra
sudo ./scripts/install-landing-refresh-timer.sh
```

The installer detects the directories of `node` and `pnpm` from that user's interactive shell (nvm is not loaded by systemd) and writes them into the unit's `PATH`. Override with `LANDING_NODE_PATH=/dir/one:/dir/two` if detection fails; `LANDING_REFRESH_USER` overrides the user.

Operations:

```bash
sudo systemctl start landing-refresh.service              # run now (blocks until done)
LANDING_REFRESH_FORCE=1 /srv/infra/scripts/refresh-landing.sh   # rebuild even if counts are unchanged
journalctl -u landing-refresh.service -n 50               # last run
systemctl list-timers landing-refresh.timer               # next/last run
systemctl --failed                                        # a GitHub outage or failed build shows up here
```

Tests for the shared logic: `bash scripts/lib/landing-lib.test.sh`.

---

## Test Traefik locally (optional)

1. In infra repo: `docker network create proxy && docker compose -f docker-compose.dev.yml up -d`
2. In landing `docker-compose.yml`, temporarily:
   ```yaml
   - traefik.http.routers.landing.rule=Host(`landing.localhost`)
   - traefik.http.routers.landing.entrypoints=web
   ```
3. `pnpm build && docker compose up -d`
4. Open `http://landing.localhost`

---

## Checklist

- [x] Project created (Vue 3 + TypeScript + Vite + vue-router)
- [x] `pnpm dev` works locally
- [x] On GitHub
- [x] `docker-compose.yml` + `docker/nginx.conf` added
- [ ] VPS: Node + pnpm installed
- [ ] VPS: build + `docker compose up -d`
- [ ] https://kostecki.dev live
