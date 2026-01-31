# FIN1 Ubuntu Server Deployment - Schnellstart

Diese Skripte ermöglichen die automatische Einrichtung des FIN1 Backend-Servers auf einem Ubuntu 24.04 LTS Rechner im lokalen Netzwerk.

## Voraussetzungen

- Mac mit SSH-Zugriff auf Ubuntu-Rechner
- Ubuntu 24.04 LTS im selben WLAN (Fritzbox)
- Beide Rechner im selben Netzwerk

**⚠️ WICHTIG:** Für optimale Ergebnisse sollten Sie zuerst die Fritzbox konfigurieren:
- Siehe: [FRITZBOX_SETUP-v2026-01-30.md](FRITZBOX_SETUP-v2026-01-30.md) für detaillierte Anleitung
- **Empfohlen:** Feste IP für Ubuntu-Server vergeben (erleichtert Auffinden)

## Schnellstart (Empfohlen)

### Option 1: All-in-One Deployment

```bash
cd /Users/ra/app/FIN1
./scripts/quick-deploy-v2026-01-30.sh
```

Das Skript führt automatisch alle Schritte durch:
1. Findet Ubuntu-Server im Netzwerk (optional)
2. Testet Verbindung
3. Installiert Docker (falls nötig)
4. Kopiert alle Dateien
5. Konfiguriert Umgebungsvariablen
6. Startet Server

### Option 2: Schrittweise

#### 1. Ubuntu-Server finden

```bash
./scripts/find-ubuntu-server-v2026-01-30.sh
```

#### 2. Deployment durchführen

```bash
./scripts/deploy-to-ubuntu-v2026-01-30.sh [ubuntu-ip] [ubuntu-user]
```

Beispiel:
```bash
./scripts/deploy-to-ubuntu-v2026-01-30.sh 192.168.178.50 ubuntu
```

## Verfügbare Skripte

### `quick-deploy-v2026-01-30.sh`
**All-in-One Deployment-Skript**
- Führt alle Schritte automatisch durch
- Interaktive Konfiguration
- Startet Server automatisch

**Verwendung:**
```bash
./scripts/quick-deploy-v2026-01-30.sh [ubuntu-ip]
```

### `deploy-to-ubuntu-v2026-01-30.sh`
**Haupt-Deployment-Skript**
- Kopiert alle Backend-Dateien
- Konfiguriert Umgebungsvariablen
- Passt Docker Compose an

**Verwendung:**
```bash
./scripts/deploy-to-ubuntu-v2026-01-30.sh [ubuntu-ip] [ubuntu-user]
```

### `setup-ubuntu-server-v2026-01-30.sh`
**Ubuntu-Setup-Skript** (wird automatisch ausgeführt)
- Installiert Docker und Docker Compose
- Konfiguriert Firewall (UFW)
- Erstellt Verzeichnisstruktur
- Erstellt Systemd-Service

**Manuelle Verwendung:**
```bash
# Auf Ubuntu ausführen
scp scripts/setup-ubuntu-server-v2026-01-30.sh user@ubuntu-ip:~/
ssh user@ubuntu-ip
chmod +x ~/setup-ubuntu-server-v2026-01-30.sh
~/setup-ubuntu-server-v2026-01-30.sh
```

### `find-ubuntu-server-v2026-01-30.sh`
**Netzwerk-Scanner**
- Findet Ubuntu-Server im lokalen Netzwerk
- Zeigt verfügbare SSH-Server

**Verwendung:**
```bash
./scripts/find-ubuntu-server-v2026-01-30.sh
```

## Manuelle Einrichtung

Falls die automatischen Skripte nicht funktionieren, siehe:
- [Detaillierte Anleitung](UBUNTU_SERVER_SETUP-v2026-01-30.md)

## Nach dem Deployment

### 1. Passwörter ändern

**WICHTIG:** Alle Standard-Passwörter in `.env` ändern!

```bash
ssh user@ubuntu-ip
cd ~/fin1-server/backend
nano .env
```

Ändern Sie mindestens:
- `PARSE_SERVER_MASTER_KEY`
- `MONGO_INITDB_ROOT_PASSWORD`
- `POSTGRES_PASSWORD`
- `REDIS_PASSWORD`
- `JWT_SECRET`
- `ENCRYPTION_KEY`

