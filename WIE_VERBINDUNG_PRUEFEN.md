# Wie erkenne ich, ob die App mit dem Parse Server verbunden ist?

**Datum:** 24. Januar 2026

## 🔍 Methoden zur Überprüfung

### 1. In Xcode: Console-Logs prüfen ✅ (Einfachste Methode)

**Während die App läuft:**

1. **Xcode öffnen** und App im Simulator starten
2. **Console öffnen:** Unten in Xcode auf "Debug Area" klicken (⌘⇧Y)
3. **Nach folgenden Logs suchen:**

```
✅ Parse Live Query connected
```

**Oder bei Fehlern:**
```
⚠️ Failed to connect Parse Live Query: [Fehlermeldung]
```

**Zusätzlich:** Die App loggt auch:
```
🚀 App launch time: X.XXX seconds
```

### 2. Parse Server Logs auf Ubuntu prüfen ✅ (Zuverlässigste Methode)

**Auf Ubuntu-Server:**

```bash
# Parse Server Logs in Echtzeit anzeigen
ssh io@192.168.178.24 "cd ~/fin1-server && docker compose -f docker-compose.production.yml logs -f parse-server"
```

**Was du sehen solltest, wenn die App verbunden ist:**
- HTTP-Requests von der App (z.B. `POST /parse/login`, `GET /parse/classes/...`)
- IP-Adresse des Mac/Simulators (z.B. `192.168.178.25`)
- Status-Codes (200 = erfolgreich, 401 = Auth-Fehler, etc.)

**Beispiel-Logs:**
```
::ffff:192.168.178.25 - - [24/Jan/2026:20:00:00 +0000] "POST /parse/login HTTP/1.1" 200 123
::ffff:192.168.178.25 - - [24/Jan/2026:20:00:01 +0000] "GET /parse/classes/User HTTP/1.1" 200 456
```

### 3. Netzwerk-Traffic auf dem Mac überwachen ✅

**Im Terminal (auf dem Mac):**

```bash
# Netzwerk-Verbindungen zum Parse Server überwachen
sudo lsof -i -P | grep 192.168.178.24 | grep 443
```

**Oder mit netstat:**
```bash
netstat -an | grep 192.168.178.24 | grep 443
```

**Was du sehen solltest:**
- ESTABLISHED-Verbindungen zur IP `192.168.178.24:443`
- Das bedeutet, die App hat eine aktive Verbindung

### 4. Parse Server API direkt testen ✅

**Im Terminal (auf dem Mac):**

```bash
# Test: Health-Check
curl -sk https://192.168.178.24/parse/health

# Test: API-Endpoint (sollte Fehler geben, aber zeigt dass Server antwortet)
curl -sk -X POST https://192.168.178.24/parse/classes/TestClass \
  -H "X-Parse-Application-Id: fin1-app-id" \
  -H "Content-Type: application/json" \
  -d '{"test":"value"}'
```

### 5. In der App: Debug-Logging hinzufügen ✅

**Falls noch nicht vorhanden, kannst du Debug-Logging hinzufügen:**

Die App loggt bereits in `FIN1App.swift`:
- `✅ Parse Live Query connected` (bei erfolgreicher Verbindung)
- `⚠️ Failed to connect Parse Live Query: [Fehler]` (bei Fehler)

**Zusätzliches Logging hinzufügen:**

In `ConfigurationService.swift` oder `AppServicesBuilder.swift` kannst du prüfen:

```swift
print("🔗 Parse Server URL: \(configurationService.parseServerURL ?? "nil")")
print("🔗 Parse Live Query URL: \(configurationService.parseLiveQueryURL ?? "nil")")
```

## 🎯 Praktische Anleitung

### Schritt 1: App starten und Console öffnen

1. **Xcode öffnen**
2. **App im Simulator starten** (⌘R)
3. **Console öffnen** (⌘⇧Y)
4. **Nach Logs suchen:**
   - `✅ Parse Live Query connected` = **Verbunden!** ✅
   - `⚠️ Failed to connect` = **Nicht verbunden** ❌

### Schritt 2: Parse Server Logs prüfen

**In einem neuen Terminal-Fenster:**

```bash
# Logs in Echtzeit anzeigen
ssh io@192.168.178.24 "cd ~/fin1-server && docker compose -f docker-compose.production.yml logs -f parse-server"
```

**Dann in der App eine Aktion ausführen** (z.B. Login versuchen)

**Was du sehen solltest:**
- HTTP-Requests von der App
- IP-Adresse des Simulators
- Status-Codes

### Schritt 3: Netzwerk-Verbindung prüfen

**Im Terminal (auf dem Mac):**

```bash
# Während die App läuft:
sudo lsof -i -P | grep 192.168.178.24
```

**Was du sehen solltest:**
- Prozess (z.B. `Simulator` oder `FIN1`)
- Verbindung zu `192.168.178.24:443`

## ✅ Erfolgs-Indikatoren

### App ist verbunden, wenn:

1. ✅ **Console zeigt:** `✅ Parse Live Query connected`
2. ✅ **Parse Server Logs zeigen:** HTTP-Requests von der App
3. ✅ **Netzwerk-Tools zeigen:** ESTABLISHED-Verbindung zu Port 1337
4. ✅ **App funktioniert:** Login/Signup funktioniert, Daten werden geladen

### App ist NICHT verbunden, wenn:

1. ❌ **Console zeigt:** `⚠️ Failed to connect Parse Live Query`
2. ❌ **Parse Server Logs zeigen:** Keine Requests von der App
3. ❌ **App zeigt Fehler:** "Network error", "Connection failed"
4. ❌ **Netzwerk-Tools zeigen:** Keine Verbindung zu Port 1337

## 🔧 Troubleshooting

### Problem: Keine Logs in Console

**Lösung:**
- Prüfe ob Console-Filter aktiv ist
- Prüfe ob Logs nach oben scrollen
- Prüfe ob App wirklich läuft

### Problem: Parse Server zeigt keine Requests

**Lösung:**
1. Prüfe ob Parse Server läuft:
   ```bash
   ssh io@192.168.178.24 "cd ~/fin1-server && docker compose -f docker-compose.production.yml ps parse-server"
   ```

2. Prüfe Parse Server URL in der App:
   - Sollte sein: `https://192.168.178.24/parse`
   - Prüfe in `ConfigurationService.swift`

3. Prüfe ATS-Einstellungen in `Info.plist`

### Problem: "Failed to connect Parse Live Query"

**Mögliche Ursachen:**
- Parse Server läuft nicht
- Falsche URL konfiguriert
- Firewall blockiert Verbindung
- Netzwerk-Problem

**Lösung:**
1. Parse Server testen: `curl -sk https://192.168.178.24/parse/health`
2. URL in `ConfigurationService.swift` prüfen
3. Firewall-Regeln prüfen
4. Netzwerk-Verbindung testen: `ping 192.168.178.24`

## 📝 Quick-Check-Liste

- [ ] App im Simulator gestartet
- [ ] Console geöffnet (⌘⇧Y)
- [ ] Nach `✅ Parse Live Query connected` gesucht
- [ ] Parse Server Logs geöffnet (optional)
- [ ] Netzwerk-Verbindung geprüft (optional)
- [ ] App-Funktionalität getestet (Login/Signup)

## 🎯 Einfachste Methode

**Die einfachste Methode ist die Console in Xcode:**

1. App starten
2. Console öffnen (⌘⇧Y)
3. Nach `✅ Parse Live Query connected` suchen

**Wenn du das siehst = App ist verbunden!** ✅
