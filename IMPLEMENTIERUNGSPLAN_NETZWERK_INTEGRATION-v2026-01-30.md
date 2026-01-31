# Detaillierter Implementierungsplan: Netzwerk-, Backend- und Frontend-Integration

## 📋 Übersicht

Dieser Plan beschreibt Schritt für Schritt, wie die gesamte FIN1-Infrastruktur optimal vernetzt wird, damit die iOS-App im Simulator zuverlässig mit dem Ubuntu-Server-Backend kommunizieren kann.

**Ziel:** Alle Services laufen stabil, iOS-App kann erfolgreich kommunizieren, WebSocket-Live-Query funktioniert.

---

## 🔍 Phase 0: Analyse & Vorbereitung (30-45 Minuten)

### Schritt 0.1: Aktuelle Situation dokumentieren

**Auf Ubuntu-Server:**

```bash
# 1. Server-IP-Adresse ermitteln
hostname -I
ip addr show | grep "inet " | grep -v 127.0.0.1

# 2. Netzwerk-Interface-Informationen
ip link show
cat /etc/netplan/*.yaml 2>/dev/null || cat /etc/network/interfaces 2>/dev/null

# 3. Firewall-Status prüfen
sudo ufw status verbose

# 4. Docker-Netzwerk prüfen
docker network ls
docker network inspect fin1-network 2>/dev/null || echo "Network not found"

# 5. Service-Status dokumentieren
cd ~/fin1-server
docker compose -f docker-compose.production.yml ps

# 6. Logs der problematischen Services prüfen
docker compose -f docker-compose.production.yml logs --tail=50 nginx
docker compose -f docker-compose.production.yml logs --tail=50 market-data
```

**Auf Mac:**

```bash
# 1. Mac-IP-Adresse ermitteln
ifconfig | grep "inet " | grep -v 127.0.0.1

# 2. Netzwerk-Verbindung zum Ubuntu-Server testen
ping -c 3 [UBUNTU-IP]  # Ubuntu-IP einsetzen

# 3. Port-Verfügbarkeit testen
nc -zv [UBUNTU-IP] 1337  # Parse Server
nc -zv [UBUNTU-IP] 80    # Nginx
nc -zv [UBUNTU-IP] 8080  # Market Data
```

**Ergebnis dokumentieren:**
- Ubuntu-Server-IP: `_________________`
- Mac-IP: `_________________`
- Netzwerk-Subnetz: `_________________`
- Problem-Services: Nginx (Port 80), Market Data (Port 8080)

### Schritt 0.2: Fritzbox-Konfiguration prüfen

**Fritzbox-Weboberfläche öffnen:**
1. Browser: `http://fritz.box` oder `http://192.168.178.1`
2. Anmelden mit Admin-Zugangsdaten

**Prüfen:**
- ✅ Ubuntu-Server hat feste IP-Adresse?
- ✅ Mac hat feste IP-Adresse? (optional, aber empfohlen)
- ✅ Portfreigaben für Ports 80, 1337, 8080 vorhanden?
- ✅ Firewall-Regeln für lokales Netzwerk?

**Dokumentieren:**
- Fritzbox-IP: `_________________`
- Ubuntu-Server feste IP: `_________________`
- Portfreigaben vorhanden: Ja / Nein

---

## 🔧 Phase 1: Service-Stabilität herstellen (60-90 Minuten)

### Schritt 1.1: Nginx-Restart-Loop beheben

**Problem:** Nginx startet kontinuierlich neu

**Diagnose auf Ubuntu-Server:**

```bash
cd ~/fin1-server

# 1. Detaillierte Nginx-Logs anzeigen
docker compose -f docker-compose.production.yml logs --tail=100 nginx

# 2. Nginx-Konfiguration testen
docker compose -f docker-compose.production.yml exec nginx nginx -t

# 3. Container-Status prüfen
docker compose -f docker-compose.production.yml ps nginx

# 4. Container-Details anzeigen
docker inspect fin1-nginx | grep -A 20 "State"
```

**Mögliche Ursachen und Lösungen:**

**A) Nginx-Konfigurationsfehler:**
```bash
# Nginx-Konfiguration prüfen
cat backend/nginx/nginx.conf

# Falls Fehler: Nginx-Konfiguration korrigieren
# Häufige Probleme:
# - Upstream-Server nicht erreichbar
# - Syntax-Fehler in nginx.conf
# - Fehlende SSL-Zertifikate (wenn HTTPS aktiviert)
```

