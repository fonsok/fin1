# FIN1 Server Setup auf Ubuntu 24.04 LTS

Diese Anleitung beschreibt die Einrichtung des FIN1 Backend-Servers auf einem Ubuntu 24.04 LTS Rechner im lokalen Netzwerk (Fritzbox).

## Voraussetzungen

- Ubuntu 24.04 LTS Rechner im selben WLAN wie der Mac
- Beide Rechner nutzen die Fritzbox als Router
- SSH-Zugriff auf den Ubuntu-Rechner
- Mindestens 4GB RAM auf dem Ubuntu-Rechner
- 20GB freier Speicherplatz

## Schnellstart

### Option 1: Automatisches Setup vom Mac

1. **Ubuntu-Server im Netzwerk finden:**
   ```bash
   cd /Users/ra/app/FIN1
   chmod +x scripts/find-ubuntu-server-v2026-01-30.sh
   ./scripts/find-ubuntu-server-v2026-01-30.sh
   ```

2. **Deployment durchführen:**
   ```bash
   chmod +x scripts/deploy-to-ubuntu-v2026-01-30.sh
   ./scripts/deploy-to-ubuntu-v2026-01-30.sh [ubuntu-ip] [ubuntu-user]
   ```

   Beispiel:
   ```bash
   ./scripts/deploy-to-ubuntu-v2026-01-30.sh 192.168.178.50 ubuntu
   ```

### Option 2: Manuelles Setup auf Ubuntu

1. **Auf Ubuntu: Setup-Skript ausführen**
   ```bash
   # Dateien vom Mac kopieren
   scp -r /Users/ra/app/FIN1/scripts/setup-ubuntu-server-v2026-01-30.sh user@ubuntu-ip:~/

   # Auf Ubuntu ausführen
   ssh user@ubuntu-ip
   chmod +x ~/setup-ubuntu-server-v2026-01-30.sh
   ~/setup-ubuntu-server-v2026-01-30.sh
   ```

2. **Neu einloggen oder Docker-Gruppe aktivieren:**
   ```bash
   newgrp docker
   ```

3. **FIN1-Dateien kopieren:**
   ```bash
   # Vom Mac
   cd /Users/ra/app/FIN1
   scp -r backend/ docker-compose.yml user@ubuntu-ip:~/fin1-server/
   ```

4. **Umgebungsvariablen konfigurieren:**
   ```bash
   # Auf Ubuntu
   cd ~/fin1-server/backend
   cp env.example .env
   nano .env
   ```

5. **Server starten:**
   ```bash
   cd ~/fin1-server
   docker compose up -d
   ```

## Detaillierte Anleitung

### Schritt 1: Netzwerk-Konfiguration (Fritzbox)

**WICHTIG:** Für optimale Ergebnisse sollten Sie die Fritzbox-Konfiguration durchführen.
Siehe: [FRITZBOX_SETUP-v2026-01-30.md](FRITZBOX_SETUP-v2026-01-30.md) für detaillierte Anleitung.

#### Ubuntu-Server IP-Adresse festlegen

1. **Fritzbox-Weboberfläche öffnen:**
   - URL: `http://fritz.box` oder `http://192.168.178.1`
   - Login mit Admin-Zugangsdaten

2. **Feste IP für Ubuntu-Server vergeben:**
   - Menü: `Heimnetz` → `Netzwerk`
   - Geräteliste öffnen
   - Ubuntu-Server finden
   - Auf Gerät klicken → `Bearbeiten`
   - `Diesem Netzwerkgerät immer die gleiche IPv4-Adresse zuweisen` aktivieren
   - IP-Adresse notieren (z.B. `192.168.178.50`)

3. **Port-Weiterleitung (optional, für externen Zugriff):**
   - Menü: `Internet` → `Freigaben` → `Portfreigaben`
   - Neue Portfreigabe:
     - Gerät: Ubuntu-Server
     - Port: 80, 443, 1337
     - Protokoll: TCP

#### Firewall-Regeln in Fritzbox

Die Fritzbox-Firewall sollte standardmäßig lokale Verbindungen erlauben. Falls Probleme auftreten:

- Menü: `Internet` → `Filter` → `Kindersicherung`
- Ubuntu-Server zur Liste der erlaubten Geräte hinzufügen

### Schritt 2: SSH-Zugriff einrichten

#### Auf Ubuntu:

```bash
# SSH-Server installieren (falls nicht vorhanden)
sudo apt update
sudo apt install -y openssh-server

# SSH-Server aktivieren
sudo systemctl enable ssh
sudo systemctl start ssh

# Status prüfen
sudo systemctl status ssh
```

#### Vom Mac: SSH-Key generieren und kopieren

```bash
# SSH-Key generieren (falls nicht vorhanden)
ssh-keygen -t ed25519 -C "fin1-deployment"

# Key auf Ubuntu kopieren
ssh-copy-id user@ubuntu-ip

# Verbindung testen
ssh user@ubuntu-ip
```

### Schritt 3: Docker Installation

Das Setup-Skript installiert automatisch:
- Docker Engine
- Docker Compose Plugin
- Firewall-Konfiguration (UFW)

Manuelle Installation:

```bash
# Docker Repository hinzufügen
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Docker installieren
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Benutzer zur Docker-Gruppe hinzufügen
sudo usermod -aG docker $USER
newgrp docker

# Installation testen
docker --version
docker compose version
```

