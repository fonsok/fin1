# FIN1 Scripts Overview

Übersicht aller verfügbaren Scripts im `scripts/` Verzeichnis.

## 📊 Statistik

- **Diverse Shell-Scripts** (`.sh`) unter `scripts/`
- **9 Dokumentations-Dateien** (`.md`)

## 🔧 Scripts nach Kategorie

### Build & Development

- **`caffeinate-build.sh`** - Intelligenter caffeinate-Wrapper für Xcode-Builds/Tests
  - Verhindert System-Sleep während Builds
  - Batterie-Schutz mit Timeout
  - Dokumentation: `README_CAFFEINATE.md`

- **`caffeinate-server.sh`** - Intelligenter caffeinate-Wrapper für Entwicklungsserver
  - Verhindert System-Sleep während Server-Laufzeit
  - Erlaubt Display-Sleep (spart Batterie)
  - Dokumentation: `README_CAFFEINATE.md`

- **`fix-xcode-build.sh`** - Behebt häufige Xcode Build-Probleme
  - Bereinigt Derived Data
  - Validiert Projektstruktur
  - Prüft Schemes
  - **Neu:** 2026-01-21

- **`generate-code-coverage.sh`** - Generiert Code-Coverage-Reports

### Code Quality & Validation

- **`check-bundle-size.sh`** - Prüft iOS App Bundle-Größe
  - Warnungen bei Überschreitung von Schwellwerten
  - Dokumentation: `README-Bundle-Size.md`

- **`check-file-sizes.sh`** - Prüft File-Size-Limits
  - Swift-Dateien ≤ 300 Zeilen (Standard-Guardrail)
  - Funktionen ≤ 50 Zeilen

- **`check-responsive-design.sh`** - ResponsiveDesign-Compliance-Check
  - Prüft auf feste UI-Werte
  - Validiert ResponsiveDesign-System-Nutzung

- **`validate-mvvm-architecture.sh`** - MVVM-Architektur-Validierung
  - Prüft ViewModel-Instanziierung
  - Validiert Dependency Injection
  - Dokumentation: `README-MVVM-Validation.md`

- **`validate-separation-of-concerns.sh`** - Separation of Concerns-Validierung
  - Prüft Business-Logik in Views
  - Validiert File-Organisation

- **`validate-main-view-spacing.sh`** - Prüft Main-View-Spacing

- **`detect-duplicate-files.sh`** - Erkennt doppelte Swift-Dateien
  - Verhindert "Multiple commands produce" Fehler
  - Dokumentation: `README-Duplicate-Prevention.md`

### Git & Pre-Commit

- **`install-githooks.sh`** - Installiert Git-Hooks (symlinkt `.githooks/pre-commit`)
  - ResponsiveDesign-Compliance
  - Separation of Concerns
  - File-Size-Validierung

### Netzwerk & Backend

**📍 Scripts befinden sich in `scripts/network/`**

- **`network/health-check-backend.sh`** - Umfassender Backend-Verbindungstest
  - Port-Erreichbarkeit (netcat)
  - Port-Status (nmap)
  - Netzwerk-Pfad (mtr)
  - Dokumentation: `Documentation/NETWORK_TOOLS.md`, `scripts/network/README.md`

- **`network/network-tuning.sh`** - Netzwerk-Performance-Tuning (on-demand)
  - TCP-Buffer-Optimierung
  - Connection-Backlog-Erhöhung
  - MTU-Konfiguration
  - Dokumentation: `Documentation/NETWORK_TOOLS.md`, `scripts/network/README.md`

- **`start-backend.sh`** - Startet Backend-Services

- **`stop-backend.sh`** - Stoppt Backend-Services

- **`seed-faq-data.sh`** - FAQ-Daten auf dem Parse-Backend seeden (Landing + Help Center, Investor/Trader)
  - `./seed-faq-data.sh HOST USER` – seeden (wenn noch keine FAQs)
  - `./seed-faq-data.sh HOST USER --force` – bestehende FAQs löschen und neu seeden
  - Dokumentation: **`README-FAQ-SEED.md`**

### Mac Development

- **`optimize-mac-for-development.sh`** - Optimiert Mac-Power-Management
  - Konfiguriert Sleep-Einstellungen
  - Aktiviert Netzwerk-Standby
  - Dokumentation: `Documentation/MAC_DEVELOPMENT_OPTIMIZATION.md`

- **`restore-mac-power-settings.sh`** - Stellt Mac-Power-Settings wieder her

### Backup & Restore (Produktion)

- **`restore-from-backup.sh`** - Bestimmte Backup-Version wiederherstellen (auf dem Server)
  - `./restore-from-backup.sh --list` – Backups anzeigen
  - `./restore-from-backup.sh <BACKUP_ID>` – Vollrestore (MongoDB, PostgreSQL, Redis)
  - `--config-only` – nur Config-Dateien (.env, nginx.conf, docker-compose)
  - Dokumentation: **`BACKUP_RESTORE.md`** (Backup-Zeitplan, Restore-Ablauf, Logs)