**B) Upstream-Services nicht bereit:**
```bash
# Prüfen ob Parse Server läuft
docker compose -f docker-compose.production.yml ps parse-server

# Prüfen ob Market Data läuft
docker compose -f docker-compose.production.yml ps market-data

# Falls nicht: Services starten
docker compose -f docker-compose.production.yml up -d parse-server
docker compose -f docker-compose.production.yml up -d market-data
```

**C) Health-Check schlägt fehl:**
```bash
# Health-Check manuell testen
docker compose -f docker-compose.production.yml exec nginx wget --quiet --tries=1 --spider http://localhost/health

# Falls fehlschlägt: Health-Check-Endpoint prüfen
docker compose -f docker-compose.production.yml exec parse-server curl -f http://localhost:1337/health
```

**Lösung implementieren:**

```bash
# 1. Nginx stoppen
docker compose -f docker-compose.production.yml stop nginx

# 2. Nginx-Konfiguration validieren
docker compose -f docker-compose.production.yml run --rm nginx nginx -t

# 3. Falls Konfiguration OK: Nginx neu starten
docker compose -f docker-compose.production.yml up -d nginx

# 4. Status prüfen (sollte "Up" sein, nicht "restarting")
docker compose -f docker-compose.production.yml ps nginx

# 5. Logs prüfen (sollte keine Fehler zeigen)
docker compose -f docker-compose.production.yml logs --tail=20 nginx
```

**Validierung:**
```bash
# Nginx sollte jetzt "Up" sein
docker compose -f docker-compose.production.yml ps nginx | grep "Up"

# Health-Check sollte funktionieren
curl http://localhost/health
```

### Schritt 1.2: Market Data Service-Restart-Loop beheben

**Problem:** Market Data Service startet kontinuierlich neu

**Diagnose:**

```bash
cd ~/fin1-server

# 1. Detaillierte Logs anzeigen
docker compose -f docker-compose.production.yml logs --tail=100 market-data

# 2. Container-Status prüfen
docker compose -f docker-compose.production.yml ps market-data

# 3. Container-Details
docker inspect fin1-market-data | grep -A 20 "State"
```

**Mögliche Ursachen:**

**A) Abhängige Services nicht bereit:**
```bash
# Prüfen ob Redis läuft
docker compose -f docker-compose.production.yml ps redis

# Prüfen ob Parse Server läuft
docker compose -f docker-compose.production.yml ps parse-server

# Services starten falls nötig
docker compose -f docker-compose.production.yml up -d redis
docker compose -f docker-compose.production.yml up -d parse-server
```

**B) Umgebungsvariablen fehlen:**
```bash
# .env-Datei prüfen
cd ~/fin1-server/backend
cat .env | grep -E "REDIS|MARKET_DATA|PARSE_SERVER"

# Prüfen ob alle benötigten Variablen gesetzt sind:
# - REDIS_URL
# - PARSE_SERVER_URL
# - MARKET_DATA_API_KEY (optional)
```

**C) Health-Check schlägt fehl:**
```bash
# Health-Check manuell testen
docker compose -f docker-compose.production.yml exec market-data curl -f http://localhost:8080/health

# Falls fehlschlägt: Service-Logs prüfen
docker compose -f docker-compose.production.yml logs --tail=50 market-data
```

**Lösung implementieren:**

```bash
# 1. Market Data Service stoppen
docker compose -f docker-compose.production.yml stop market-data

# 2. Abhängige Services sicherstellen
docker compose -f docker-compose.production.yml up -d redis
docker compose -f docker-compose.production.yml up -d parse-server

# 3. Warten bis Services bereit sind (30 Sekunden)
sleep 30

# 4. Market Data Service neu starten
docker compose -f docker-compose.production.yml up -d market-data

# 5. Status prüfen
docker compose -f docker-compose.production.yml ps market-data

# 6. Logs prüfen
docker compose -f docker-compose.production.yml logs --tail=30 market-data
```

**Validierung:**
```bash
# Market Data sollte "Up" sein
docker compose -f docker-compose.production.yml ps market-data | grep "Up"

# Health-Check sollte funktionieren
curl http://localhost:8080/health
```

