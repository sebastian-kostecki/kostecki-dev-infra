# Remove wallet-master from the VPS

Full teardown: containers, Docker volumes, app image, `/srv/apps/wallet-master`, and Spatie backups under `/storage/wallet-master-backups`.

Does **not** remove the shared Traefik `proxy` network or other apps.

Replacement product (no automatic data migration): [household-treasurer.md](./household-treasurer.md).

## 1. Run the uninstall script

From the infra repo on the VPS:

```bash
cd /srv/infra
./scripts/uninstall-wallet-master.sh
```

Or from the app repo:

```bash
cd /srv/apps/wallet-master
./scripts/uninstall.sh
```

Non-interactive:

```bash
./scripts/uninstall-wallet-master.sh --yes
```

Uses `VPS_WALLET_DIR` (default `/srv/apps/wallet-master`) and `BACKUP_HOST_DIR` (default `/storage/wallet-master-backups`).

If the app directory is already gone, the infra wrapper prints manual cleanup commands (`docker rm`, volume/image removal, `rm -rf`).

## 2. DNS (Cloudflare)

Delete the **A** record `budget` → VPS IP (Proxied / orange cloud).

`https://budget.kostecki.dev` should stop resolving (or no longer hit the app).

## 3. Verify

```bash
docker ps -a | grep -i wallet || true
docker volume ls | grep -i wallet || true
test ! -d /srv/apps/wallet-master && echo "app dir gone"
test ! -d /storage/wallet-master-backups && echo "backups gone"
curl -I https://budget.kostecki.dev
```

Expected: no wallet containers/volumes, directories absent, curl fails to reach the former app.
