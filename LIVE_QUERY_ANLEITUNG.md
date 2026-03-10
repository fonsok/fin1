# 🔧 Live Query WebSocket-Verbindung - Anleitung

## Problem

Die App zeigt:
```
⚠️ Failed to connect Parse Live Query: There was a bad response from the server.
```

**Ursache:** Parse Server Live Query benötigt einen separaten WebSocket-Server, der nicht gestartet wurde.

---

## ✅ Lösung

Der Parse Live Query WebSocket Server wurde zum Parse Server hinzugefügt.

### Was wurde geändert

**Datei:** `backend/parse-server/index.js`

```javascript
// Start Parse Live Query WebSocket Server
ParseServer.createLiveQueryServer(httpServer, {
  appId: parseServerConfig.appId,
  masterKey: parseServerConfig.masterKey,
  serverURL: parseServerConfig.serverURL,
  websocketTimeout: 10 * 1000, // 10 seconds
  cacheTimeout: 5 * 1000, // 5 seconds
  logLevel: process.env.LOG_LEVEL || 'INFO',
}).then(() => {
  console.log('✅ Parse Live Query WebSocket Server started on port', port);
}).catch((error) => {
  console.error('❌ Failed to start Parse Live Query Server:', error);
});
```

---

## 🚀 Installation auf Ubuntu Server

### Option 1: Automatisch (Script)

```bash
cd /Users/ra/app/FIN1
./scripts/copy-parse-server-to-ubuntu.sh 192.168.178.24 io
```

Das Script:
1. Kopiert `backend/parse-server/index.js` auf den Server
2. Baut den Parse Server Container neu
3. Startet den Service

### Option 2: Manuell

**1. Code auf Server kopieren:**
```bash
scp backend/parse-server/index.js io@192.168.178.24:~/fin1-server/backend/parse-server/index.js
```

**2. Parse Server neu bauen:**
```bash
ssh io@192.168.178.24 "cd ~/fin1-server && docker compose -f docker-compose.production.yml up -d --build parse-server"
```

**3. Logs prüfen:**
```bash
ssh io@192.168.178.24 "cd ~/fin1-server && docker compose -f docker-compose.production.yml logs -f parse-server"
```

**Was du sehen solltest:**
```
✅ Parse Live Query WebSocket Server started on port 1337
```

---

## 📱 App testen

### 1. App neu starten

1. **Xcode:** Product → Clean Build Folder (⇧⌘K)
2. **Xcode:** Product → Build (⌘B)
3. **Xcode:** Product → Run (⌘R)

### 2. Console-Logs prüfen

**Erfolgreich verbunden:**
```
🔗 Parse Server Configuration:
   URL: https://192.168.178.24/parse
   Live Query URL: wss://192.168.178.24/parse
   Application ID: fin1-app-id
✅ Parse Live Query connected successfully!
```

**Bei Fehler:**
```
⚠️ Failed to connect Parse Live Query: [Fehlermeldung]
```

---

## 🔍 Troubleshooting

### Problem: "bad response from the server" bleibt bestehen

**1. Prüfe ob Parse Server neu gestartet wurde:**
```bash
ssh io@192.168.178.24 "cd ~/fin1-server && docker compose -f docker-compose.production.yml ps parse-server"
```

**2. Prüfe Parse Server Logs:**
```bash
ssh io@192.168.178.24 "cd ~/fin1-server && docker compose -f docker-compose.production.yml logs parse-server | tail -50"
```

**Suche nach:**
- `✅ Parse Live Query WebSocket Server started`
- `❌ Failed to start Parse Live Query Server`
- WebSocket-bezogene Fehler

**3. Prüfe ob WebSocket-Verbindung funktioniert:**
```bash
# Test WebSocket (benötigt wscat)
# Oder prüfe in den Parse Server Logs nach WebSocket-Verbindungen
```

### Problem: Parse Server startet nicht

**1. Prüfe Docker-Logs:**
```bash
ssh io@192.168.178.24 "cd ~/fin1-server && docker compose -f docker-compose.production.yml logs parse-server"
```

**2. Prüfe ob `parse-server-live-query` installiert ist:**
```bash
ssh io@192.168.178.24 "cd ~/fin1-server && docker compose -f docker-compose.production.yml exec parse-server npm list parse-server-live-query"
```

Falls nicht installiert, muss das Docker-Image neu gebaut werden.

**3. Prüfe Syntax-Fehler:**
```bash
ssh io@192.168.178.24 "cd ~/fin1-server && docker compose -f docker-compose.production.yml exec parse-server node -c /app/index.js"
```

### Problem: WebSocket-Verbindung wird abgelehnt

**1. Prüfe Firewall:**
```bash
ssh io@192.168.178.24 "sudo ufw status | grep 443"
```

**2. Prüfe ob HTTPS/WebSocket erreichbar ist:**
```bash
curl -vsk -H "Upgrade: websocket" -H "Connection: Upgrade" https://192.168.178.24/parse
```

**3. Prüfe Parse Server Konfiguration:**
```bash
ssh io@192.168.178.24 "cd ~/fin1-server && cat backend/.env | grep LIVE_QUERY"
```

---

## ✅ Erfolg

**Wenn du `✅ Parse Live Query connected successfully!` in der Console siehst, funktioniert Live Query!**

Die App kann dann:
- ✅ Live Updates von Parse Server empfangen
- ✅ Real-time Updates für WalletTransaction, Order, Trade, etc.
- ✅ Automatische UI-Updates bei Datenänderungen

---

## 📝 Technische Details

### Parse Live Query Server

- **Port:** Verwendet denselben Port wie der HTTP-Server (1337)
- **Protokoll:** WebSocket (ws:// oder wss://)
- **Endpoint:** `/parse` (gleich wie HTTP API)
- **Timeout:** 10 Sekunden für WebSocket-Ping/Pong
- **Cache:** 5 Sekunden für Session-Token-Cache

### WebSocket-Upgrade

Der HTTP-Server akzeptiert jetzt WebSocket-Upgrade-Anfragen:
- `Upgrade: websocket`
- `Connection: Upgrade`
- `Sec-WebSocket-Key: [key]`
- `Sec-WebSocket-Version: 13`

### Live Query Klassen

Folgende Klassen unterstützen Live Query:
- `WalletTransaction`
- `Order`
- `Trade`
- `ComplianceEvent`
- `Investment`
- `Notification`
- `Document`
- `User`
- `MarketData`
- `PriceAlert`
