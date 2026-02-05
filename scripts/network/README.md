# Network Scripts

Netzwerk-bezogene Scripts für Entwicklung und Diagnose.

## 📋 Verfügbare Scripts

### `health-check-backend.sh`

Umfassender Backend-Verbindungstest mit netcat, nmap und mtr.

**Verwendung:**
```bash
# Standard-Verwendung (ohne mtr)
./scripts/network/health-check-backend.sh [HOST]

# Mit mtr-Diagnose (benötigt sudo)
sudo ./scripts/network/health-check-backend.sh 192.168.178.20
```

**Was wird getestet:**
- ✅ Port-Erreichbarkeit (netcat) für Ports: 1337, 27017, 6379, 5432, 9000
- ✅ Port-Status und Service-Erkennung (nmap)
- ✅ Netzwerk-Pfad und Latenz (mtr, mit sudo)

**Features:**
- Automatische Tool-Erkennung (zeigt Warnung wenn Tools fehlen)
- Port-Interpretation (zeigt Service-Namen für bekannte Ports)
- Host-Erreichbarkeits-Prüfung
- Klare Status-Anzeige (✅/❌)

### `network-tuning.sh`

On-demand Netzwerk-Performance-Tuning für macOS.

**Verwendung:**
```bash
# Status anzeigen (kein sudo nötig)
./scripts/network/network-tuning.sh status

# TCP-Buffer für große Transfers optimieren
sudo ./scripts/network/network-tuning.sh transfer

# Max. Verbindungen erhöhen
sudo ./scripts/network/network-tuning.sh connections

# MTU für Interface setzen
sudo ./scripts/network/network-tuning.sh mtu Wi-Fi 1500

# Einstellungen zurücksetzen (aus Backup)
sudo ./scripts/network/network-tuning.sh reset [backup-file]
```

**Modi:**
- `status` - Zeigt aktuelle TCP- und MTU-Einstellungen
- `transfer` - Optimiert TCP-Buffer für große Datei-Transfers
- `connections` - Erhöht `somaxconn` für mehr gleichzeitige Verbindungen
- `mtu <iface> <value>` - Setzt MTU für ein Interface
- `reset [backup-file]` - Stellt Einstellungen aus Backup wieder her

**Backup-System:**
- Automatische Backups in `/tmp/network-tuning-backup-<timestamp>.txt`
- Alle Änderungen werden vor Anwendung gesichert
- `reset` ohne Parameter verwendet das neueste Backup

**Hinweise:**
- Änderungen sind **nicht persistent** über Neustarts (sysctl-basiert)
- Für persistente Änderungen müssen sysctl-Werte manuell in `/etc/sysctl.conf` gespeichert werden
- Immer mit `sudo` für Änderungen ausführen

## 📚 Vollständige Dokumentation

Siehe `Documentation/NETWORK_TOOLS.md` für:
- Detaillierte Tool-Dokumentation (nmap, netcat, mtr)
- Weitere Beispiele und Optionen
- Installation-Anweisungen

## 🔧 Voraussetzungen

```bash
# Alle Tools installieren
brew install nmap netcat mtr

# Einzelne Tools
brew install nmap      # Netzwerk-Scanner
brew install netcat    # Netzwerk-Utility
brew install mtr       # Ping + Traceroute
```

## 📝 Changelog

- **2026-01-21**: Scripts in `scripts/network/` organisiert
- **2026-01-21**: Vollständige Dokumentation in `Documentation/NETWORK_TOOLS.md`

---

**Standort:** `/Users/ra/app/FIN1/scripts/network/`
