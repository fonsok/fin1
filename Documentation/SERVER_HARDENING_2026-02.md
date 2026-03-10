# Server-Hardening & Änderungen (Februar 2026)

**Stand:** 2026-02-23
**Betrifft:** fin1-server (Ubuntu, iobox), `docker-compose.production.yml`, Nginx, Backups, Monitoring.

Dieses Dokument listet alle Änderungen aus dem Hardening-Chat. **Projekt-Doku und Scripts, die noch `http://`, `ws://`, direkte Ports oder alte Backup-Anleitungen erwähnen, sollten entsprechend angepasst werden.**

---

## 1) Was wurde umgesetzt

### Security
- **HTTPS:** TLS (self-signed) aktiv, HTTP leitet auf HTTPS um (301), HSTS-Header.
- **URLs:** API/LiveQuery in Produktion auf `https://` bzw. `wss://` (z. B. `https://192.168.178.24/parse`, `wss://192.168.178.24/parse`).
- **Ports:** Alle Datenbanken und Parse Server nur noch auf `127.0.0.1` (nicht mehr `0.0.0.0`). Nach außen nur Nginx 80/443 (+ ggf. Uptime Kuma 3001).
- **Firewall:** UFW aktiv (22, 80, 443; optional 3001 für Monitoring).
- **SSH:** Hardening (Key-only, kein Root, Fail2Ban).
- **Parse Dashboard / API-Docs:** Nur von localhost erreichbar (Nginx `allow 127.0.0.1; deny all`).
- **CORS:** Wildcard entfernt, nur explizite Origins.
- **Credentials:** Starke Passwörter, keine Fallback-Defaults in Compose, `.env` mit 600.

### Infrastruktur
- **Netzwerk:** Zwei Docker-Netze – `frontend` (Nginx, Parse, Microservices, Uptime Kuma), `backend` (internal: true, nur MongoDB, Redis, Postgres, MinIO + die App-Services die DB brauchen).
- **Ressourcen:** Memory/CPU-Limits für alle Container.
- **Logs:** json-file mit Rotation (max-size, max-file) für alle Services.

### Backup & Restore
- **Backup-Script:** Täglich 3:00 Uhr (Cron). Inhalt: MongoDB (`mongodump`), PostgreSQL (`pg_dump` **nicht** `pg_dumpall`), Redis (RDB), Config (docker-compose, .env, nginx.conf). 14 Tage Aufbewahrung.
- **Restore-Script:** `scripts/restore-from-backup.sh` – Liste mit `--list`, Vollrestore mit `<BACKUP_ID>`, optional `--config-only`. Siehe `scripts/BACKUP_RESTORE.md`.

### Monitoring
- **Uptime Kuma:** Läuft als Container, Port 3001 (optional per UFW freigegeben). 8 Monitore (Parse, Nginx, Market Data, Notification, Analytics, MongoDB, Redis, PostgreSQL). Alerts z. B. via ntfy.

---

## 2) Was in der Doku angepasst werden sollte

### URLs (überall wo Server-URLs stehen)
- **Alt:** `http://192.168.178.24/parse`, `ws://192.168.178.24/parse`, `http://192.168.178.24/admin`, `http://192.168.178.24/health`
- **Neu:** `https://192.168.178.24/parse`, `wss://192.168.178.24/parse`, `https://192.168.178.24/admin`, `https://192.168.178.24/health`
- **Hinweis:** Server-IP kann je nach Netz 192.168.178.20 oder 192.168.178.24 sein.

### Parse Dashboard
- **Alt:** Direkt `http://<server>:1337/dashboard` oder `:1338/dashboard`.
- **Neu:** Port 1338 ist nur auf localhost gebunden. Zugriff nur:
  - per Nginx: `https://localhost/dashboard/` (nach SSH-Tunnel `ssh -L 443:127.0.0.1:443 io@<server>`), oder
  - Tunnel auf 1338: `ssh -L 1338:127.0.0.1:1338 io@<server>` → dann `https://localhost:1338/dashboard/` (wenn Nginx TLS-Terminierung genutzt wird, eher Tunnel auf 443 wie oben).

### Backup/Restore
- **Alt:** Manuelle Befehle wie `docker compose exec mongodb mongodump ...`, `pg_dump`/`pg_restore` in verschiedenen Docs.
- **Neu:** Automatisches Backup per Cron; Wiederherstellung über `scripts/restore-from-backup.sh` und Anleitung in `scripts/BACKUP_RESTORE.md`. In allen Betriebs-/Runbook-Docs darauf verweisen.

### Ports (nur zur Info, keine Aktion nötig wenn nur „empfohlene“ Nutzung beschrieben wird)
- MongoDB/Postgres/Redis/MinIO/Parse sind von außen nur noch über Nginx (80/443) oder localhost erreichbar. Alte Hinweise wie „Mongo auf 27018 von LAN aus“ sind obsolet.

---