### 2. Server starten

```bash
cd ~/fin1-server
docker compose -f docker-compose.production.yml up -d
```

### 3. Services prüfen

```bash
# Status
docker compose ps

# Logs
docker compose logs -f

# Health Check
curl http://ubuntu-ip/health
```

## Nützliche Befehle

### Vom Mac aus

```bash
# Logs anzeigen
ssh user@ubuntu-ip 'cd ~/fin1-server && docker compose logs -f'

# Services neu starten
ssh user@ubuntu-ip 'cd ~/fin1-server && docker compose restart'

# Services stoppen
ssh user@ubuntu-ip 'cd ~/fin1-server && docker compose down'

# Backup erstellen
ssh user@ubuntu-ip 'cd ~/fin1-server && docker compose exec mongodb mongodump --out /backup'
```

### Auf Ubuntu

```bash
# Services verwalten
cd ~/fin1-server
docker compose ps                    # Status
docker compose logs -f               # Logs
docker compose restart               # Neu starten
docker compose down                  # Stoppen
docker compose up -d                 # Starten

# Einzelne Services
docker compose logs -f parse-server
docker compose restart parse-server

# Datenbank-Zugriff
docker compose exec mongodb mongosh
docker compose exec postgres psql -U fin1_user -d fin1_analytics
```

## Troubleshooting

### SSH-Verbindung fehlgeschlagen

```bash
# SSH-Key generieren (falls nicht vorhanden)
ssh-keygen -t ed25519

# Key auf Ubuntu kopieren
ssh-copy-id user@ubuntu-ip

# Verbindung testen
ssh user@ubuntu-ip
```

### Docker nicht verfügbar

```bash
# Auf Ubuntu: Docker-Gruppe aktivieren
newgrp docker

# Oder neu einloggen
exit
ssh user@ubuntu-ip
```

### Port bereits belegt

```bash
# Auf Ubuntu: Port prüfen
sudo lsof -i :1337

# Prozess beenden
sudo kill -9 <PID>
```

### Container startet nicht

```bash
# Logs prüfen
docker compose logs parse-server

# Container neu erstellen
docker compose up -d --force-recreate parse-server
```

## Netzwerk-Konfiguration (Fritzbox)

**Detaillierte Anleitung:** Siehe [FRITZBOX_SETUP-v2026-01-30.md](FRITZBOX_SETUP-v2026-01-30.md)

### Wichtigste Schritte:

1. **Feste IP vergeben** (Empfohlen)
   - Fritzbox-Weboberfläche: `http://fritz.box`
   - `Heimnetz` → `Netzwerk` → `Geräte und Benutzer`
   - Ubuntu-Server finden → `Bearbeiten`
   - `Diesem Netzwerkgerät immer die gleiche IPv4-Adresse zuweisen` aktivieren
   - IP-Adresse notieren

2. **WLAN-Geräte anzeigen**
   - `WLAN` → `Funknetz` → `Funknetz-Name (SSID)`
   - `WLAN-Geräte anzeigen` aktivieren

3. **Port-Weiterleitung** (optional, für externen Zugriff)
   - `Internet` → `Freigaben` → `Portfreigaben`
   - Ports: 80, 443, 1337

## Sicherheit

### Wichtige Maßnahmen:

1. ✅ Alle Passwörter in `.env` ändern
2. ✅ SSH-Key-Authentifizierung verwenden
3. ✅ Firewall aktivieren (automatisch durch Setup-Skript)
4. ✅ Regelmäßige Updates: `sudo apt update && sudo apt upgrade -y`
5. ✅ Backups regelmäßig durchführen

## Support

Bei Problemen:
1. Logs prüfen: `docker compose logs -f`
2. Container-Status: `docker compose ps`
3. Netzwerk-Verbindung testen: `ping ubuntu-ip`
4. Firewall-Regeln prüfen: `sudo ufw status`

## Nächste Schritte

Nach erfolgreichem Setup:
1. iOS-App konfigurieren (API-URL auf Ubuntu-IP setzen)
2. SSL-Zertifikate einrichten (für Produktion)
3. Monitoring einrichten
4. Backup-Strategie implementieren
