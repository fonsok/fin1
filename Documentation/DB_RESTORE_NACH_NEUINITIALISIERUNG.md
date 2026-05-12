# Datenbank-Wiederherstellung nach versehentlicher Neuinitialisierung

## Kurzfassung

- **Implementierung „2 % konfigurierbar“:** Die **Funktion ist Code** (Swift, Admin-Portal, Backend) und liegt im Repo bzw. auf dem Server. Sie ist **nicht** in der Datenbank gespeichert und daher **nicht verloren**. Nach einem DB-Reset nutzt die App weiterhin den Code; nur der **gespeicherte Wert** (z. B. 2 %) fehlt in der DB – die App verwendet dann den Default 2 %.
- **Verloren:** Nur die **Daten** in MongoDB/PostgreSQL/Redis (Benutzer, Rollen, Konfigurationswerte, Kontodaten, Investments, Trades, etc.), sofern die DB neu initialisiert wurde.
- **Wiederherstellung:** Über die vorhandenen Backups unter `~/fin1-backups/` (täglich 03:00 Uhr).

---

## 1. Was wiederherstellbar ist

| Inhalt | Wo gespeichert | Nach DB-Reset | Wiederherstellung |
|--------|----------------|---------------|--------------------|
| **Code** (z. B. Maximum Risk Exposure %) | Repo + Server (Cloud Functions, Admin-Portal, iOS-Build) | Unverändert | Nicht nötig |
| **Konfigurationswerte** (z. B. 2 % in Config/Configuration) | MongoDB (Collections `Configuration`, `Config`) | Leer/Default | Mit DB-Restore aus Backup |
| **Benutzer, Rollen, Sessions** | MongoDB (`_User`, `Role`, `_Session`) | Leer | Mit DB-Restore aus Backup |
| **Kontodaten, Investments, Trades, Dokumente** | MongoDB (entsprechende Collections) | Leer | Mit DB-Restore aus Backup |
| **Analytics** | PostgreSQL `fin1_analytics` | Leer | Mit DB-Restore aus Backup |
| **Cache** | Redis | Leer | Mit DB-Restore aus Backup (optional) |

---

## 2. Verfügbare Backups (Stand: Server 192.168.178.20)

Backups liegen unter **`~/fin1-backups/`** (täglich 03:00 Uhr automatisch, siehe auch **Backup manuell** unten).

- `20260306_030001` – heute früh (kann schon nach Neuinit sein)
- `20260305_030001` – gestern früh (in der Regel **vor** einer Neuinit vom heutigen Tag)
- `20260304_030001`, `20260301_030001`, …

**Backup manuell auslösen (z. B. vor größeren Änderungen):**

```bash
ssh io@192.168.178.20 '~/fin1-server/scripts/backup.sh'
```

Details: **`scripts/BACKUP_RESTORE.md`** (Abschnitt „Backup manuell auslösen“).

Jedes Backup enthält u. a.:

- `mongodb.gz` – MongoDB-Dump (User, Configuration, Config, Investment, Trade, …)
- `postgresql.sql.gz` – PostgreSQL (Analytics)
- `redis-dump.rdb` – Redis
- `backend.env`, `nginx.conf`, `docker-compose.production.yml` (optional)

---

## 3. Wiederherstellung (auf dem Server ausführen)

**Empfehlung:** Zuerst ein Backup von **vor** der Neuinitialisierung wählen. Wenn die Neuinit heute passiert ist, ist **`20260305_030001`** (gestern 03:00) meist die richtige Wahl.

### Option A: Vollständiger Restore (MongoDB + PostgreSQL + Redis)

Auf dem Ubuntu-Server (z. B. per SSH):

```bash
ssh io@192.168.178.20
cd ~/fin1-server/scripts
./restore-from-backup.sh 20260305_030001
```

Das Skript:

1. Listet Inhalt des Backups.
2. Fordert zur Bestätigung auf: **`yes`** eintippen.
3. Ersetzt die **aktuelle** MongoDB, PostgreSQL und Redis durch den Stand aus dem Backup (mit `--drop`).
4. Fragt am Ende, ob auch Config-Dateien (`.env`, nginx, docker-compose) wiederhergestellt werden sollen – bei reiner DB-Wiederherstellung in der Regel **N** (nur wenn du gezielt alte Config willst).

Ohne interaktive Bestätigung (z. B. für Skripte):

```bash
RESTORE_CONFIRM=yes ~/fin1-server/scripts/restore-from-backup.sh 20260305_030001
```

### Option B: Nur Backups anzeigen

```bash
ssh io@192.168.178.20
~/fin1-server/scripts/restore-from-backup.sh
# oder
~/fin1-server/scripts/restore-from-backup.sh --list
```

### Option C: Nur Config-Dateien (keine DBs)

```bash
~/fin1-server/scripts/restore-from-backup.sh 20260305_030001 --config-only
```

---

## 4. Nach dem Restore

1. **Parse Server** ggf. neu starten (Sessions/Cache):
   ```bash
   cd ~/fin1-server
   docker compose -f docker-compose.production.yml restart parse-server
   ```
2. **Admin-Login prüfen:**
   https://192.168.178.24/admin/ (oder deine Server-URL) – Login mit einem Benutzer aus dem wiederhergestellten Backup.
3. **Konfiguration prüfen:**
   Unter **Konfiguration → Anzeige** den Wert **Maximum Risk Exposure (%)** prüfen bzw. erneut setzen (z. B. 2 %). Die **Funktion** dafür ist unverändert; nur der in der DB gespeicherte Wert kommt aus dem Backup (oder Default).

---

## 5. Implementierung „2 % konfigurierbar“ – wo sie liegt

Die konfigurierbare Variable ist **nicht** in der Datenbank „gespeichert“ als Implementierung, sondern nur ihr **Wert** (z. B. 2.0) kann in der DB stehen. Der **Code** liegt hier:

- **iOS:** `FIN1/Features/Dashboard/Views/Components/DashboardContainer.swift`, `ConfigurationService*`, `ConfigurationServiceProtocol`
- **Admin-Portal:** `admin-portal/src/pages/Configuration/ConfigurationPage.tsx` (Sektion „Anzeige“, Parameter `maximumRiskExposurePercent`)
- **Backend:** `backend/parse-server/cloud/functions/configuration.js`, `backend/parse-server/cloud/utils/configHelper/`, `backend/parse-server/cloud/main.js` (getConfig/updateConfig)

Nach einem DB-Restore verwendet die App wieder die Daten aus dem Backup (inkl. Konfigurationswerte). Die genannte Implementierung bleibt bestehen; nur wenn im Backup noch keine `Configuration`/`Config` mit `maximumRiskExposurePercent` existierte, greift der Default 2 %.
