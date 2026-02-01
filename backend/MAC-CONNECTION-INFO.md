# Mac → FIN1 Server Verbindungsinformationen

## Übersicht

Diese Dokumentation listet alle Informationen auf, die der Mac benötigt, um sich mit dem FIN1-Server zu verbinden.

---

## 🔑 Wichtige Informationen für Xcode/iOS-App

### 1. Server-IP-Adresse

**Aktuelle Server-IP:**
```
192.168.178.24
```

**Wie ermitteln:**
```bash
# Auf dem Server ausführen:
hostname -I
# Oder:
ip addr show | grep "inet " | grep -v 127.0.0.1
```

**Wichtig:**
- ✅ Diese IP wird in der iOS-App konfiguriert
- ✅ Mac und Server müssen im gleichen Netzwerk sein
- ✅ Statische IP für Server empfohlen (in Fritzbox konfigurieren)

---

### 2. Parse Server URL

**Vollständige URL:**
```
http://192.168.178.24/parse
```

**Komponenten:**
- **Protokoll:** `http://` (oder `https://` wenn SSL konfiguriert)
- **IP:** `192.168.178.24` (Server-IP)
- **Port:** `80` (via Nginx Reverse Proxy)
- **Pfad:** `/parse` (Parse Server Endpoint via Nginx)

**Live Query URL (WebSocket):**
```
ws://192.168.178.24/parse
```

---

### 3. Application ID

**Parse Server Application ID:**
```
fin1-app-id
```

**Wo finden:**
- Server: `/home/io/fin1-server/backend/.env`
- Variable: `PARSE_SERVER_APPLICATION_ID`

**Wichtig:**
- ✅ Muss in Xcode konfiguriert werden
- ✅ Muss mit Server-Konfiguration übereinstimmen

---

### 4. Xcode Konfiguration (Swift)

**In App.swift oder AppDelegate.swift:**

```swift
import ParseSwift

@main
struct FIN1App: App {
    init() {
        ParseServerConfiguration.initialize(
            applicationId: "fin1-app-id",                    // ← Application ID
            serverURL: "http://192.168.178.24/parse"        // ← Server URL
        )

        #if DEBUG
        ParseServerConfiguration.logLevel = .debug
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

**Mit Live Query:**
```swift
ParseServerConfiguration.initialize(
    applicationId: "fin1-app-id",
    serverURL: "http://192.168.178.24/parse",
    liveQueryURL: "ws://192.168.178.24/parse"  // Optional
)
```

---

### 5. Info.plist Konfiguration

**App Transport Security (ATS) für lokales Netzwerk:**

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
            <key>NSIncludesSubdomains</key>
            <true/>
        </dict>
    </dict>
</dict>
```

**Optional: Server-URL in Info.plist speichern:**

```xml
<key>ParseServerURL</key>
<string>http://192.168.178.24/parse</string>
<key>ParseApplicationId</key>
<string>fin1-app-id</string>
```

Dann im Code:
```swift
let serverURL = Bundle.main.object(forInfoDictionaryKey: "ParseServerURL") as! String
let appId = Bundle.main.object(forInfoDictionaryKey: "ParseApplicationId") as! String

ParseServerConfiguration.initialize(
    applicationId: appId,
    serverURL: serverURL
)
```

---

## 🌐 Netzwerk-Konfiguration

### Mac IP-Adresse

**Empfohlene Mac-IP:**
```
192.168.178.25
```

**Wichtig:**
- ✅ Muss **anders** sein als Server-IP (`192.168.178.24`)
- ✅ Kann dynamisch (DHCP) oder statisch sein
- ✅ Statische IP empfohlen für Entwicklung

**Mac-IP ermitteln:**
```bash
# Auf dem Mac:
ipconfig getifaddr en0  # WLAN-IP
# Oder:
ifconfig | grep "inet " | grep -v 127.0.0.1
```

---

### Netzwerk-Übersicht

| Gerät | IP-Adresse | Verwendung |
|-------|------------|------------|
| **Server** | `192.168.178.24` | **Diese IP in iOS-App konfigurieren!** |
| **Mac** | `192.168.178.25` | Entwicklungsrechner (Xcode) |
| **iPhone** | `192.168.178.26` | Testgerät (eigene IP) |

**Wichtig:**
- ✅ Alle Geräte müssen im gleichen WLAN sein
- ✅ Server-IP wird in der App verwendet (nicht Mac-IP!)
- ✅ Mac-IP ist nur für Netzwerk-Identifikation

---

## 🔍 Verbindung testen