### Schritt 1.3: Alle Services validieren

```bash
cd ~/fin1-server

# Alle Services prüfen
docker compose -f docker-compose.production.yml ps

# Erwartetes Ergebnis: Alle Services "Up" (keine "restarting")
# Parse Server: Up
# MongoDB: Up
# PostgreSQL: Up
# Redis: Up
# MinIO: Up
# Nginx: Up
# Market Data: Up
# Notification Service: Up
# Analytics Service: Up

# Health-Checks testen
curl http://localhost/health                    # Nginx
curl http://localhost:1337/parse/health         # Parse Server
curl http://localhost:8080/health               # Market Data
curl http://localhost:8081/health               # Notification Service
curl http://localhost:8082/health               # Analytics Service
```

---

## 🌐 Phase 2: Netzwerk-Konfiguration (45-60 Minuten)

### Schritt 2.1: Ubuntu-Server Netzwerk optimieren

**2.1.1: Feste IP-Adresse sicherstellen**

```bash
# Auf Ubuntu-Server: Aktuelle IP prüfen
ip addr show

# Falls noch keine feste IP: In Fritzbox konfigurieren (siehe Schritt 0.2)
# Oder manuell in Ubuntu konfigurieren (falls DHCP nicht verwendet wird)
```

**2.1.2: Firewall (UFW) konfigurieren**

```bash
# Auf Ubuntu-Server:

# 1. UFW-Status prüfen
sudo ufw status verbose

# 2. Falls UFW aktiviert: Regeln für lokales Netzwerk hinzufügen
# Erlaubt Zugriff vom lokalen Netzwerk (192.168.178.0/24)
sudo ufw allow from 192.168.178.0/24 to any port 22    # SSH
sudo ufw allow from 192.168.178.0/24 to any port 80     # Nginx
sudo ufw allow from 192.168.178.0/24 to any port 1337   # Parse Server
sudo ufw allow from 192.168.178.0/24 to any port 8080   # Market Data
sudo ufw allow from 192.168.178.0/24 to any port 8081   # Notification Service
sudo ufw allow from 192.168.178.0/24 to any port 8082   # Analytics Service
sudo ufw allow from 192.168.178.0/24 to any port 9000   # MinIO
sudo ufw allow from 192.168.178.0/24 to any port 9001   # MinIO Console

# 3. UFW aktivieren (falls noch nicht aktiv)
sudo ufw --force enable

# 4. Status prüfen
sudo ufw status numbered
```

**2.1.3: Docker-Netzwerk prüfen**

```bash
# Docker-Netzwerk-Informationen
docker network inspect fin1-network

# Sollte zeigen:
# - Subnet: 172.20.0.0/16
# - Alle Services verbunden
```

### Schritt 2.2: Fritzbox-Konfiguration optimieren

**2.2.1: Feste IP-Adressen vergeben**

1. **Fritzbox-Weboberfläche öffnen:** `http://fritz.box`
2. **Menü:** `Heimnetz` → `Netzwerk` → `Geräte und Benutzer`
3. **Ubuntu-Server finden und bearbeiten:**
   - ✅ `Diesem Netzwerkgerät immer die gleiche IPv4-Adresse zuweisen` aktivieren
   - IP-Adresse wählen (z.B. `192.168.178.50`)
   - Gerätenamen vergeben: "FIN1-Server"
   - `Übernehmen` klicken
4. **Mac (optional):**
   - Gleiche Prozedur für Mac
   - Gerätenamen: "Mac-Tahoe"

**2.2.2: Portfreigaben konfigurieren (optional, für lokales Netzwerk normalerweise nicht nötig)**

**Hinweis:** Für lokales Netzwerk sind Portfreigaben normalerweise nicht erforderlich, da die Fritzbox lokale Verbindungen standardmäßig erlaubt. Falls dennoch Probleme auftreten:

1. **Menü:** `Internet` → `Freigaben` → `Portfreigaben`
2. **Neue Portfreigaben erstellen:**
   - **Port 80 (HTTP):** Gerät: FIN1-Server, Protokoll: TCP
   - **Port 1337 (Parse Server):** Gerät: FIN1-Server, Protokoll: TCP
   - **Port 8080 (Market Data):** Gerät: FIN1-Server, Protokoll: TCP

**2.2.3: WLAN-Optimierung (optional)**

