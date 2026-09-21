# Backupy Vaultwarden (dump + Backrest)

Dwa zegary, jeden cel: **spójny SQLite** na `/storage`, potem **restic** sterowany z UI Backrest.

Household-treasurer i root-keeper zostają przy Spatie (`/storage/household-treasurer-backups`, `/storage/root-keeper-backups`). Ten dokument ich nie dotyczy.

```text
03:00  systemd vaultwarden-dump     →  /storage/backup-staging/vaultwarden
03:15  Backrest plan (cron)         →  /storage/restic/vaultwarden
       UI                            →  https://backup.kostecki.dev
```

Dump jest na hoście (Docker + sqlite), **nie** w kontenerze Backrest — obraz zostaje vanilla, bez `docker.sock`.

## Layout

```text
/storage/
├── household-treasurer-backups/    ← Spatie
├── root-keeper-backups/            ← Spatie
├── restic/vaultwarden/             ← repo restic (szyfrowane)
└── backup-staging/vaultwarden/     ← dump; Backrest montuje to jako /userdata

/srv/apps/backrest/                 ← compose skopiowany z stacks/backrest
├── docker-compose.yml
├── data/  config/  cache/  tmp/    ← stan UI; deploy nie kasuje config/
```

`/storage` musi być **mountpoint** (`mountpoint /storage`). Inaczej dump wychodzi z błędem.

## Co robi dump (03:00)

Skrypt [scripts/dump-vaultwarden.sh](../scripts/dump-vaultwarden.sh):

1. Czyści i tworzy staging.
2. `rsync` z volume `vaultwarden_vw-data` **bez** `db.sqlite3*` (wal/shm też).
3. `sqlite3 .backup` do `staging/db.sqlite3` przy włączonym Vaultwarden.

Staging **zostaje** do następnego dumpa (Backrest czyta go o 03:15).

Instalacja timera (raz, jako root):

```bash
cd /srv/infra
sudo ./scripts/install-vaultwarden-dump-timer.sh
```

Ręcznie:

```bash
sudo systemctl start vaultwarden-dump.service
journalctl -u vaultwarden-dump.service -e
ls -la /storage/backup-staging/vaultwarden/
```

Jeśli kiedyś włączałeś stare `backup-vaultwarden.timer` / `backup-obsidian-livesync.timer`, instalator próbuje je wyłączyć. Ręcznie:

```bash
sudo systemctl disable --now backup-vaultwarden.timer backup-obsidian-livesync.timer
sudo rm -f /etc/systemd/system/backup-vaultwarden.* /etc/systemd/system/backup-obsidian-livesync.*
sudo systemctl daemon-reload
```

## Backrest (03:15 + UI)

### DNS

| Record | Type | Value | Proxy |
|--------|------|--------|--------|
| `backup` | A | VPS IP | **Proxied** (orange cloud) |

SSL: Cloudflare Full (strict), cert z Traefika (Let's Encrypt). **Nie** publikuj portu 9898 na hoście.

Hasło UI Backrest ustawiasz przy **pierwszym** wejściu. Traktuj `backup.kostecki.dev` jak panel admina (długie hasło, w menedżerze haseł). Nie commituj `config/config.json`.

### Deploy

```bash
cd /srv/infra
git pull
./scripts/deploy-backrest.sh
```

Skrypt nadpisuje tylko `docker-compose.yml`. Katalog `config/` z planami restic zostaje.

Obraz: `ghcr.io/garethgeorge/backrest:v1.14.1` (pin w [stacks/backrest/docker-compose.yml](../stacks/backrest/docker-compose.yml)).

### Pierwsze uruchomienie w UI

1. Otwórz `https://backup.kostecki.dev`, ustaw hasło instancji.
2. **Repo:** typ lokalny, ścieżka w kontenerze `/repos/vaultwarden` (to jest `/storage/restic/vaultwarden` na hoście). Ustaw **hasło restic** (inne niż hasło UI). Zapisz je w menedżerze haseł — bez niego snapshotów nie odczytasz z CLI ani po reinstalacji Backrest.
3. Jeśli katalog repo jest pusty, Backrest zrobi `restic init`. Jeśli już jest `config` restic, **zaimportuj** istniejące repo tym samym hasłem.
4. **Plan:** ścieżka do backupu `/userdata` (dump). Harmonogram cron: `15 3 * * *` (03:15 czasu `Europe/Warsaw`). Retention: **7 daily / 4 weekly / 6 monthly**, włącz prune/forget zgodnie z UI (GFS).
5. Po pierwszym dumpie: **Backup now**. W UI powinna pojawić się historia joba i snapshot.

### CLI restic (to samo repo)

Hasło restic z kroku 2, nie hasło UI:

```bash
export RESTIC_REPOSITORY=/storage/restic/vaultwarden
export RESTIC_PASSWORD='...'   # or RESTIC_PASSWORD_FILE=/root/restic-vaultwarden.password
restic snapshots
```

Backrest trzyma swoje restic w kontenerze; na hoście `apt restic` (bootstrap) wystarczy do listowania/restore.

## Restore Vaultwarden

**Z UI:** Restores w Backrest → wybierz snapshot → pliki z `/userdata` (w snapshotcie mogą być w korzeniu `/userdata` albo ze ścieżką kontenera). Ściągnij/`restore` do katalogu tymczasowego, potem wgraj do volume (poniżej).

**Z CLI** (przykład `latest`):

```bash
sudo RESTIC_REPOSITORY=/storage/restic/vaultwarden RESTIC_PASSWORD_FILE=/path/to/restic.password \
  restic restore latest --target /tmp/vw-restore
sudo find /tmp/vw-restore -name db.sqlite3
```

Korzeń przywróconych danych to katalog, w którym leży `db.sqlite3` (często `/tmp/vw-restore/userdata` albo zagnieżdżony staging).

```bash
docker stop vaultwarden
SRC=/tmp/vw-restore/userdata   # popraw po find
docker run --rm \
  -v vaultwarden_vw-data:/data \
  -v "${SRC}:/restore:ro" \
  alpine:3.20 \
  sh -c 'rm -rf /data/* /data/.[!.]* /data/..?* ; cp -a /restore/. /data/'
docker start vaultwarden
```

Nazwę volume potwierdź: `docker volume ls | grep vw`. Smoke-check: `https://vault.kostecki.dev`.

## Logi

```bash
systemctl status vaultwarden-dump.timer
journalctl -u vaultwarden-dump.service
docker logs backrest --tail 100
```

Historia snapshotów i błędów restic: UI Backrest. Mail/Healthchecks: nie skonfigurowane.

## LiveSync

CouchDB został wycofany. Teardown: [remove-obsidian-livesync.md](./remove-obsidian-livesync.md).