- Backups laufen automatisch täglich 3:00 Uhr auf dem Server (`/home/io/fin1-server/scripts/backup.sh`). Siehe `Documentation/SERVER_HARDENING_2026-02.md`.

### Deployment & Ubuntu

**Backend-Ziel ist der Ubuntu-Rechner (`~/fin1-server`, Docker Compose).** Ein früherer Mac/Colima-Workflow im Repo wurde entfernt. iOS-Simulator: typisch `ssh -L 8443:127.0.0.1:443 …` und `https://localhost:8443/parse` gemäß `Config/FIN1-Dev.xcconfig` und `Documentation/HELP_N_INSTRUCTIONS_SERVER_DRIVEN.md`. Runbook: `Documentation/FIN1_APP_DOCS/06A_BACKEND_UBUNTU_IOBOX_RUNBOOK.md`.

- **`deploy-to-ubuntu.sh`** - Deployment auf Ubuntu-Server
  - Kopiert Dateien auf Server
  - Dokumentation: `README-UBUNTU-DEPLOYMENT.md`

- **`setup-ubuntu-server.sh`** - Setup für Ubuntu-Server
  - Dokumentation: `UBUNTU_SERVER_SETUP.md`

- **`find-ubuntu-server.sh`** - Findet Ubuntu-Server im Netzwerk

- **`activate-ssh-on-ubuntu.sh`** - Aktiviert SSH auf Ubuntu

- **`quick-deploy.sh`** - Schnelles Deployment

- **`auto-setup-passwords.sh`** - Automatisches Passwort-Setup

- **`setup-passwords.sh`** - Passwort-Setup

### Utilities

- **`replace-white-font-colors.sh`** - Ersetzt weiße Font-Farben

## 📚 Dokumentation

### Vollständig dokumentierte Scripts

- ✅ **Caffeinate Scripts** → `README_CAFFEINATE.md` (Root-Level)
- ✅ **Network Scripts** → `Documentation/NETWORK_TOOLS.md`
- ✅ **Bundle Size** → `README-Bundle-Size.md`
- ✅ **MVVM Validation** → `README-MVVM-Validation.md`
- ✅ **Duplicate Prevention** → `README-Duplicate-Prevention.md`
- ✅ **Ubuntu Deployment** → `README-UBUNTU-DEPLOYMENT.md`
- ✅ **Ubuntu Setup** → `UBUNTU_SERVER_SETUP.md`, `EINFACHES_SETUP.md`, `QUICKSTART.md`
- ✅ **Backup & Restore** → `BACKUP_RESTORE.md` (Produktion; Restore-Script: `restore-from-backup.sh`)
- ✅ **Fritzbox Setup** → `FRITZBOX_SETUP.md`
- ✅ **Cursor Ubuntu Setup** → `CURSOR_UBUNTU_SETUP.md`

### Scripts ohne dedizierte Dokumentation

- ⚠️ **`fix-xcode-build.sh`** - Neu erstellt (2026-01-21), noch nicht dokumentiert
- ⚠️ **`generate-code-coverage.sh`** - Keine dedizierte Dokumentation
- ⚠️ **`start-backend.sh`** / **`stop-backend.sh`** - Keine dedizierte Dokumentation
- ⚠️ **`restore-mac-power-settings.sh`** - Keine dedizierte Dokumentation
- ⚠️ **`replace-white-font-colors.sh`** - Keine dedizierte Dokumentation
- ⚠️ **`validate-main-view-spacing.sh`** - Keine dedizierte Dokumentation

## 🚀 Quick Reference

### Häufig verwendete Scripts

```bash
# Build mit caffeinate
./scripts/caffeinate-build.sh --mode build

# Backend-Verbindung testen
./scripts/network/health-check-backend.sh

# Code-Qualität prüfen
./scripts/check-file-sizes.sh
./scripts/validate-mvvm-architecture.sh

# Xcode Build-Probleme beheben
./scripts/fix-xcode-build.sh

# Mac für Entwicklung optimieren
./scripts/optimize-mac-for-development.sh
```

## 📝 Hinweise

- Alle Scripts sollten mit `./scripts/script-name.sh` ausgeführt werden
- Einige Scripts benötigen `sudo` (z.B. `scripts/network/network-tuning.sh`, `mtr` in `scripts/network/health-check-backend.sh`)
- Pre-Commit-Hooks werden mit `install-githooks.sh` eingerichtet (symlinkt `.githooks/pre-commit`)

## 🔄 Letzte Aktualisierungen

- **2026-01-21**: `fix-xcode-build.sh` erstellt
- **2026-01-21**: `health-check-backend.sh` und `network-tuning.sh` dokumentiert in `NETWORK_TOOLS.md`

---

**Standort:** `/Users/ra/app/FIN1/scripts/`
**Letzte Aktualisierung:** 2026-01-21