### Schritt 4: FIN1 Backend konfigurieren

#### Umgebungsvariablen anpassen

```bash
cd ~/fin1-server/backend
cp env.example .env
nano .env
```

**Wichtige Einstellungen:**

```bash
# Server-URLs (Ubuntu IP verwenden)
PARSE_SERVER_PUBLIC_SERVER_URL=http://192.168.178.50:1338/parse
PARSE_SERVER_LIVE_QUERY_SERVER_URL=ws://192.168.178.50:1338/parse

# Produktionsmodus
NODE_ENV=production

# Passwörter ändern!
PARSE_SERVER_MASTER_KEY=<starkes-passwort-generieren>
MONGO_INITDB_ROOT_PASSWORD=<sicheres-passwort>
POSTGRES_PASSWORD=<sicheres-passwort>
REDIS_PASSWORD=<sicheres-passwort>
JWT_SECRET=<zufälliger-string>
```

#### Passwort-Generierung

```bash
# Starke Passwörter generieren
openssl rand -base64 32
```

### Schritt 5: Server starten

```bash
cd ~/fin1-server
docker compose up -d
```

#### Services prüfen

```bash
# Container-Status
docker compose ps

# Logs anzeigen
docker compose logs -f

# Einzelner Service
docker compose logs -f parse-server
```

### Schritt 6: Firewall konfigurieren

```bash
# UFW Status prüfen
sudo ufw status

# Ports öffnen (falls nicht bereits geschehen)
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 80/tcp    # HTTP
sudo ufw allow 443/tcp   # HTTPS
sudo ufw allow 1337/tcp  # Parse Server
sudo ufw allow 8080/tcp  # Market Data
sudo ufw allow 8081/tcp  # Notifications
sudo ufw allow 8082/tcp  # Analytics
```

### Schritt 7: Server testen

#### Vom Mac aus:

```bash
# Health Check
curl http://ubuntu-ip/health

# Parse Server API
curl http://ubuntu-ip:1338/parse/health

# Services testen
curl http://ubuntu-ip:8080/health  # Market Data
curl http://ubuntu-ip:8081/health  # Notifications
curl http://ubuntu-ip:8082/health  # Analytics
```

#### Im Browser:

- Parse Dashboard: `http://ubuntu-ip:1337/dashboard`
- MinIO Console: `http://ubuntu-ip:9001`
- API Health: `http://ubuntu-ip/health`

## Automatischer Start (Systemd)

Server automatisch beim Booten starten:

```bash
# Service aktivieren
sudo systemctl enable fin1-server

# Service starten
sudo systemctl start fin1-server

# Status prüfen
sudo systemctl status fin1-server
```

## Wartung

### Logs anzeigen

```bash
# Alle Services
docker compose logs -f

# Einzelner Service
docker compose logs -f parse-server

# Letzte 100 Zeilen
docker compose logs --tail=100 parse-server
```

### Services neu starten

```bash
# Alle Services
docker compose restart

# Einzelner Service
docker compose restart parse-server
```

### Backup erstellen

```bash
# MongoDB Backup
docker compose exec mongodb mongodump --out /backup/mongodb-$(date +%Y%m%d)

# PostgreSQL Backup
docker compose exec postgres pg_dump -U fin1_user fin1_analytics > ~/backups/postgres-$(date +%Y%m%d).sql
```

### Updates durchführen

```bash
# Services stoppen
docker compose down

# Images aktualisieren
docker compose pull

# Services neu bauen (falls Code geändert)
docker compose build

# Services starten
docker compose up -d
```

## Troubleshooting

### Port bereits belegt

```bash
# Port prüfen
sudo lsof -i :1337

# Prozess beenden
sudo kill -9 <PID>
```

### Container startet nicht

```bash
# Logs prüfen
docker compose logs parse-server

# Container-Status
docker compose ps -a

# Container neu erstellen
docker compose up -d --force-recreate parse-server
```

### Datenbank-Verbindungsfehler

```bash
# Datenbank-Container prüfen
docker compose ps mongodb postgres redis

# Verbindung testen
docker compose exec parse-server ping mongodb
docker compose exec parse-server ping postgres
docker compose exec parse-server ping redis
```

### Netzwerk-Probleme

```bash
# IP-Adresse prüfen
hostname -I

# Netzwerk-Verbindung testen
ping 8.8.8.8

# DNS prüfen
nslookup google.com

# Firewall-Status
sudo ufw status verbose
```

## Sicherheit

### Wichtige Sicherheitsmaßnahmen:

1. **Alle Standard-Passwörter ändern** in `.env`
2. **SSH-Key-Authentifizierung** verwenden (keine Passwort-Login)
3. **Firewall aktivieren** (UFW)
4. **Regelmäßige Updates:**
   ```bash
   sudo apt update && sudo apt upgrade -y
   ```
5. **SSL/TLS für Produktion** einrichten (Let's Encrypt)
6. **Backups regelmäßig** durchführen

## Support

Bei Problemen:
1. Logs prüfen: `docker compose logs -f`
2. Container-Status: `docker compose ps`
3. Netzwerk-Verbindung testen
4. Firewall-Regeln prüfen

## Nächste Schritte

Nach erfolgreichem Setup:
1. iOS-App konfigurieren (API-URL auf Ubuntu-IP setzen)
2. SSL-Zertifikate einrichten (für Produktion)
3. Monitoring einrichten
4. Backup-Strategie implementieren
