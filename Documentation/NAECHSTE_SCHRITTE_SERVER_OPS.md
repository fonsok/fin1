# Nächste Schritte – Server & Operations (Prioritäten)

**Stand:** 2026-02-23
**Kontext:** Bewertung „Server-Checkliste“ (Infrastruktur, Security, Deployment, Observability, Operations).
**Referenz:** `Documentation/SERVER_HARDENING_2026-02.md`, `06_BETRIEB_PROZESSE.md`, `06A_BACKEND_UBUNTU_IOBOX_RUNBOOK.md`.

---

## Priorität 1: Restore-Test durchführen (Backup-Validierung)

**Warum:** Backups laufen automatisch; ob ein Vollrestore funktioniert, ist ohne Test nicht sicher.

**Konkrete Schritte:**

1. **Termin festlegen** (z. B. im nächsten Wartungsfenster oder an einem ruhigen Tag).
2. **Auf dem Server** (`ssh io@192.168.178.20` bzw. `io@192.168.178.24`):
   - `cd /home/io/fin1-server`
   - `./scripts/restore-from-backup.sh --list` → ältestes oder zweitneuestes Backup wählen (nicht das allerneueste, um echte Daten zu testen).
   - Optional: **Test in separatem Verzeichnis** (z. B. zweiter Compose-Stack mit anderem Projektnamen), damit Produktion nicht angefasst wird.
     Wenn ihr direkt auf Prod testet: Backup vom gleichen Tag vor dem Test anlegen (`./scripts/backup.sh`), dann Restore mit einer älteren BACKUP_ID.
   - Restore ausführen: `./scripts/restore-from-backup.sh <BACKUP_ID>` (Bestätigung mit `yes`).
   - Stack prüfen: `docker compose -f docker-compose.production.yml up -d`, dann `curl -sk https://localhost/health` und `curl -sk https://localhost/parse/health`.
3. **Ergebnis dokumentieren** (z. B. in diesem Abschnitt oder in `scripts/BACKUP_RESTORE.md`):
   - Datum, verwendete BACKUP_ID, Dauer, eventuelle Fehler.
   - „Letzter Restore-Test: YYYY-MM-DD, BACKUP_ID …, Ergebnis: OK / Fehler: …“

**Doku-Anpassung:** In `scripts/BACKUP_RESTORE.md` einen kurzen Abschnitt „Restore-Test (empfohlen quartalsweise)“ ergänzen und auf dieses Vorgehen verweisen.

---

## Priorität 2: Security-Patching dokumentieren und automatisieren

**Warum:** OS- und Runtime-Updates sind in der Checkliste gefordert; aktuell nicht dokumentiert.

**Konkrete Schritte:**

1. **Dokumentation anlegen** (z. B. in `06A_BACKEND_UBUNTU_IOBOX_RUNBOOK.md` oder neues Blatt `06C_PATCHING_WARTUNG.md`):
   - **Ubuntu:** Unattended-Upgrades für Sicherheitsupdates aktivieren:
     - `sudo apt install unattended-upgrades`
     - `sudo dpkg-reconfigure -plow unattended-upgrades` (Security updates: yes)
     - Optional: Reboot nur bei Kernel-Updates (`Unattended-Upgrade::Automatic-Reboot` in `/etc/apt/apt.conf.d/50unattended-upgrades`).
   - **Docker/Images:** Regelmäßig Images neu bauen und neu deployen (z. B. monatlich oder nach CVE-Meldungen), z. B.:
     - `docker compose -f docker-compose.production.yml build --no-cache` und `up -d` (in Wartungsfenster).
   - **Node/Parse:** Wenn Parse Server oder Cloud Code Abhängigkeiten hat, `npm audit` und Updates in einem definierten Zyklus (z. B. vierteljährlich).
2. **Checkliste „Patching-Zyklus“** (z. B. monatlich):
   - [ ] `apt update && apt list --upgradable` prüfen
   - [ ] Unattended-Upgrades-Log prüfen (`/var/log/unattended-upgrades/`)
   - [ ] Docker-Images neu bauen & deployen (oder nur bei bekannter CVE)
   - [ ] Datum in Doku eintragen

---

## Priorität 3: Offene Ports bereinigen (Samba, RDP, 8000)

**Warum:** Runbook nennt 139/445 (Samba), 3389 (RDP), 8000 als noch offen; Angriffsfläche minimieren.

**Konkrete Schritte:**

1. **Auf dem Server prüfen**, ob die Dienste genutzt werden:
   - Samba: Wird auf dem Host Dateifreigabe genutzt? Wenn **nein**: `sudo systemctl disable --now smbd nmbd` und in UFW Ports 139/445 blocken oder nicht freigeben.
   - RDP (gnome-remote-desktop): Wird Remote-Desktop genutzt? Wenn **nein**: Remote Desktop in den Systemeinstellungen deaktivieren (oder Dienst stoppen/deaktivieren).
   - Port 8000: `sudo ss -ltnp | grep :8000` bzw. `sudo lsof -nP -iTCP:8000 -sTCP:LISTEN` → Prozess identifizieren; deaktivieren oder auf localhost binden, wenn nicht benötigt.
