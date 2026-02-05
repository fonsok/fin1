# FIN1 Scripts Overview

Übersicht aller verfügbaren Scripts im `scripts/` Verzeichnis.

## 📊 Statistik

- **27 Shell-Scripts** (`.sh`)
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
  - Klassen ≤ 400 Zeilen
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

- **`pre-commit-hook.sh`** - Pre-Commit-Hook für Code-Qualität
  - ResponsiveDesign-Compliance
  - Separation of Concerns
  - File-Size-Validierung

- **`setup-git-hooks.sh`** - Setup für Git-Hooks

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

### Mac Development

- **`optimize-mac-for-development.sh`** - Optimiert Mac-Power-Management
  - Konfiguriert Sleep-Einstellungen
  - Aktiviert Netzwerk-Standby
  - Dokumentation: `Documentation/MAC_DEVELOPMENT_OPTIMIZATION.md`

- **`restore-mac-power-settings.sh`** - Stellt Mac-Power-Settings wieder her

### Deployment & Ubuntu

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
- Pre-Commit-Hooks werden automatisch von `setup-git-hooks.sh` eingerichtet

## 🔄 Letzte Aktualisierungen

- **2026-01-21**: `fix-xcode-build.sh` erstellt
- **2026-01-21**: `health-check-backend.sh` und `network-tuning.sh` dokumentiert in `NETWORK_TOOLS.md`

---

**Standort:** `/Users/ra/app/FIN1/scripts/`
**Letzte Aktualisierung:** 2026-01-21
