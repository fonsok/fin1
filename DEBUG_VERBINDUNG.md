# Debug: App-Verbindung zu Parse Server überprüfen

**Schnellste Methode:** Xcode Console prüfen

## 🎯 Methode 1: Xcode Console (Empfohlen)

### Schritt-für-Schritt:

1. **Xcode öffnen**
2. **App im Simulator starten** (⌘R)
3. **Console öffnen:**
   - Unten in Xcode auf "Debug Area" klicken
   - Oder Tastenkürzel: **⌘⇧Y** (Cmd+Shift+Y)
4. **Nach folgenden Logs suchen:**

**✅ Erfolgreich verbunden:**
```
✅ Parse Live Query connected
🚀 App launch time: X.XXX seconds
```

**❌ Nicht verbunden:**
```
⚠️ Failed to connect Parse Live Query: [Fehlermeldung]
```

### Was bedeutet das?

- **`✅ Parse Live Query connected`** = **App ist erfolgreich mit Parse Server verbunden!** 🎉
- **`⚠️ Failed to connect`** = Verbindung fehlgeschlagen, siehe Fehlermeldung

---

## 🔍 Methode 2: Parse Server Logs überwachen

### Während die App läuft:

**In einem Terminal-Fenster:**

```bash
# Parse Server Logs in Echtzeit anzeigen
ssh io@192.168.178.24 "cd ~/fin1-server && docker compose -f docker-compose.production.yml logs -f parse-server"
```

**Dann in der App eine Aktion ausführen** (z.B. Login versuchen, Daten laden)

### Was du sehen solltest:

**✅ App ist verbunden, wenn du siehst:**
```
::ffff:192.168.178.25 - - [24/Jan/2026:20:00:00 +0000] "POST /parse/login HTTP/1.1" 200 123
::ffff:192.168.178.25 - - [24/Jan/2026:20:00:01 +0000] "GET /parse/classes/User HTTP/1.1" 200 456
```

**Erklärung:**
- `::ffff:192.168.178.25` = IP-Adresse des Mac/Simulators
- `POST /parse/login` = Login-Request von der App
- `200` = Erfolgreich
- `GET /parse/classes/User` = Daten werden geladen

**❌ App ist NICHT verbunden, wenn:**
- Keine Requests in den Logs erscheinen
- Oder nur Fehler (401, 403, 500, etc.)

---

## 🔧 Methode 3: Netzwerk-Verbindung prüfen

### Während die App läuft:

**Im Terminal (auf dem Mac):**

```bash
# Aktive Verbindungen zum Parse Server anzeigen
sudo lsof -i -P | grep 192.168.178.24 | grep 1337
```

**Oder:**
```bash
netstat -an | grep 192.168.178.24 | grep 1337
```

### Was du sehen solltest:

**✅ Verbindung vorhanden:**
```
FIN1    12345  ra   23u  IPv4 0x...  TCP 192.168.178.25:54321->192.168.178.24:1337 (ESTABLISHED)
```

**❌ Keine Verbindung:**
- Keine Ausgabe oder keine ESTABLISHED-Verbindung

---

## 🧪 Methode 4: Test-Script verwenden

**Im Terminal (auf dem Mac):**

```bash
cd /Users/ra/app/FIN1
./scripts/test-app-connection.sh
```

Das Script prüft:
- Parse Server Status
- Health-Check
- Letzte Requests
- Netzwerk-Verbindungen

---

## 📱 Methode 5: In der App testen

### App-Funktionalität testen:

1. **Login/Signup versuchen:**
   - Wenn Login funktioniert = **App ist verbunden!** ✅
   - Wenn "Network error" = **Nicht verbunden** ❌

2. **Daten laden:**
   - Wenn Dashboard-Daten erscheinen = **App ist verbunden!** ✅
   - Wenn "Loading..." ewig dauert = **Möglicherweise nicht verbunden** ⚠️

---

## 🎯 Quick-Check (30 Sekunden)

**Die schnellste Methode:**

1. **App starten** (⌘R in Xcode)
2. **Console öffnen** (⌘⇧Y)
3. **Nach `✅ Parse Live Query connected` suchen**

**Wenn du das siehst = App ist verbunden!** ✅

---

## ⚠️ Häufige Probleme

### Problem: Keine Logs in Console

**Lösung:**
- Prüfe ob Console-Filter aktiv ist (oben in Console)
- Prüfe ob "All Output" ausgewählt ist
- Scroll nach oben, Logs erscheinen beim App-Start

### Problem: "Failed to connect Parse Live Query"

**Mögliche Ursachen:**
1. Parse Server läuft nicht
2. Falsche URL konfiguriert
3. Firewall blockiert
4. Netzwerk-Problem

**Lösung:**
```bash
# 1. Parse Server prüfen
curl http://192.168.178.24:1337/parse/health

# 2. URL in App prüfen (sollte sein):
# http://192.168.178.24:1337/parse

# 3. Netzwerk testen
ping 192.168.178.24
```

### Problem: Parse Server zeigt keine Requests

**Lösung:**
1. Prüfe ob App wirklich läuft
2. Prüfe ob App versucht, sich zu verbinden (Console-Logs)
3. Prüfe Parse Server URL in `ConfigurationService.swift`

---

## 📝 Checkliste

- [ ] App im Simulator gestartet
- [ ] Console geöffnet (⌘⇧Y)
- [ ] Nach `✅ Parse Live Query connected` gesucht
- [ ] Parse Server Logs geöffnet (optional)
- [ ] App-Funktionalität getestet (Login/Signup)

---

## 🎉 Erfolg!

**Wenn du `✅ Parse Live Query connected` in der Console siehst, ist die App erfolgreich mit dem Parse Server verbunden!**

Die App kann jetzt:
- ✅ Daten vom Server laden
- ✅ Daten zum Server senden
- ✅ Live Updates empfangen (Live Query)
- ✅ Authentifizierung durchführen
