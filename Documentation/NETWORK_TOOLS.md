# Netzwerk-Tools für Entwicklung

## Installierte Tools

- **nmap** (7.98) - Netzwerk-Scanner und Sicherheits-Audit-Tool
- **netcat** (0.7.1) - Netzwerk-Utility für TCP/UDP-Verbindungen
- **mtr** (0.96) - Kombination aus ping und traceroute

## 🔍 nmap - Netzwerk-Scanner

### Verwendung für Entwicklung

**Lokalen Server scannen:**
```bash
# Scan lokalen Server (192.168.178.20)
nmap -p 1337,3000,8080 192.168.178.20

# Scan mit Service-Detection
nmap -sV -p 1337 192.168.178.20

# Scan alle Ports (langsam, aber gründlich)
nmap -p- 192.168.178.20
```

**Parse Server prüfen:**
```bash
# Prüfe ob Parse Server läuft
nmap -p 1337 localhost

# Prüfe Backend-Services
nmap -p 1337,27017,6379,5432 localhost
```

**Netzwerk-Discovery:**
```bash
# Finde alle Geräte im lokalen Netzwerk
nmap -sn 192.168.178.0/24

# Finde Fritzbox
nmap -sn 192.168.178.1
```

### Nützliche Optionen

- `-p PORT` - Spezifische Ports scannen
- `-sV` - Service-Version erkennen
- `-sn` - Ping-Scan (keine Ports)
- `-O` - OS-Detection (benötigt sudo)
- `-A` - Aggressive Scan (OS, Version, Scripts)

## 🔌 netcat (nc) - Netzwerk-Utility

### Verwendung für Entwicklung

**Port-Test:**
```bash
# Test ob Port offen ist
nc -zv 192.168.178.20 1337

# Test mit Timeout
nc -zv -w 5 192.168.178.20 1337
```

**Einfacher Server:**
```bash
# Starte einfachen TCP-Server auf Port 8080
nc -l 8080

# Starte UDP-Server
nc -u -l 8080
```

**Daten transferieren:**
```bash
# Sende Datei über Netzwerk
nc -l 8080 > received_file.txt  # Empfänger
nc 192.168.178.20 8080 < file.txt  # Sender
```

**Backend-Verbindung testen:**
```bash
# Test Parse Server Verbindung
echo "GET /parse HTTP/1.1" | nc 192.168.178.20 1337

# Test mit Timeout
nc -zv -w 3 192.168.178.20 1337
```

### Nützliche Optionen

- `-z` - Scan-Modus (keine Daten senden)
- `-v` - Verbose (zeigt Details)
- `-w SECONDS` - Timeout in Sekunden
- `-u` - UDP statt TCP
- `-l` - Listen-Modus (Server)

## 📊 mtr - Kombination aus ping und traceroute

### Verwendung für Entwicklung

**Netzwerk-Diagnose:**
```bash
# Trace Route zu Backend-Server
sudo mtr 192.168.178.20

# Trace Route mit Report (10 Pings)
sudo mtr -r -c 10 192.168.178.20

# Trace Route zu Internet
sudo mtr -r -c 10 8.8.8.8
```

**Fritzbox-Verbindung prüfen:**
```bash
# Prüfe Verbindung zur Fritzbox
sudo mtr -r -c 10 192.168.178.1

# Prüfe Gateway
sudo mtr -r -c 10 $(route -n get default | grep gateway | awk '{print $2}')
```

**Backend-Server Diagnose:**
```bash
# Prüfe Verbindung zum lokalen Server
sudo mtr -r -c 10 iobox.local

# Prüfe mit IP
sudo mtr -r -c 10 192.168.178.20
```

### Nützliche Optionen

- `-r` - Report-Modus (kein interaktives TUI)
- `-c COUNT` - Anzahl der Pings
- `-n` - Keine DNS-Auflösung (nur IPs)
- `-w` - Wide-Report (mehr Details)

**Hinweis:** `mtr` benötigt sudo-Rechte für ICMP-Pakete.

## 🎯 Praktische Beispiele für FIN1

### Backend-Server prüfen

```bash
# 1. Prüfe ob Server läuft
nc -zv 192.168.178.20 1337

# 2. Scan alle Backend-Ports
nmap -p 1337,27017,6379,5432,9000 192.168.178.20

# 3. Prüfe Netzwerk-Verbindung
sudo mtr -r -c 10 192.168.178.20
```

