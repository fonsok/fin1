# FIN1 Netzwerk-Konfiguration - Referenz

**Datum:** 24. Januar 2026
**Status:** Produktiv ✅

## Kanone (Repo & Clients)

- **Ein physischer Server** (`iobox`): zwei LAN-Adressen (zwei NICs).
- **Parse-/HTTPS-Ziel für Apps, Admin-URLs, Dokumentation:** **`192.168.178.24`** (WLAN).
- **Derselbe Host per Kabel:** **`192.168.178.20`** (Ethernet) — gültig für SSH/rsync, gleicher Docker-Stack.

**Deploy-Ziele (welches Skript welche IP):** festgehalten in [`Documentation/OPERATIONAL_DEPLOY_HOSTS.md`](Documentation/OPERATIONAL_DEPLOY_HOSTS.md) inkl. `scripts/.env.server` / `show-fin1-deploy-targets.sh`.

## Server-Informationen

- **Ubuntu-Server-IP:** 192.168.178.24 (WLAN: wlp2s0)
- **Ubuntu-Server-IP (Ethernet):** 192.168.178.20 (Ethernet: enp3s0)
- **Mac-IP:** 192.168.178.25
- **Fritzbox-IP:** 192.168.178.1
- **Netzwerk-Subnetz:** 192.168.178.0/24
- **Hostname:** iobox

## Service-Ports

| Service | Port | Status | Zugriff |
|---------|------|--------|---------|
| Parse Server (via Nginx) | 443 | ✅ Running | 0.0.0.0 (HTTPS) |
| Nginx | 80, 443 | ✅ | 0.0.0.0 (HTTP→HTTPS Redirect) |
| Market Data | 8080 | ❌ Not Running | 0.0.0.0 (öffentlich) |
| Notification Service | 8081 | ❌ Not Running | 0.0.0.0 (öffentlich) |
| Analytics Service | 8082 | ❌ Not Running | 0.0.0.0 (öffentlich) |
| MinIO | 9000, 9001 | ✅ Running | 0.0.0.0 (öffentlich) |
| MongoDB | 27017 | ✅ Running | 127.0.0.1 (nur localhost) |
| PostgreSQL | 5432 | ✅ Running | 127.0.0.1 (nur localhost) |
| Redis | 6379 | ✅ Running | 127.0.0.1 (nur localhost) |

## Parse Server URLs

- **API URL:** `https://192.168.178.24/parse`
- **Live Query URL:** `wss://192.168.178.24/parse`
- **Application ID:** `fin1-app-id`
- **Master Key:** (siehe backend/.env)

## iOS-App Konfiguration

### ConfigurationService.swift
```swift
var parseServerURL: String? {
    return ProcessInfo.processInfo.environment["PARSE_SERVER_URL"]
        ?? "https://192.168.178.24/parse"
}
```

### Info.plist (ATS)
```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsLocalNetworking</key>
    <true/>
    <key>NSExceptionDomains</key>
    <dict>
        <key>192.168.178.24</key>
        <dict>
            <key>NSExceptionAllowsInsecureHTTPLoads</key>
            <true/>
        </dict>
    </dict>
</dict>
```

## Backend-Konfiguration

### .env Datei (Ubuntu Server)
```bash
PARSE_SERVER_PUBLIC_SERVER_URL=https://192.168.178.24/parse
PARSE_SERVER_LIVE_QUERY_SERVER_URL=wss://192.168.178.24/parse
ALLOWED_ORIGINS=http://localhost:3000,http://localhost:8080,http://192.168.178.0/24,*
```

## Docker-Netzwerk

- **Netzwerk-Name:** `fin1-server_fin1-network`
- **Subnet:** 172.20.0.0/16
- **Driver:** bridge

## Firewall (UFW)

**Status:** Aktiv

**Empfohlene Regeln (manuell hinzufügen):**
```bash
sudo ufw allow from 192.168.178.0/24 to any port 22    # SSH
sudo ufw allow from 192.168.178.0/24 to any port 80     # Nginx
sudo ufw allow from 192.168.178.0/24 to any port 443     # HTTPS (Parse/API)
sudo ufw allow from 192.168.178.0/24 to any port 8080   # Market Data
sudo ufw allow from 192.168.178.0/24 to any port 8081   # Notification
sudo ufw allow from 192.168.178.0/24 to any port 8082   # Analytics
sudo ufw allow from 192.168.178.0/24 to any port 9000   # MinIO
sudo ufw allow from 192.168.178.0/24 to any port 9001   # MinIO Console
```

## Fritzbox-Konfiguration

- **Fritzbox-IP:** 192.168.178.1
- **Weboberfläche:** http://fritz.box
- **Ubuntu-Server:** Feste IP empfohlen (192.168.178.24)

## Troubleshooting

### Parse Server nicht erreichbar
```bash
# Auf Ubuntu-Server prüfen
docker compose -f docker-compose.production.yml ps parse-server
docker compose -f docker-compose.production.yml logs parse-server

# Vom Mac testen
curl -sk https://192.168.178.24/parse/health
```

### Firewall blockiert Verbindungen
```bash
# Auf Ubuntu-Server
sudo ufw status
sudo ufw allow from 192.168.178.0/24 to any port 443
```

### Services im Restart-Loop
```bash
# Logs prüfen
docker compose -f docker-compose.production.yml logs [service-name]

# Service neu starten
docker compose -f docker-compose.production.yml restart [service-name]
```

## Wichtige Dateien

- **Backend .env:** `~/fin1-server/backend/.env`
- **Docker Compose:** `~/fin1-server/docker-compose.production.yml`
- **iOS Config:** `FIN1/Shared/Services/ConfigurationService.swift`
- **iOS Info.plist:** `Info.plist`