1. **Menü:** `WLAN` → `Funkkanal` → `Funkkanal-Einstellungen`
2. **Empfehlungen:**
   - Automatische Kanalwahl aktivieren
   - 5 GHz und 2.4 GHz aktivieren (falls verfügbar)
   - WLAN-Geräte anzeigen aktivieren

### Schritt 2.3: Netzwerk-Verbindung testen

**Auf Mac:**

```bash
# 1. Ping-Test
ping -c 5 [UBUNTU-IP]

# 2. Port-Verfügbarkeit testen
nc -zv [UBUNTU-IP] 80     # Nginx
nc -zv [UBUNTU-IP] 1337   # Parse Server
nc -zv [UBUNTU-IP] 8080   # Market Data

# 3. HTTP-Verbindung testen
curl http://[UBUNTU-IP]/health
curl http://[UBUNTU-IP]:1337/parse/health

# 4. WebSocket-Verbindung testen (mit wscat, falls installiert)
# npm install -g wscat
# wscat -c ws://[UBUNTU-IP]:1337/parse
```

**Erwartetes Ergebnis:**
- ✅ Ping erfolgreich
- ✅ Alle Ports erreichbar
- ✅ HTTP-Antworten erhalten

---

## ⚙️ Phase 3: Backend-Konfiguration (60-90 Minuten)

### Schritt 3.1: Parse Server für lokales Netzwerk konfigurieren

**Auf Ubuntu-Server:**

```bash
cd ~/fin1-server/backend

# 1. Aktuelle .env-Datei prüfen
cat .env | grep PARSE_SERVER

# 2. Ubuntu-Server-IP ermitteln
UBUNTU_IP=$(hostname -I | awk '{print $1}')
echo "Ubuntu IP: $UBUNTU_IP"

# 3. .env-Datei mit Ubuntu-IP aktualisieren
# WICHTIG: Backup erstellen!
cp .env .env.backup.$(date +%Y%m%d_%H%M%S)

# 4. Parse Server URLs aktualisieren
sed -i "s|PARSE_SERVER_PUBLIC_SERVER_URL=.*|PARSE_SERVER_PUBLIC_SERVER_URL=http://$UBUNTU_IP:1337/parse|g" .env
sed -i "s|PARSE_SERVER_LIVE_QUERY_SERVER_URL=.*|PARSE_SERVER_LIVE_QUERY_SERVER_URL=ws://$UBUNTU_IP:1337/parse|g" .env

# 5. Änderungen prüfen
cat .env | grep PARSE_SERVER
```

**Manuelle Bearbeitung (falls sed nicht funktioniert):**

```bash
nano .env
```

**Zu ändern:**
```bash
# Vorher:
PARSE_SERVER_PUBLIC_SERVER_URL=http://localhost:1337/parse
PARSE_SERVER_LIVE_QUERY_SERVER_URL=ws://localhost:1337/parse

# Nachher (Ubuntu-IP einsetzen):
PARSE_SERVER_PUBLIC_SERVER_URL=http://192.168.178.50:1337/parse
PARSE_SERVER_LIVE_QUERY_SERVER_URL=ws://192.168.178.50:1337/parse
```

**CORS-Einstellungen anpassen:**

```bash
# .env-Datei bearbeiten
nano .env

# ALLOWED_ORIGINS erweitern (Mac-IP oder * für lokales Netzwerk)
# Beispiel:
ALLOWED_ORIGINS=http://localhost:3000,http://localhost:8080,http://192.168.178.0/24
# Oder für Entwicklung:
ALLOWED_ORIGINS=*
```

### Schritt 3.2: Parse Server neu starten

```bash
cd ~/fin1-server

# 1. Parse Server neu starten (um neue Konfiguration zu laden)
docker compose -f docker-compose.production.yml restart parse-server

# 2. Warten bis Service bereit ist
sleep 10

# 3. Status prüfen
docker compose -f docker-compose.production.yml ps parse-server

# 4. Logs prüfen
docker compose -f docker-compose.production.yml logs --tail=30 parse-server

# 5. Konfiguration validieren
curl http://localhost:1337/parse/health
curl http://[UBUNTU-IP]:1337/parse/health  # Von Mac aus testen
```

### Schritt 3.3: Nginx-Konfiguration prüfen