## 3) Bereits angepasste Dateien (Referenz)

- `FIN1_PROJECT_STATUS.md` – URLs, Backup/Monitoring-Hinweise
- `START_HERE.md` – URLs auf HTTPS
- `Documentation/FIN1_APP_DOCS/06_BETRIEB_PROZESSE.md` – Backup/Restore-Abschnitt
- `Documentation/FIN1_APP_DOCS/06A_BACKEND_UBUNTU_IOBOX_RUNBOOK.md` – Ports, HTTPS, Backup/Restore, Dashboard-Tunnel
- `Documentation/FIN1_APP_DOCS/10_ADMIN_PORTAL_REQUIREMENTS.md`, `09_ADMIN_ROLES_SEPARATION.md`, `03_TECHNISCHE_SPEZIFIKATION.md`, `04_DEVELOPER_GUIDE.md` – URLs auf HTTPS
- `ADMIN_PORTAL_DEPLOYMENT_ERFOLGREICH.md`, `ADMIN_PORTAL_LOGIN_ANLEITUNG.md`, `ADMIN_PORTAL_AUSWIRKUNGEN.md` – HTTPS
- `admin-portal/CSR_PORTAL_SETUP.md`, `CSR_LOGIN_ANLEITUNG.md`, `README.md`, `vite.config.ts` – HTTPS
- `WEB_PANEL_LOGIN_CREDENTIALS.md` – HTTPS, curl -k
- `BACKEND_DEPLOYMENT_ANLEITUNG.md`, `BACKEND_ANPASSUNGEN_ERFORDERLICH.md`, `BACKEND_ANPASSUNGEN_ZUSAMMENFASSUNG.md` – HTTPS/localhost
- `scripts/README.md` – Backup-/Restore-Skripte und BACKUP_RESTORE.md
- `scripts/BACKUP_RESTORE.md` – neu, beschreibt Backup/Restore
- `scripts/restore-from-backup.sh` – neu, Restore einer Backup-Version
- `scripts/UBUNTU_SERVER_SETUP.md`, `README-UBUNTU-DEPLOYMENT.md`, `QUICKSTART.md`, `EINFACHES_SETUP.md` – HTTPS, Backup-Verweise
- `.cursor/rules/admin-portal.md` – Production HTTPS
- `NAECHSTE_SCHRITTE.md`, `Documentation/CONFIGURATION_4EYES_DEPLOYMENT.md`, `NAECHSTE_SCHRITTE_BACKEND_INTEGRATION.md` – HTTPS

---

## 4) Weitere Dateien – inzwischen angepasst (Feb 2026)

Folgende Docs wurden ebenfalls auf HTTPS/WSS und Dashboard-Tunnel aktualisiert:
- `backend/MAC-CONNECTION-INFO.md` – Server-URL, Live Query, curl, Checkliste, SSH-Tunnel 443 / `https://localhost/dashboard/`
- `scripts/CURSOR_UBUNTU_SETUP.md` – curl health/parse mit `-sk` und `https://`
- `INTEGRATION_ABGESCHLOSSEN.md`, `WIE_VERBINDUNG_PRUEFEN.md`, `PHASE4_IOS_APP_KONFIGURATION.md`, `PHASE3_ERGEBNISSE.md`, `PHASE3_ABGESCHLOSSEN.md`, `PHASE5_VALIDIERUNG.md`
- `README_NETZWERK_INTEGRATION.md`, `VERBINDUNG_PRUEFEN_ANLEITUNG.md`, `STATUS_ZUSAMMENFASSUNG.md`
- `LIVE_QUERY_ANLEITUNG.md`, `LIVE_QUERY_FIX.md`
- `COMPLIANCE_EVENT_SETUP.md`, `DASHBOARD_ANLEITUNG.md`, `DASHBOARD_SCHRITT_FUER_SCHRITT.md`, `DASHBOARD_TROUBLESHOOTING.md`
- `FINALER_STATUS.md`, `NETZWERK_KONFIGURATION.md`
- `TROUBLESHOOTING.md`, `DEBUG_VERBINDUNG.md`, `WIE_ERKENNE_ICH_VERBINDUNG.md`
- `BACKEND_ANPASSUNGEN_ERFORDERLICH.md` – SSH-Tunnel auf 443

Bei weiteren älteren Docs ggf. nach `http://192.168`, `ws://`, `:1338/dashboard` suchen und anpassen.

---

## 5) Scripts auf dem Server (ohne Repo-Änderung)

- **Backup:** `/home/io/fin1-server/scripts/backup.sh` (Cron täglich 3:00)
- **Restore:** `/home/io/fin1-server/scripts/restore-from-backup.sh` (von diesem Repo deployt)
- **Hardening:** `/home/io/fin1-server/scripts/harden-server.sh` (einmalig ausgeführt)

Backup verwendet für PostgreSQL `pg_dump` (einzelne DB), nicht `pg_dumpall`.
