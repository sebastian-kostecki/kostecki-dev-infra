# kostecki.dev architecture

## Current state

```text
Internet :443
      │
      ▼
┌─────────────┐
│ Traefik     │  kostecki-dev-infra, network: proxy
└──────┬──────┘
       │
       ├── kostecki.dev / www.kostecki.dev
       │   landing (nginx + dist/)   ← kostecki-dev-landing repo
       │
       ├── budget.kostecki.dev
       │   wallet-master (Laravel + Inertia)   ← wallet-master repo
       │
       ├── budget.kostecki.dev/app, /apps
       │   Reverb (WebSocket, same app container)
       │
       ├── vault.kostecki.dev
       │   vaultwarden   ← kostecki-dev-vaultwarden repo
       │
       ├── treasurer.kostecki.dev
       │   household-treasurer (Laravel + Inertia)   ← household-treasurer repo
       │
       └── backup.kostecki.dev
           backrest (restic UI)   ← stacks/backrest in this repo
```

| Layer | Repo | Domain |
|-------|------|--------|
| Proxy | kostecki-dev-infra | — |
| Landing | kostecki-dev-landing | kostecki.dev |
| wallet-master | wallet-master | budget.kostecki.dev (+ Reverb on /app, /apps) |
| vaultwarden | kostecki-dev-vaultwarden | vault.kostecki.dev |
| household-treasurer | household-treasurer | treasurer.kostecki.dev |
| Backrest | kostecki-dev-infra (`stacks/backrest`) | backup.kostecki.dev |

Public exposure: **Traefik only** (ports 80/443).

Details: [wallet-master.md](./wallet-master.md) · [household-treasurer.md](./household-treasurer.md) · [vaultwarden.md](./vaultwarden.md) · [backups.md](./backups.md)

---

## Repositories

```text
kostecki-dev-infra/          ← Traefik, scripts, Backrest stack templates (this repo)
kostecki-dev-landing/        ← Vue landing
wallet-master/               ← Laravel + Inertia + Reverb
household-treasurer/         ← Laravel + Inertia + PostgreSQL
kostecki-dev-vaultwarden/    ← Vaultwarden (upstream image)
```

Separate repo per application — **no** monorepo or submodules.

**Exception:** Backrest has no app repo. YAML lives in this repo and is copied to `/srv/apps/backrest`.

On VPS:

```text
/srv/
├── infra/              ← kostecki-dev-infra
└── apps/
    ├── landing/        ← kostecki-dev-landing
    ├── wallet-master/  ← wallet-master
    ├── vaultwarden/    ← kostecki-dev-vaultwarden
    ├── household-treasurer/ ← household-treasurer
    └── backrest/       ← copied from stacks/backrest (not a clone)

/storage/                   ← network mount (not the VPS system disk)
├── wallet-master-backups/  ← Spatie
├── household-treasurer-backups/  ← Spatie
├── restic/vaultwarden/     ← restic repo (Backrest)
└── backup-staging/vaultwarden/  ← SQLite dump before restic
```

Host systemd dumps Vaultwarden at 03:00; Backrest snapshots staging at 03:15. Ops: [backups.md](./backups.md).

---

## Landing stack

| Layer | Choice |
|-------|--------|
| Package manager | pnpm |
| Runtime | Node.js `^20.19.0 \|\| >=22.12.0` |
| Language | TypeScript |
| Framework | Vue 3 + Vite + vue-router |
| Production | `pnpm build` → `dist/` → nginx container |

Dev: `pnpm dev` (:5173), no Traefik required. Details: [LANDING.md](./LANDING.md).

---

## Why Traefik

- Routing via **labels** in each app's docker-compose,
- New app = labels + DNS — **no Traefik config edits**,
- Automatic Let's Encrypt.

Network (one-time): `docker network create proxy`

---

## Adding another application

Generic guide: [ADDING-AN-APP.md](./ADDING-AN-APP.md)

Laravel-specific: [wallet-master.md](./wallet-master.md) · [household-treasurer.md](./household-treasurer.md)

Third-party image example: [vaultwarden.md](./vaultwarden.md)

Infra-owned stack (copied by deploy script): [backups.md](./backups.md) (Backrest)

---

## Security (minimum)

- Firewall: 22, 80, 443
- HTTPS via Traefik
- `.env` on server only
- Traefik dashboard not public without auth
- Backrest UI uses its own password; treat `backup.kostecki.dev` as sensitive