**Nginx sollte bereits korrekt konfiguriert sein, aber prüfen:**

```bash
cd ~/fin1-server

# 1. Nginx-Konfiguration anzeigen
cat backend/nginx/nginx.conf

# 2. Nginx-Konfiguration testen
docker compose -f docker-compose.production.yml exec nginx nginx -t

# 3. Falls Änderungen nötig: Nginx neu laden
docker compose -f docker-compose.production.yml exec nginx nginx -s reload

# 4. Oder Nginx neu starten
docker compose -f docker-compose.production.yml restart nginx
```

**Wichtige Nginx-Einstellungen prüfen:**

- ✅ Upstream-Server korrekt (parse-server:1337, market-data:8080, etc.)
- ✅ WebSocket-Support aktiviert (für Live Query)
- ✅ CORS-Header (falls nötig)

### Schritt 3.4: Alle Services neu starten (um Konfiguration zu übernehmen)

```bash
cd ~/fin1-server

# 1. Alle Services stoppen
docker compose -f docker-compose.production.yml down

# 2. Alle Services neu starten
docker compose -f docker-compose.production.yml up -d

# 3. Warten bis alle Services bereit sind (1-2 Minuten)
sleep 60

# 4. Status aller Services prüfen
docker compose -f docker-compose.production.yml ps

# 5. Alle sollten "Up" sein
```

---

## 📱 Phase 4: iOS-App-Konfiguration (30-45 Minuten)

### Schritt 4.1: Parse Server URL in iOS-App konfigurieren

**Auf Mac, im Xcode-Projekt:**

**Option A: Über Environment Variables (Empfohlen)**

1. **Xcode öffnen:** `FIN1.xcodeproj`
2. **Scheme bearbeiten:**
   - `Product` → `Scheme` → `Edit Scheme...`
   - `Run` → `Arguments` → `Environment Variables`
   - Hinzufügen:
     - `PARSE_SERVER_URL` = `http://[UBUNTU-IP]:1337/parse`
     - `PARSE_APPLICATION_ID` = `fin1-app-id`

**Option B: Über ConfigurationService.swift (Code-Änderung)**

```swift
// Datei: FIN1/Shared/Services/ConfigurationService.swift

// Zeile 24 ändern:
var parseServerURL: String? {
    // Für lokales Netzwerk: Ubuntu-IP verwenden
    return ProcessInfo.processInfo.environment["PARSE_SERVER_URL"] 
        ?? "http://192.168.178.50:1337/parse"  // Ubuntu-IP einsetzen!
}
```

**Option C: Über Build Configuration (Xcode)**

1. **Project Navigator:** FIN1-Projekt auswählen
2. **Target:** FIN1 auswählen
3. **Build Settings:** `User-Defined Settings`
4. **Hinzufügen:**
   - `PARSE_SERVER_URL` = `http://[UBUNTU-IP]:1337/parse`

### Schritt 4.2: iOS App Transport Security (ATS) konfigurieren

**Falls HTTP verwendet wird (nicht HTTPS):**

1. **Datei öffnen:** `Info.plist`
2. **Hinzufügen (falls nicht vorhanden):**

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsLocalNetworking</key>
    <true/>
    <key>NSExceptionDomains</key>
    <dict>
        <key>192.168.178.50</key>  <!-- Ubuntu-IP -->
        <dict>
            <key>NSExceptionAllowsInsecureHTTPLoads</key>
            <true/>
            <key>NSIncludesSubdomains</key>
            <true/>
        </dict>
    </dict>
</dict>
```

**Oder für gesamtes lokales Netzwerk:**

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsLocalNetworking</key>
    <true/>
    <key>NSAllowsArbitraryLoadsInWebContent</key>
    <true/>
</dict>
```

### Schritt 4.3: iOS-App testen

**In Xcode:**

1. **Simulator starten:** `Product` → `Destination` → `iPhone Simulator`
2. **App starten:** `Product` → `Run` (⌘R)
3. **Netzwerk-Verbindung prüfen:**
   - App sollte sich mit Parse Server verbinden können
   - Login/Signup sollte funktionieren
   - Live Query sollte funktionieren (falls implementiert)

**Debugging:**

```swift
// In der App: Parse Server URL loggen
print("Parse Server URL: \(configurationService.parseServerURL ?? "nil")")
print("Parse Live Query URL: \(configurationService.parseLiveQueryURL ?? "nil")")
```

