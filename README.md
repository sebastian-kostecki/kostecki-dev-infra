# kostecki-dev-infra

Traefik reverse proxy and deploy scripts for **kostecki.dev**.

This repo contains **infrastructure only** — no application code. Apps (landing, household-treasurer, root-keeper, vaultwarden) live in separate repos and attach via Traefik labels. **Exception:** Backrest (backup UI) is a stack template here (`stacks/backrest/`), copied onto the VPS by a deploy script — not a separate GitHub repo.

## Repositories

| Repo | Status | Path on VPS |
|------|--------|-------------|
| **kostecki-dev-infra** (this) | on GitHub | `/srv/infra` |
| **kostecki-dev-landing** | on GitHub | `/srv/apps/landing` |
| household-treasurer | on GitHub | `/srv/apps/household-treasurer` |
| root-keeper | on GitHub | `/srv/apps/root-keeper` |
| **kostecki-dev-vaultwarden** | on GitHub | `/srv/apps/vaultwarden` |
| Backrest | template in this repo | `/srv/apps/backrest` |

wallet-master is removed. Teardown: [docs/remove-wallet-master.md](docs/remove-wallet-master.md).

## Documentation

| File | When to read |
|------|--------------|
| [docs/SETUP.md](docs/SETUP.md) | **Start here** — Traefik + VPS deploy checklist |
| [docs/LANDING.md](docs/LANDING.md) | **Landing repo** — Node, pnpm, Docker, local dev |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Overview (current + planned) |
| [docs/ADDING-AN-APP.md](docs/ADDING-AN-APP.md) | How to attach another app to Traefik |
| [docs/household-treasurer.md](docs/household-treasurer.md) | Laravel + Inertia + PostgreSQL at treasurer.kostecki.dev |
| [docs/root-keeper.md](docs/root-keeper.md) | Laravel + Inertia + PostgreSQL at genealog.kostecki.dev |
| [docs/vaultwarden.md](docs/vaultwarden.md) | Vaultwarden at vault.kostecki.dev |
| [docs/backups.md](docs/backups.md) | Vaultwarden dump + Backrest |
| [docs/remove-wallet-master.md](docs/remove-wallet-master.md) | Teardown wallet-master on the VPS |
| [docs/remove-obsidian-livesync.md](docs/remove-obsidian-livesync.md) | Teardown CouchDB LiveSync on the VPS |

## Quick start (VPS)

```bash
./scripts/bootstrap-vps.sh
cp .env.example .env   # set ACME_EMAIL
docker network create proxy
docker compose up -d
```

Deploy landing (after [Docker setup in landing repo](docs/LANDING.md)):

```bash
./scripts/deploy-landing.sh
```

Uses **pnpm** — install on VPS before first landing deploy (`corepack enable && corepack prepare pnpm@latest --activate`).

The archive counter on the landing is refreshed daily by `landing-refresh.timer` (install once: `sudo ./scripts/install-landing-refresh-timer.sh`, details in [docs/LANDING.md](docs/LANDING.md#daily-archive-counter-refresh)).
