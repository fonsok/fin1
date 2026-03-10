# FAQ-Daten seeden (Parse Backend)

Dieses Dokument beschreibt, wie du die FAQ-Daten für Landing Page und Help Center (Investor/Trader) auf dem Backend seedest.

## Schnellstart

```bash
cd scripts
chmod +x seed-faq-data.sh

# Server und User angeben (z.B. io@192.168.178.20)
./seed-faq-data.sh 192.168.178.20 io

# Optional: Bestehende FAQs löschen und neu seeden (role-aware)
./seed-faq-data.sh 192.168.178.20 io --force
```

Ohne Argumente fragt das Script interaktiv nach Server und User.

## Voraussetzungen

- Parse Server läuft auf dem Zielrechner (z.B. `docker compose -f docker-compose.production.yml up -d`).
- Auf dem Server existiert `~/fin1-server/backend/.env` mit `PARSE_SERVER_MASTER_KEY=...`.
- SSH-Zugriff auf den Server (z.B. `ssh io@192.168.178.20`).

## Optionen

| Aufruf | Bedeutung |
|--------|-----------|
| `./seed-faq-data.sh HOST USER` | **seedFAQData**: Kategorien und FAQs anlegen, falls noch keine existieren. |
| `./seed-faq-data.sh HOST USER --force` | **forceReseedFAQData**: Alle FAQ-Daten löschen und neu seeden (role-aware: Investor- und Trader-spezifische Help-Center-FAQs). |

## Bei Problemen

- **Parse-Fehler (z.B. code 600):** Logs auf dem Server prüfen:
  ```bash
  ssh io@192.168.178.20 "cd ~/fin1-server && docker compose -f docker-compose.production.yml logs --tail=80 parse-server"
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
# Dann vom Mac: ./scripts/seed-faq-data.sh 192.168.178.20 io
```