**Auf Mac, Terminal (für Netzwerk-Debugging):**

```bash
# 1. Netzwerk-Traffic überwachen (mit tcpdump, falls installiert)
sudo tcpdump -i any -n host [UBUNTU-IP]

# 2. Oder mit netstat Verbindungen prüfen
netstat -an | grep [UBUNTU-IP]
```

---

## ✅ Phase 5: Validierung & Testing (45-60 Minuten)

### Schritt 5.1: End-to-End-Verbindungstest

**Auf Mac:**

```bash
# 1. Basis-Verbindungstest
ping -c 5 [UBUNTU-IP]

# 2. HTTP-Endpoints testen
curl -v http://[UBUNTU-IP]/health
curl -v http://[UBUNTU-IP]:1337/parse/health
curl -v http://[UBUNTU-IP]:8080/health

# 3. Parse Server API testen
curl -X POST http://[UBUNTU-IP]:1337/parse/classes/_User \
  -H "X-Parse-Application-Id: fin1-app-id" \
  -H "Content-Type: application/json" \
  -d '{"username":"test","password":"test123"}'

# 4. WebSocket-Verbindung testen (mit wscat)
# npm install -g wscat
wscat -c ws://[UBUNTU-IP]:1337/parse
```

### Schritt 5.2: Service-Stabilitätstest

**Auf Ubuntu-Server:**

```bash
cd ~/fin1-server

# 1. Alle Services prüfen (sollten alle "Up" sein)
docker compose -f docker-compose.production.yml ps

# 2. Logs auf Fehler prüfen
docker compose -f docker-compose.production.yml logs --tail=50 | grep -i error

# 3. Service-Restarts überwachen (5 Minuten)
watch -n 5 'docker compose -f docker-compose.production.yml ps'

# 4. Health-Checks alle 30 Sekunden (10 Mal)
for i in {1..10}; do
  echo "=== Test $i ==="
  curl -f http://localhost/health && echo "✓ Nginx OK" || echo "✗ Nginx FAILED"
  curl -f http://localhost:1337/parse/health && echo "✓ Parse Server OK" || echo "✗ Parse Server FAILED"
  curl -f http://localhost:8080/health && echo "✓ Market Data OK" || echo "✗ Market Data FAILED"
  sleep 30
done
```

### Schritt 5.3: iOS-App-Funktionalitätstest

**In Xcode Simulator:**

1. **App starten**
2. **Login/Signup testen:**
   - Neuen Benutzer registrieren
   - Mit bestehendem Benutzer einloggen
   - Logout testen

3. **API-Kommunikation testen:**
   - Daten laden (z.B. Dashboard)
   - Daten speichern (z.B. Profil aktualisieren)
   - Fehlerbehandlung (z.B. Netzwerk-Fehler)

4. **Live Query testen (falls implementiert):**
   - Daten in Backend ändern
   - Prüfen ob App automatisch aktualisiert wird

5. **Netzwerk-Fehlerbehandlung testen:**
   - Server stoppen: `docker compose -f docker-compose.production.yml stop parse-server`
   - App-Verhalten prüfen
   - Server starten: `docker compose -f docker-compose.production.yml start parse-server`
   - App sollte sich wieder verbinden

### Schritt 5.4: Performance-Test

**Auf Mac:**

```bash
# 1. Response-Zeit messen
time curl http://[UBUNTU-IP]:1337/parse/health

# 2. Mehrere parallele Requests
for i in {1..10}; do
  curl -s -o /dev/null -w "%{time_total}\n" http://[UBUNTU-IP]:1337/parse/health &
done
wait

# 3. WebSocket-Verbindungszeit
time wscat -c ws://[UBUNTU-IP]:1337/parse
```

---

## 📝 Phase 6: Dokumentation (30 Minuten)

### Schritt 6.1: Konfigurations-Dokumentation erstellen

**Datei erstellen:** `NETZWERK_KONFIGURATION.md`

