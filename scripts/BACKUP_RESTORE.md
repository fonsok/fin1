# FIN1 Backup & Restore

## Backups (automatisch)

- **Zeitplan:** Täglich um 3:00 Uhr (Cron)
- **Speicherort auf dem Server:** `/home/io/fin1-backups/<BACKUP_ID>/`
- **Inhalt:** MongoDB, PostgreSQL, Redis, Config (docker-compose, .env, nginx.conf)
- **Aufbewahrung:** Backups älter als **14 Tage** werden gelöscht; es bleiben aber **immer mindestens 100** Backups erhalten (siehe `scripts/backup.sh`: `RETENTION_DAYS=14`, `MIN_BACKUPS_KEEP=100`).

## Backup manuell auslösen

Das gleiche Script wie beim nächtlichen Cron-Lauf kann jederzeit per Terminal ausgeführt werden.

**Auf dem Server (nach SSH-Login):**

```bash
ssh io@192.168.178.20
~/fin1-server/scripts/backup.sh
```

**Direkt von außen (ein Befehl):**

```bash
ssh io@192.168.178.20 '~/fin1-server/scripts/backup.sh'
```

Es wird ein neues Verzeichnis unter `~/fin1-backups/` mit Zeitstempel erstellt (z. B. `20260307_141523`). Ausgabe und Fehler werden in `/home/io/fin1-backups/backup.log` geschrieben.

## Bestimmte Backup-Version wiederherstellen

### 1. Auf dem Server einloggen

```bash
ssh io@192.168.178.20
```

### 2. Verfügbare Backups anzeigen

```bash
cd /home/io/fin1-server
./scripts/restore-from-backup.sh
# oder
./scripts/restore-from-backup.sh --list
```

Beispielausgabe:

```
Available backup versions (newest first):
----------------------------------------
  20260223_124944  (164K)
  20260223_124745  (164K)
  20260223_113411  (164K)

Restore with: ./scripts/restore-from-backup.sh <BACKUP_ID>
```

### 3. Vollständigen Restore ausführen

**Achtung:** Überschreibt die aktuellen Daten von MongoDB, PostgreSQL und Redis.

```bash
./scripts/restore-from-backup.sh 20260223_124944
```

- Zur Bestätigung `yes` eingeben.
- Optional: Am Ende nach Config-Wiederherstellung mit `y` bestätigen (sonst nur Datenbanken).

### 4. Nur Config-Dateien wiederherstellen

```bash
./scripts/restore-from-backup.sh 20260223_124944 --config-only
```

Stellt nur `backend/.env`, `backend/nginx/nginx.conf` und `docker-compose.production.yml` aus dem Backup wieder her. Keine Datenbanken.

### 5. Nicht-interaktiv (z.B. für Skripte)

```bash
RESTORE_CONFIRM=yes RESTORE_CONFIG=yes ./scripts/restore-from-backup.sh 20260223_124944
```

- `RESTORE_CONFIRM=yes` – Bestätigung überspringen
- `RESTORE_CONFIG=yes` – Config-Dateien mit wiederherstellen (bei vollem Restore)

## Ablauf beim Restore

| Schritt | Aktion |
|--------|--------|
| MongoDB | `mongorestore --drop`: bestehende Collections werden ersetzt |
| PostgreSQL | Datenbank `fin1_analytics` wird gelöscht, neu angelegt und Dump eingespielt |
| Redis | `dump.rdb` wird ersetzt, Container wird neu gestartet (kurzer Ausfall) |
| Config (optional) | Dateien werden in `/home/io/fin1-server/` kopiert |

Nach einem Restore ggf. Stack neu starten:

```bash
cd /home/io/fin1-server
docker compose -f docker-compose.production.yml up -d
```

## Restore-Test (empfohlen: quartalsweise)

Damit Backups im Ernstfall funktionieren, sollte regelmäßig ein Restore getestet werden. Konkrete Schritte und Priorisierung: **`Documentation/NAECHSTE_SCHRITTE_SERVER_OPS.md`** (Priorität 1).

Kurz: Backup-ID wählen (`--list`), Restore ausführen, Health-Checks prüfen, Ergebnis (Datum, BACKUP_ID, OK/Fehler) dokumentieren.

## Logs

- Backup-Log: `/home/io/fin1-backups/backup.log`
- Restore-Log: `/home/io/fin1-backups/restore.log`
