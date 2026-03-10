# Parse Dashboard - Schritt-für-Schritt Anleitung

**Ziel:** ComplianceEvent-Klasse erstellen

---

## 🔗 Schritt 1: Dashboard öffnen

1. Öffne deinen Browser
2. SSH-Tunnel starten: `ssh -L 443:127.0.0.1:443 io@192.168.178.24`, dann im Browser: **`https://localhost/dashboard/`**
3. Du solltest die Parse Dashboard Login-Seite sehen

---

## 🔐 Schritt 2: Login

1. **Username:** `admin`
2. **Password:** `CHANGE-THIS-ADMIN-PASSWORD`
   - (Das Passwort steht in `backend/.env` auf dem Ubuntu-Server)
3. Klicke auf **"Log In"**

---

## 📋 Schritt 3: Schema öffnen

1. Nach dem Login siehst du das Parse Dashboard
2. **Links im Menü:** Klicke auf **"Schema"**
3. Du siehst jetzt eine Liste aller Klassen (User, _Installation, etc.)

---

## ➕ Schritt 4: Neue Klasse erstellen

1. Klicke auf den Button **"+ Create a class"** (oben rechts)
2. Ein Dialog öffnet sich
3. **Class Name eingeben:** `ComplianceEvent`
   - **Wichtig:** Genau so schreiben, mit großem C und großem E
4. Klicke auf **"Create class"**

---

## 📝 Schritt 5: Felder hinzufügen

Nach dem Erstellen der Klasse siehst du die Felder-Übersicht.

**Für jedes Feld:**
1. Klicke auf **"+ Add a new column"**
2. Fülle die Felder aus:
   - **Column name:** (siehe Tabelle unten)
   - **Type:** (siehe Tabelle unten)
   - **Required:** (siehe Tabelle unten)

### Feld 1: userId
- **Column name:** `userId`
- **Type:** `String`
- **Required:** ✅ **Yes** (Häkchen setzen)
- Klicke **"Create column"**

### Feld 2: eventType
- **Column name:** `eventType`
- **Type:** `String`
- **Required:** ✅ **Yes**
- Klicke **"Create column"**

### Feld 3: description
- **Column name:** `description`
- **Type:** `String`
- **Required:** ✅ **Yes**
- Klicke **"Create column"**

### Feld 4: metadata
- **Column name:** `metadata`
- **Type:** `Object`
- **Required:** ❌ **No** (kein Häkchen)
- Klicke **"Create column"**

### Feld 5: timestamp
- **Column name:** `timestamp`
- **Type:** `Date`
- **Required:** ✅ **Yes**
- Klicke **"Create column"**

### Feld 6: regulatoryFlags
- **Column name:** `regulatoryFlags`
- **Type:** `Array`
- **Required:** ❌ **No**
- Klicke **"Create column"**

---

## ✅ Schritt 6: Fertig!

Die ComplianceEvent-Klasse ist jetzt erstellt!

**Automatische Felder (werden von Parse Server hinzugefügt):**
- `objectId` - Eindeutige ID
- `createdAt` - Erstellungszeitpunkt
- `updatedAt` - Letzte Aktualisierung
- `ACL` - Access Control List

Diese musst du **nicht** manuell hinzufügen.

---

## 🧪 Schritt 7: Testen

1. **App neu starten** (falls sie läuft)
2. **Console-Logs prüfen:**
   - Sollte keine 500-Fehler mehr zeigen
   - Compliance Events sollten erfolgreich gespeichert werden

3. **Im Dashboard prüfen:**
   - Links im Menü: **"Data Browser"**
   - Wähle **"ComplianceEvent"** aus
   - Du solltest Objekte sehen, die von der App erstellt wurden

---

## 🎯 Zusammenfassung

**Erstellte Klasse:** `ComplianceEvent`

**Felder:**
- ✅ `userId` (String, required)
- ✅ `eventType` (String, required)
- ✅ `description` (String, required)
- ✅ `metadata` (Object, optional)
- ✅ `timestamp` (Date, required)
- ✅ `regulatoryFlags` (Array, optional)

**Fertig!** 🎉

Die 500-Fehler in der App sollten jetzt verschwinden.

---

## ❓ Hilfe

**Falls das Dashboard nicht funktioniert:**
- Prüfe ob Parse Server läuft: `docker compose ps parse-server`
- Prüfe Logs: `docker compose logs parse-server`
- Prüfe ob Dashboard aktiviert ist: `curl -sk https://192.168.178.24/dashboard` (oder nach Tunnel: `curl -sk https://localhost/dashboard`)

**Falls Login nicht funktioniert:**
- Prüfe Passwort in `backend/.env`: `DASHBOARD_PASSWORD=...`
- Standard-Passwort: `CHANGE-THIS-ADMIN-PASSWORD`