```markdown
# FIN1 Netzwerk-Konfiguration

## Server-Informationen
- Ubuntu-Server-IP: [IP]
- Mac-IP: [IP]
- Fritzbox-IP: [IP]
- Netzwerk-Subnetz: 192.168.178.0/24

## Service-Ports
- Parse Server: 1337
- Nginx: 80
- Market Data: 8080
- Notification Service: 8081
- Analytics Service: 8082
- MinIO: 9000, 9001
- MongoDB: 27017 (nur localhost)
- PostgreSQL: 5432 (nur localhost)
- Redis: 6379 (nur localhost)

## Parse Server URLs
- API: http://[UBUNTU-IP]:1337/parse
- Live Query: ws://[UBUNTU-IP]:1337/parse

## iOS-App Konfiguration
- Parse Server URL: http://[UBUNTU-IP]:1337/parse
- Application ID: fin1-app-id
```

### Schritt 6.2: Troubleshooting-Guide erstellen

**Datei erstellen:** `TROUBLESHOOTING.md`

**Häufige Probleme:**

1. **Service im "restarting" Status:**
   ```bash
   docker compose -f docker-compose.production.yml logs [service-name]
   docker compose -f docker-compose.production.yml restart [service-name]
   ```

2. **iOS-App kann Server nicht erreichen:**
   - Ping-Test: `ping [UBUNTU-IP]`
   - Port-Test: `nc -zv [UBUNTU-IP] 1337`
   - ATS-Einstellungen prüfen

3. **WebSocket-Verbindung schlägt fehl:**
   - Nginx-WebSocket-Konfiguration prüfen
   - Parse Server Live Query aktiviert?

---

## 🎯 Zusammenfassung & Checkliste

### ✅ Phase 0: Analyse
- [ ] Aktuelle Situation dokumentiert
- [ ] Fritzbox-Konfiguration geprüft
- [ ] Probleme identifiziert

### ✅ Phase 1: Service-Stabilität
- [ ] Nginx läuft stabil (nicht mehr "restarting")
- [ ] Market Data Service läuft stabil
- [ ] Alle Services im "Up" Status

### ✅ Phase 2: Netzwerk
- [ ] Ubuntu-Server hat feste IP
- [ ] Firewall konfiguriert
- [ ] Fritzbox-Portfreigaben (falls nötig)
- [ ] Netzwerk-Verbindung getestet

### ✅ Phase 3: Backend
- [ ] Parse Server URLs auf Ubuntu-IP umgestellt
- [ ] CORS konfiguriert
- [ ] Alle Services neu gestartet
- [ ] Konfiguration validiert

### ✅ Phase 4: iOS-App
- [ ] Parse Server URL konfiguriert
- [ ] ATS-Einstellungen angepasst
- [ ] App kann Server erreichen

### ✅ Phase 5: Validierung
- [ ] End-to-End-Tests erfolgreich
- [ ] Service-Stabilität bestätigt
- [ ] iOS-App-Funktionalität getestet
- [ ] Performance akzeptabel

### ✅ Phase 6: Dokumentation
- [ ] Konfiguration dokumentiert
- [ ] Troubleshooting-Guide erstellt

---

## ⏱️ Geschätzter Gesamtaufwand

- **Phase 0:** 30-45 Minuten
- **Phase 1:** 60-90 Minuten
- **Phase 2:** 45-60 Minuten
- **Phase 3:** 60-90 Minuten
- **Phase 4:** 30-45 Minuten
- **Phase 5:** 45-60 Minuten
- **Phase 6:** 30 Minuten

**Gesamt:** 5-7 Stunden (je nach Komplexität der Probleme)

---

## 🚨 Wichtige Hinweise

1. **Backups erstellen:** Vor jeder Änderung Backups der Konfigurationsdateien erstellen
2. **Schrittweise vorgehen:** Jeden Schritt validieren bevor zum nächsten übergegangen wird
3. **Logs prüfen:** Bei Problemen immer zuerst die Logs prüfen
4. **Netzwerk testen:** Nach jeder Änderung die Netzwerk-Verbindung testen
5. **Dokumentation:** Alle Änderungen dokumentieren für zukünftige Referenz

---

## 📞 Support & Hilfe

Bei Problemen:
1. Logs prüfen: `docker compose -f docker-compose.production.yml logs [service]`
2. Service-Status prüfen: `docker compose -f docker-compose.production.yml ps`
3. Netzwerk-Verbindung testen: `ping`, `curl`, `nc`
4. Dokumentation konsultieren: `NETZWERK_KONFIGURATION.md`, `TROUBLESHOOTING.md`