2. **Firewall (UFW)** nach Abschnitt 14 in `06A_BACKEND_UBUNTU_IOBOX_RUNBOOK.md` anpassen: Nur 22, 80, 443 (und optional 3001 für Uptime Kuma) von außen erlauben; Rest explizit nicht öffnen oder blockieren.
3. **Doku aktualisieren:** In `06A_BACKEND_UBUNTU_IOBOX_RUNBOOK.md` unter „Bereits bereinigt“ vermerken (z. B. „Stand MM/YYYY: Samba/RDP/8000 deaktiviert bzw. geblockt“).

---

## Priorität 4: Incident-Prozess und Runbook ergänzen

**Warum:** Es gibt SLA-Priorisierung (S0–S3), aber kein klares On-Call-/Incident-Runbook und keinen Post-Mortem-Prozess.

**Konkrete Schritte:**

1. **Kurzes Incident-Runbook** in `06_BETRIEB_PROZESSE.md` (oder als Verweis in `06A`) ergänzen:
   - **S0/S1 (kritisch):** Wer wird informiert (E-Mail/Telegram/ntfy)? Wer entscheidet Rollback?
   - **Erste Schritte:** Health-Checks (`/health`, `/parse/health`), `docker compose ps`, Logs (`logs parse-server`, `logs nginx`), letzte Änderungen (Deploy, Config).
   - **Rollback:** Compose auf vorherigen Stand, ggf. Restore aus Backup (siehe `scripts/BACKUP_RESTORE.md`).
   - **Eskalation:** Wenn nach X Minuten keine Besserung → wen anrufen / wen hinzuziehen?
2. **Post-Mortem (optional, aber empfohlen bei S0/S1):**
   - Kurzes Template: Was ist passiert? Ursache? Was wurde sofort getan? Was wird dauerhaft geändert (Config, Monitoring, Doku)? Kein Blame – nur Fakten und Maßnahmen.
   - Ein Absatz in `06_BETRIEB_PROZESSE.md` reicht („Nach S0/S1-Vorfällen: kurzes Post-Mortem mit [diesen Punkten] und Doku im Repo oder intern“).
3. **On-Call:** Muss nicht rotierend sein; reicht z. B. „Verantwortliche Person für Server-Incidents: [Name/Kontakt], Backup: [Name/Kontakt]“ in der Doku zu hinterlegen.

---

## Priorität 5: Deploy-Reproduzierbarkeit und (optional) kleines CI-Deploy

**Warum:** Deploy ist heute manuell; Versionen und Rollback sind klarer, wenn Builds getaggt und dokumentiert sind.

**Konkrete Schritte:**

1. **Image-Tagging:** Bei jedem Release einen festen Tag verwenden (z. B. `parse-server:2026-02-23` statt nur `latest`). In `docker-compose.production.yml` oder in einem `docker-compose.override.yml` für Releases das Image mit Tag referenzieren; Build mit diesem Tag: `docker compose build parse-server` und `docker tag ... parse-server:2026-02-23`, Push in eine Registry nur wenn ihr eine nutzt.
2. **Deploy-Checkliste in Doku** (z. B. in `06A_BACKEND_UBUNTU_IOBOX_RUNBOOK.md` Abschnitt „Deployment/Update“):
   - Vor dem Deploy: Backup prüfen (existiert heute?), Health grün.
   - Nach dem Deploy: Health, kurzer Smoke-Test (z. B. Login, eine kritische Cloud Function).
   - Rollback-Anweisung: „Bei Problemen: Compose auf vorherigen Image-Tag/Commit zurücksetzen und `up -d`.“
3. **(Optional) Automatisches Deploy:** Kleines Skript auf dem Server oder in GitHub Actions: bei Tag/Release z. B. `rsync`/`scp` der relevanten Dateien + `ssh … 'cd /home/io/fin1-server && docker compose build … && docker compose up -d'`. Erst nach Priorität 1–4 sinnvoll; dann Reduktion von Tippfehlern und klare Nachvollziehbarkeit.

---

## Übersicht: Reihenfolge und Aufwand

| Priorität | Thema                    | Grober Aufwand   | Abhängigkeiten |
|----------|---------------------------|------------------|----------------|
| 1        | Restore-Test              | 1–2 h (einmalig) | Keine          |
| 2        | Patching-Doku + Automatik | 1–2 h            | Keine          |
| 3        | Ports bereinigen         | ca. 30 min       | Server-Zugriff |
| 4        | Incident-Runbook/Post-Mortem | ca. 1 h      | Keine          |
| 5        | Deploy-Tagging + Doku    | ca. 1 h          | Optional: CI   |

Empfohlene Reihenfolge: **1 → 2 → 3 → 4 → 5**. Priorität 1 und 2 erhöhen die Zuverlässigkeit und Sicherheit sofort; 3 verringert die Angriffsfläche; 4 verbessert die Reaktion bei Ausfällen; 5 verbessert Reproduzierbarkeit und Rollback.

---

## Verweise

- **Backup & Restore:** `scripts/BACKUP_RESTORE.md`, `scripts/restore-from-backup.sh`
- **Server-Runbook:** `Documentation/FIN1_APP_DOCS/06A_BACKEND_UBUNTU_IOBOX_RUNBOOK.md`
- **Betrieb & Prozesse:** `Documentation/FIN1_APP_DOCS/06_BETRIEB_PROZESSE.md`
- **Hardening-Überblick:** `Documentation/SERVER_HARDENING_2026-02.md`
