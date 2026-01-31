# Caffeinate Helper-Scripts - Quick Reference

Intelligente Wrapper für `caffeinate` mit Batterie-Schutz und Timeouts.

## 🚀 Quick Start

### Für Xcode-Builds/Tests

```bash
# Build mit caffeinate (2h max)
./scripts/caffeinate-build.sh --mode build

# Tests mit caffeinate (1h max)
./scripts/caffeinate-build.sh --mode test --timeout 3600

# Hilfe anzeigen
./scripts/caffeinate-build.sh --help
```

### Für Entwicklungsserver

```bash
# Server mit caffeinate starten
./scripts/caffeinate-server.sh -- npm start

# Mit Timeout (2h max)
./scripts/caffeinate-server.sh --timeout 7200 -- docker-compose up

# Hilfe anzeigen
./scripts/caffeinate-server.sh --help
```

## 📋 Features

✅ **Automatischer Timeout** - Schützt vor leerer Batterie
✅ **Batterie-Check** - Warnt bei niedrigem Stand
✅ **Display Sleep erlaubt** - Spart Batterie
✅ **System Sleep verhindert** - WLAN bleibt verbunden
✅ **Clean Exit** - Automatisches Beenden bei Ctrl+C

## 🔧 Details

Siehe `Documentation/CAFFEINATE_EXPERT_OPINION.md` für vollständige Dokumentation.
