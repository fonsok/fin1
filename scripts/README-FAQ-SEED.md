# FAQ-Daten seeden (Parse Backend)

Dieses Dokument beschreibt, wie du die FAQ-Daten für Landing Page und Help Center (Investor/Trader) auf dem Backend seedest.

## Schnellstart

```bash
cd scripts
chmod +x seed-faq-data.sh

# Server und User angeben (z.B. io@192.168.178.24; gleicher Host per Kabel: .20)
./seed-faq-data.sh 192.168.178.24 io

# Optional: Bestehende FAQs löschen und neu seeden (role-aware)
./seed-faq-data.sh 192.168.178.24 io --force
```

Ohne Argumente fragt das Script interaktiv nach Server und User.

## Voraussetzungen

- Parse Server läuft auf dem Zielrechner (z.B. `docker compose -f docker-compose.production.yml up -d`).
- Auf dem Server existiert `~/fin1-server/backend/.env` mit `PARSE_SERVER_MASTER_KEY=...`.
- SSH-Zugriff auf den Server (z.B. `ssh io@192.168.178.24`; alternativ gleicher Host per Kabel `.20`).

## Optionen

| Aufruf | Bedeutung |
|--------|-----------|
| `./seed-faq-data.sh HOST USER` | **seedFAQData**: Kategorien und FAQs anlegen, falls noch keine existieren. |
| `./seed-faq-data.sh HOST USER --force` | **forceReseedFAQData**: Alle FAQ-Daten löschen und neu seeden (role-aware: Investor- und Trader-spezifische Help-Center-FAQs). |

## Bei Problemen

- **Parse-Fehler (z.B. code 600):** Logs auf dem Server prüfen:
  ```bash
  ssh io@192.168.178.24 "cd ~/fin1-server && docker compose -f docker-compose.production.yml logs --tail=80 parse-server"
  ```
- **SSH/Verbindung:** Sicherstellen, dass Parse auf dem Server auf Port 1338 (localhost) erreichbar ist und alle Services laufen.

---

## Docker Compose: Gestoppte Container (Recreate-Bug 1.29.2)

Wenn nach einem Recreate Basis-Services (redis, mongodb, postgres, minio, uptime-kuma) mit „Exit 0“ verschwinden:

1. Gestoppte Container entfernen (Daten bleiben in Volumes):
   ```bash
   cd ~/fin1-server
   docker-compose -f docker-compose.production.yml rm -f redis mongodb postgres minio uptime-kuma
   ```
2. Services neu starten:
   ```bash
   docker-compose -f docker-compose.production.yml up -d redis mongodb postgres minio uptime-kuma
   ```
3. Nach ca. 15 Sekunden Health prüfen:
   ```bash
   docker-compose -f docker-compose.production.yml ps
   ```

Danach ggf. Parse Server neu starten und FAQ-Seed erneut ausführen:
```bash
docker-compose -f docker-compose.production.yml restart parse-server
# Dann vom Mac: ./scripts/seed-faq-data.sh 192.168.178.24 io
```

---

## Git und Datenbank synchron halten (`faq_export.json`)

Die Datei `scripts/faq_export.json` ist das **Repo-Abbild** für den JSON-Import (`apply_faqs_to_parse.py`) und für Reviews/Diffs. Nach einem **`forceReseedFAQData`** oder nach Änderungen im **Admin-Portal** („Hilfe & Anleitung“) solltest du sie neu erzeugen, damit Git zum Stand der Parse-DB passt.

### Export (DB → `scripts/faq_export.json`)

Voraussetzung: Parse erreichbar (lokal z. B. `http://127.0.0.1:1338/parse`, auf dem Server per SSH-Tunnel oder direkt), `PARSE_SERVER_APPLICATION_ID` und `PARSE_SERVER_MASTER_KEY` in `backend/.env` (oder als Umgebungsvariablen).

```bash
cd scripts
python3 export_faq_from_parse.py --output faq_export.json
# Andere URL (Beispiel):
# python3 export_faq_from_parse.py --parse-url http://127.0.0.1:1338/parse --output faq_export.json
```

Nur FAQs mit `source === "help_center"` (optional):

```bash
python3 export_faq_from_parse.py --output faq_export.json --filter-source help_center
```

**Hinweis:** Enthält die DB nach dem Cloud-Seed nur die **deutschen** Artikel aus `backend/parse-server/cloud/functions/seed/faq/data.js`, enthält der Export entsprechend deutschsprachige `question`/`answer`. Englische Texte stehen dann in `questionEn`/`answerEn`, sobald sie im Portal gepflegt sind. Die zuvor manuell gepflegte englische Help-Center-Datei kann sich unterscheiden — nach Reseed ggf. englische Einträge erneut setzen oder aus Backup importieren.

### Import (JSON → DB, Ubuntu-Server)

Wie bisher: `apply_faqs_to_parse.py` auf dem Server mit der exportierten Datei (setzt u. a. `categoryId`, `categoryIds`, optional `questionEn`/`answerEn`/`targetRoles`/`contexts`).

### Admin-Portal-Backup

Alternative zum Skript: Im Portal **Export (Backup)** — liefert das Rohformat von `exportFAQBackup` (inkl. `objectId`). Für Git ist das **Skript-Exportformat** (`export_faq_from_parse.py`) meist besser lesbar und kompatibel mit `apply_faqs_to_parse.py`.
