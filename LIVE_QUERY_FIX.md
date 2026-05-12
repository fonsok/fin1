# 🔧 Live Query WebSocket-Verbindung - Fix

**Problem:** Live Query WebSocket-Verbindung schlägt fehl mit "bad response from the server"

**Ursache:** Parse Server Live Query benötigt einen separaten WebSocket-Server, der nicht gestartet wurde.

**Lösung:** Parse Live Query Server wurde zum Parse Server hinzugefügt.

---

## ✅ Was wurde geändert

**Datei:** `backend/parse-server/index.js`

Der Parse Live Query WebSocket Server wurde hinzugefügt:

```javascript
// Start Parse Live Query WebSocket Server
const ParseLiveQueryServer = require('parse-server').ParseLiveQueryServer;

const liveQueryServer = new ParseLiveQueryServer(httpServer, {
  appId: parseServerConfig.appId,
  masterKey: parseServerConfig.masterKey,
  serverURL: parseServerConfig.serverURL,
  websocketTimeout: 10 * 1000, // 10 seconds
  cacheTimeout: 5 * 1000, // 5 seconds
  logLevel: process.env.LOG_LEVEL || 'INFO',
});
```

---

## 🚀 Nächste Schritte

### 1. Parse Server auf Ubuntu neu starten

```bash
ssh io@192.168.178.24 "cd ~/fin1-server && docker compose -f docker-compose.production.yml restart parse-server"
```

**Oder vollständig neu bauen (falls Code-Änderungen):**

```bash
ssh io@192.168.178.24 "cd ~/fin1-server && docker compose -f docker-compose.production.yml up -d --build parse-server"
```

### 2. Parse Server Logs prüfen

```bash
ssh io@192.168.178.24 "cd ~/fin1-server && docker compose -f docker-compose.production.yml logs -f parse-server"
```

**Was du sehen solltest:**
```
✅ Parse Live Query WebSocket Server started on port 1337
```

### 3. App neu starten

1. **Xcode:** Product → Clean Build Folder (⇧⌘K)
2. **Xcode:** Product → Build (⌘B)
3. **Xcode:** Product → Run (⌘R)

### 4. Console-Logs prüfen

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

**Lösung 1:** Prüfe ob Parse Server neu gestartet wurde:
```bash
ssh io@192.168.178.24 "cd ~/fin1-server && docker compose -f docker-compose.production.yml ps parse-server"
```

**Lösung 2:** Prüfe Parse Server Logs auf Fehler:
```bash
ssh io@192.168.178.24 "cd ~/fin1-server && docker compose -f docker-compose.production.yml logs parse-server | grep -i 'live query\|websocket\|error'"
```

**Lösung 3:** Prüfe ob WebSocket-Verbindung funktioniert:
```bash
# Test WebSocket-Verbindung (benötigt wscat oder ähnliches)
# Oder prüfe in den Parse Server Logs nach WebSocket-Verbindungen
```

### Problem: Parse Server startet nicht

**Lösung:** Prüfe ob `parse-server-live-query` installiert ist:
```bash
ssh io@192.168.178.24 "cd ~/fin1-server && docker compose -f docker-compose.production.yml exec parse-server npm list parse-server-live-query"
```

Falls nicht installiert, muss das Docker-Image neu gebaut werden.

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

---

## ✅ Erfolg

**Wenn du `✅ Parse Live Query connected successfully!` in der Console siehst, funktioniert Live Query!**

Die App kann dann:
- ✅ Live Updates von Parse Server empfangen
- ✅ Real-time Updates für Konto-Transaktionen, Order, Trade, etc. (Wallet-Feature deaktiviert)
- ✅ Automatische UI-Updates bei Datenänderungen
