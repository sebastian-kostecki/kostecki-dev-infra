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
       ├── treasurer.kostecki.dev
       │   household-treasurer (Laravel + Inertia)   ← household-treasurer repo
       │
       ├── genealog.kostecki.dev
       │   root-keeper (Laravel + Inertia)   ← root-keeper repo
       │
       ├── vault.kostecki.dev
       │   vaultwarden   ← kostecki-dev-vaultwarden repo
       │
       └── backup.kostecki.dev
           backrest (restic UI)   ← stacks/backrest in this repo
```

| Layer | Repo | Domain |
|-------|------|--------|
| Proxy | kostecki-dev-infra | — |
| Landing | kostecki-dev-landing | kostecki.dev |
| household-treasurer | household-treasurer | treasurer.kostecki.dev |
| root-keeper | root-keeper | genealog.kostecki.dev |
| vaultwarden | kostecki-dev-vaultwarden | vault.kostecki.dev |
| Backrest | kostecki-dev-infra (`stacks/backrest`) | backup.kostecki.dev |

Public exposure: **Traefik only** (ports 80/443).

wallet-master (`budget.kostecki.dev`) was removed. Teardown: [remove-wallet-master.md](./remove-wallet-master.md).

Details: [household-treasurer.md](./household-treasurer.md) · [root-keeper.md](./root-keeper.md) · [vaultwarden.md](./vaultwarden.md) · [backups.md](./backups.md)

---

## Repositories

```text
kostecki-dev-infra/          ← Traefik, scripts, Backrest stack templates (this repo)
kostecki-dev-landing/        ← Vue landing
household-treasurer/         ← Laravel + Inertia + PostgreSQL
root-keeper/                 ← Laravel + Inertia + PostgreSQL
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
    ├── vaultwarden/    ← kostecki-dev-vaultwarden
    ├── household-treasurer/ ← household-treasurer
    ├── root-keeper/    ← root-keeper
    └── backrest/       ← copied from stacks/backrest (not a clone)

/storage/                   ← network mount (not the VPS system disk)
├── household-treasurer-backups/  ← Spatie
├── root-keeper-backups/    ← Spatie
├── restic/vaultwarden/     ← restic repo (Backrest)
└── backup-staging/vaultwarden/  ← SQLite dump before restic
```

Host systemd dumps Vaultwarden at 03:00; Backrest snapshots staging at 03:15. Ops: [backups.md](./backups.md).

Host systemd also runs `landing-refresh.timer` at 04:30: it rebuilds the landing when the archive counts on GitHub changed. Ops: [LANDING.md](./LANDING.md#daily-archive-counter-refresh).

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

Laravel-specific: [household-treasurer.md](./household-treasurer.md) · [root-keeper.md](./root-keeper.md)

Third-party image example: [vaultwarden.md](./vaultwarden.md)

Infra-owned stack (copied by deploy script): [backups.md](./backups.md) (Backrest)

Removed apps: [remove-wallet-master.md](./remove-wallet-master.md) · [remove-obsidian-livesync.md](./remove-obsidian-livesync.md)

---

## Security (minimum)

- Firewall: 22, 80, 443
- HTTPS via Traefik
- `.env` on server only
- Traefik dashboard not public without auth
- Backrest UI uses its own password; treat `backup.kostecki.dev` as sensitive