### 1. Vom Mac aus testen

**Health-Check:**
```bash
curl http://192.168.178.24/health
```

**Parse Server Info:**
```bash
curl http://192.168.178.24/parse
```

**Erwartete Ausgabe (Health-Check):**
```json
{
  "status": "healthy",
  "timestamp": "2026-01-29T...",
  "version": "1.0.0"
}
```

### 2. Port-Verfügbarkeit prüfen

```bash
# Port 80 prüfen (Nginx)
nc -zv 192.168.178.24 80

# Oder mit telnet
telnet 192.168.178.24 1338
```

**Erwartete Ausgabe:**
```
Connection to 192.168.178.24 port 80 [tcp/*] succeeded!
```

### 3. Browser-Test

Öffnen Sie im Browser auf dem Mac:
```
http://192.168.178.24/health
```

Sie sollten die JSON-Antwort sehen.

---

## 📋 Checkliste für Xcode-Setup

### Voraussetzungen
- [ ] Server läuft und ist erreichbar
- [ ] Mac und Server im gleichen WLAN
- [ ] Port 1338 ist erreichbar (`curl http://SERVER_IP:1338/health`)
- [ ] Port 80 ist erreichbar (`curl http://SERVER_IP/health`)

### Xcode-Konfiguration
- [ ] ParseSwift SDK hinzugefügt
- [ ] Application ID konfiguriert: `fin1-app-id`
- [ ] Server URL konfiguriert: `http://192.168.178.24:1338/parse`
- [ ] Server URL konfiguriert: `http://192.168.178.24/parse`
- [ ] Info.plist ATS-Einstellungen für Server-IP vorhanden

### Testing
- [ ] App baut erfolgreich (keine Compile-Fehler)
- [ ] Verbindung zum Server erfolgreich
- [ ] Health-Check funktioniert
- [ ] Parse Server Requests funktionieren

---

## 🔧 Troubleshooting

### Problem: Verbindung schlägt fehl

**1. Server erreichbar?**
```bash
ping 192.168.178.24
```

**2. Port offen?**
```bash
nc -zv 192.168.178.24 80
```

**3. Firewall prüfen:**
```bash
# Auf dem Server:
sudo ufw status
sudo ufw allow 80/tcp
```

**4. Container läuft?**
```bash
# Auf dem Server:
docker compose -f docker-compose.production.yml ps
```

### Problem: "Connection refused"

- ✅ Container läuft nicht → Container starten
- ✅ Falscher Port → Port 80 (Nginx) verwenden
- ✅ Firewall blockiert → Port 80 öffnen

### Problem: "Network unreachable"

- ✅ Mac und Server im gleichen WLAN?
- ✅ Server-IP korrekt?
- ✅ Router/Firewall blockiert Verbindung?

---

## 📝 Zusammenfassung

**Minimale Informationen für Xcode:**

1. **Server-IP:** `192.168.178.24`
2. **Port:** `1338`
3. **Application ID:** `fin1-app-id`
4. **Server URL:** `http://192.168.178.24/parse`

**Swift-Code:**
```swift
ParseServerConfiguration.initialize(
    applicationId: "fin1-app-id",
    serverURL: "http://192.168.178.24/parse"
)
```

**Das war's!** 🎉

---

## 🔐 Parse Dashboard (robust & sicher)

Aus Sicherheitsgründen sollte das Parse Dashboard **nicht** im LAN öffentlich erreichbar sein,
weil es im Browser mit erhöhten Rechten (Master Key) arbeitet.

**Empfehlung:** Dashboard nur per SSH-Tunnel öffnen.

### SSH Tunnel (Mac → Ubuntu)

```bash
# Port 1338 lokal auf dem Mac -> Port 1338 (localhost) auf dem Server
ssh -L 1338:127.0.0.1:1338 io@192.168.178.24
```

Dann im Browser auf dem Mac:

```
http://localhost:1338/dashboard
```

---

**Letzte Aktualisierung:** 29. Januar 2026
**Version:** 1.0.0


Wichtige Punkte
Server-IP: 192.168.178.24 (in der App verwenden)
Mac-IP: 192.168.178.25 (nur für Netzwerk-Identifikation)
Port: 1338 (nicht 1337!)
Alle Geräte müssen im gleichen WLAN sein



Informationen für Mac → FIN1-Server Verbindung
Minimale Informationen für Xcode
Server-IP-Adresse: 192.168.178.24
Port: 1338 (externer Port)
Application ID: fin1-app-id
Server URL: http://192.168.178.24:1338/parse