### Entwicklungsumgebung debuggen

```bash
# Finde alle aktiven Services
nmap -sV localhost

# Prüfe Docker-Container Ports
nmap -p 1337,27017,6379 localhost

# Test Backend-Verbindung
nc -zv localhost 1337
```

### Netzwerk-Probleme diagnostizieren

```bash
# 1. Prüfe lokales Netzwerk
nmap -sn 192.168.178.0/24

# 2. Prüfe Gateway-Verbindung
sudo mtr -r -c 10 192.168.178.1

# 3. Prüfe Internet-Verbindung
sudo mtr -r -c 10 8.8.8.8

# 4. Prüfe spezifischen Server
nc -zv -w 5 192.168.178.20 1337
```

## 📝 Quick Reference

### nmap
```bash
nmap -p PORT HOST          # Port scannen
nmap -sV HOST             # Service-Version erkennen
nmap -sn NETWORK          # Netzwerk-Discovery
```

### netcat
```bash
nc -zv HOST PORT          # Port testen
nc -l PORT                # Server starten
nc HOST PORT < file       # Datei senden
```

### mtr
```bash
sudo mtr HOST             # Interaktiver Trace
sudo mtr -r -c 10 HOST    # Report (10 Pings)
sudo mtr -n HOST          # Keine DNS-Auflösung
```

## 🔧 Integration in Scripts

### Backend Health Check Script

**Datei:** `scripts/network/health-check-backend.sh`

Ein umfassendes Verbindungstest-Script, das alle drei Tools kombiniert:

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

**Beispiel-Output:**
```
==== Port-Check (netcat) ====
Port 1337: ✅ offen
Port 27017: ❌ geschlossen oder gefiltert
...

==== Port-Scan (nmap) ====
Starting Nmap 7.98...
✅ Offene Ports:
  - Port 1337: Parse Server ✅

==== Netzwerk-Pfad (mtr) ====
HOST: Mac.fritz.box
Loss% Snt Last Avg Best Wrst StDev
1.|-- iobox.fritz.box 0.0% 10 4.1 5.2 3.0 7.8 1.6
```

**Features:**
- Automatische Tool-Erkennung (zeigt Warnung wenn Tools fehlen)
- Port-Interpretation (zeigt Service-Namen für bekannte Ports)
- Host-Erreichbarkeits-Prüfung
- Klare Status-Anzeige (✅/❌)

### Network Performance Tuning Script

**Datei:** `scripts/network/network-tuning.sh`

Ein Script für on-demand Netzwerk-Performance-Tuning:

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

### Einfache Beispiel-Scripts

**Server-Health-Check (einfach):**
```bash
#!/bin/bash
# Prüfe ob Backend-Server erreichbar ist

SERVER="192.168.178.20"
PORT="1337"

if nc -zv -w 3 $SERVER $PORT 2>&1 | grep -q "succeeded"; then
    echo "✅ Server ist erreichbar"
    exit 0
else
    echo "❌ Server ist nicht erreichbar"
    exit 1
fi
```

**Port-Scan (einfach):**
```bash
#!/bin/bash
# Scan Backend-Ports

SERVER="192.168.178.20"
PORTS="1337,27017,6379,5432"

echo "Scanning $SERVER..."
nmap -p $PORTS $SERVER
```

---

## 📚 Weitere Ressourcen

### Scripts im Repository

- **`scripts/network/health-check-backend.sh`** - Umfassender Backend-Verbindungstest
- **`scripts/network/network-tuning.sh`** - Netzwerk-Performance-Tuning (on-demand)

### Installation

```bash
# Alle Tools installieren
brew install nmap netcat mtr

# Einzelne Tools
brew install nmap      # Netzwerk-Scanner
brew install netcat    # Netzwerk-Utility
brew install mtr       # Ping + Traceroute
```

### Tool-Pfade (Homebrew auf Apple Silicon)

- `nmap`: `/opt/homebrew/bin/nmap`
- `netcat`: `/opt/homebrew/bin/nc`
- `mtr`: `/opt/homebrew/sbin/mtr` (benötigt sudo für ICMP)

---

**Installiert:** 2025-01-21
**Versionen:** nmap 7.98, netcat 0.7.1, mtr 0.96
**Letzte Aktualisierung:** 2026-01-21 (Scripts dokumentiert)
