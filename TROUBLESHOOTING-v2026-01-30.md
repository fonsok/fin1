# FIN1 Netzwerk-Integration - Troubleshooting-Guide

**Datum:** 24. Januar 2026

## Häufige Probleme und Lösungen

### 1. Parse Server nicht erreichbar vom Mac

**Symptome:**
- iOS-App kann sich nicht mit Server verbinden
- `curl http://192.168.178.24:1337/parse/health` schlägt fehl

**Lösung:**
```bash
# 1. Prüfe ob Parse Server läuft
ssh io@192.168.178.24 "cd ~/fin1-server && docker compose -f docker-compose.production.yml ps parse-server"

# 2. Prüfe Logs
ssh io@192.168.178.24 "cd ~/fin1-server && docker compose -f docker-compose.production.yml logs --tail=20 parse-server"

# 3. Prüfe Firewall
ssh io@192.168.178.24 "sudo ufw status | grep 1337"

# 4. Parse Server neu starten
ssh io@192.168.178.24 "cd ~/fin1-server && docker compose -f docker-compose.production.yml restart parse-server"
```

### 2. Service im "restarting" Status

**Symptome:**
- Service startet kontinuierlich neu
- `docker compose ps` zeigt "Restarting"

**Lösung:**
```bash
# 1. Logs prüfen
docker compose -f docker-compose.production.yml logs [service-name]

# 2. Service stoppen
docker compose -f docker-compose.production.yml stop [service-name]

# 3. Abhängige Services prüfen
docker compose -f docker-compose.production.yml ps

# 4. Service neu starten
docker compose -f docker-compose.production.yml up -d [service-name]
```

**Häufige Ursachen:**
- Abhängige Services nicht bereit
- Konfigurationsfehler
- Port bereits belegt
- Fehlende Dateien (z.B. index.js)

### 3. MongoDB Log-Verzeichnis-Problem

**Symptome:**
- MongoDB im Restart-Loop
- Fehler: `Failed to open /var/log/mongodb/mongod.log`

**Lösung:**
```bash
# In docker-compose.production.yml:
# Logging-Kommando deaktivieren:
# command: mongod --logpath /var/log/mongodb/mongod.log --logappend
# → Auskommentieren oder entfernen
```

### 4. Nginx findet Upstream-Services nicht

**Symptome:**
- Nginx im Restart-Loop
- Fehler: `host not found in upstream "market-data:8080"`

**Lösung:**
```bash
# 1. Prüfe ob Upstream-Services laufen
docker compose -f docker-compose.production.yml ps market-data notification-service

# 2. Starte fehlende Services
docker compose -f docker-compose.production.yml up -d market-data notification-service analytics-service

# 3. Nginx neu starten
docker compose -f docker-compose.production.yml restart nginx
```

**Hinweis:** Nginx ist optional - Parse Server ist direkt erreichbar!

### 5. iOS-App kann Server nicht erreichen

**Symptome:**
- App zeigt Netzwerk-Fehler
- Verbindung schlägt fehl

**Lösung:**

**A) Prüfe ConfigurationService.swift:**
```swift
// Sollte sein:
return ProcessInfo.processInfo.environment["PARSE_SERVER_URL"] 
    ?? "http://192.168.178.24:1337/parse"
```

**B) Prüfe Info.plist:**
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

**C) Teste Verbindung vom Mac:**
```bash
curl http://192.168.178.24:1337/parse/health
```

**D) Prüfe Simulator-Netzwerk:**
- Simulator sollte im selben WLAN sein
- Prüfe ob Simulator die Server-IP erreichen kann

### 6. Firewall blockiert Verbindungen

**Symptome:**
- Ports nicht erreichbar
- "No route to host" Fehler

**Lösung:**
```bash
# Auf Ubuntu-Server:
# 1. UFW-Status prüfen
sudo ufw status

# 2. Regeln für lokales Netzwerk hinzufügen
sudo ufw allow from 192.168.178.0/24 to any port 1337
sudo ufw allow from 192.168.178.0/24 to any port 80
sudo ufw allow from 192.168.178.0/24 to any port 8080

# 3. Firewall aktivieren (falls inaktiv)
sudo ufw --force enable
```

### 7. Parse Server Health-Check schlägt fehl

**Symptome:**
- Parse Server läuft, aber Health-Check gibt 503 zurück
- Service zeigt "unhealthy"

**Lösung:**
```bash
# 1. Prüfe .env Konfiguration
ssh io@192.168.178.24 "cd ~/fin1-server/backend && cat .env | grep PARSE_SERVER"

# 2. Prüfe ob URLs korrekt sind
# Sollte sein:
# PARSE_SERVER_PUBLIC_SERVER_URL=http://192.168.178.24:1337/parse
# PARSE_SERVER_LIVE_QUERY_SERVER_URL=ws://192.168.178.24:1337/parse

# 3. Parse Server neu starten
ssh io@192.168.178.24 "cd ~/fin1-server && docker compose -f docker-compose.production.yml restart parse-server"

# 4. Warten und erneut prüfen
sleep 20
curl http://192.168.178.24:1337/parse/health
```

### 8. Market Data Service fehlt index.js

**Symptome:**
- Market Data Service im Restart-Loop
- Fehler: `Cannot find module '/app/index.js'`

**Lösung:**
```bash
# 1. Prüfe ob index.js existiert
ssh io@192.168.178.24 "ls -la ~/fin1-server/backend/market-data/"

# 2. Falls fehlt: Von Mac kopieren
scp backend/market-data/index.js io@192.168.178.24:~/fin1-server/backend/market-data/

# 3. Image neu bauen
ssh io@192.168.178.24 "cd ~/fin1-server && docker compose -f docker-compose.production.yml build market-data"

# 4. Service starten
ssh io@192.168.178.24 "cd ~/fin1-server && docker compose -f docker-compose.production.yml up -d market-data"
```

## Nützliche Befehle

### Service-Status prüfen
```bash
ssh io@192.168.178.24 "cd ~/fin1-server && docker compose -f docker-compose.production.yml ps"
```

### Logs anzeigen
```bash
ssh io@192.168.178.24 "cd ~/fin1-server && docker compose -f docker-compose.production.yml logs [service-name]"
```

### Alle Services neu starten
```bash
ssh io@192.168.178.24 "cd ~/fin1-server && docker compose -f docker-compose.production.yml restart"
```

### Netzwerk-Verbindung testen
```bash
# Vom Mac
ping 192.168.178.24
curl http://192.168.178.24:1337/parse/health
nc -zv 192.168.178.24 1337
```

### Parse Server URL testen
```bash
curl -X POST http://192.168.178.24:1337/parse/classes/TestClass \
  -H "X-Parse-Application-Id: fin1-app-id" \
  -H "Content-Type: application/json" \
  -d '{"test":"value"}'
```

## Support

Bei weiteren Problemen:
1. Logs prüfen: `docker compose logs [service]`
2. Service-Status prüfen: `docker compose ps`
3. Netzwerk-Verbindung testen: `ping`, `curl`, `nc`
4. Dokumentation konsultieren: `NETZWERK_KONFIGURATION.md`
