# Remove Obsidian LiveSync from the VPS

One-time teardown. The stack is **no longer** in this repo. Local Obsidian vaults are unchanged; only the CouchDB server and DNS go away.

Do this **after** `git pull` on `/srv/infra` so you are not following a deleted deploy guide.

## 1. Stop and remove containers

```bash
cd /srv/apps/obsidian-livesync
docker compose down
```

If the directory or compose file is already gone:

```bash
docker ps -a | grep -i couch
docker stop couchdb
docker rm couchdb
```

## 2. Delete the Docker volume

Confirm the name (compose project is usually the directory name):

```bash
docker volume ls | grep -i couch
```

Typical name: `obsidian-livesync_couchdb-data`.

```bash
docker volume rm obsidian-livesync_couchdb-data
```

This **destroys** server-side notes. Clients still have their local vault.

## 3. Delete the app directory

```bash
rm -rf /srv/apps/obsidian-livesync
```

That removes the CouchDB `.env` (password).

## 4. DNS (Cloudflare)

Delete the **A** record `obsidian` → VPS IP (was DNS only / grey cloud).

`https://obsidian.kostecki.dev` should stop resolving.

## 5. Obsidian client

Disable or uninstall the **Self-hosted LiveSync** plugin. The vault on disk stays. Use another sync method if you still want multi-device.

## 6. Optional leftover restic repo

If `/storage/restic/obsidian-livesync` exists from an unused backup experiment and you do not need it:

```bash
# only if you are sure — encrypted snapshots, unreadable without the password anyway
sudo rm -rf /storage/restic/obsidian-livesync
```

Do **not** remove `/storage/restic/vaultwarden`.
