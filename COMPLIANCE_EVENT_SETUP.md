# ComplianceEvent-Klasse erstellen

**Problem:** 500-Fehler beim Speichern von Compliance Events

**Lösung:** ComplianceEvent-Klasse im Parse Server Schema erstellen

---

## ✅ Option 1: Parse Dashboard (Empfohlen - Einfachste Methode)

### Schritt-für-Schritt:

1. **Parse Dashboard öffnen (per SSH-Tunnel):**
   ```bash
   ssh -L 443:127.0.0.1:443 io@192.168.178.24
   ```
   Dann im Browser: **`https://localhost/dashboard/`** (Zertifikat-Warnung ggf. bestätigen)

2. **Login:**
   - User: `admin` (oder wie in `.env` konfiguriert)
   - Password: `admin123` (oder wie in `.env` konfiguriert)

3. **Schema öffnen:**
   - Links im Menü: **"Schema"** klicken

4. **Neue Klasse erstellen:**
   - Button: **"Create a class"** klicken
   - Class Name: `ComplianceEvent`
   - Klicke: **"Create class"**

5. **Felder hinzufügen:**

   Klicke auf **"Add a new column"** für jedes Feld:

   | Feldname | Typ | Required | Default |
   |----------|-----|----------|---------|
   | `userId` | String | ✅ Yes | - |
   | `eventType` | String | ✅ Yes | - |
   | `description` | String | ✅ Yes | - |
   | `metadata` | Object | ❌ No | - |
   | `timestamp` | Date | ✅ Yes | - |
   | `regulatoryFlags` | Array | ❌ No | - |

6. **Fertig!** ✅

Die Klasse ist jetzt erstellt und die App kann Compliance Events speichern.

---

## ✅ Option 2: Automatisch (Parse Server erstellt Klasse selbst)

Parse Server erstellt Klassen **automatisch**, wenn das erste Objekt gespeichert wird.

**Das bedeutet:**
- Die Klasse wird erstellt, sobald die App das nächste Mal ein Compliance Event speichert
- **Aber:** Der Server muss vollständig initialisiert sein (nicht nur "initialized" Status)

**Warte einfach:**
- Parse Server vollständig starten lassen (1-2 Minuten nach Neustart)
- App erneut starten
- Compliance Event wird automatisch gespeichert und die Klasse wird erstellt

---

## ✅ Option 3: Via MongoDB (Für Experten)

```bash
ssh io@192.168.178.24 "cd ~/fin1-server && docker compose -f docker-compose.production.yml exec mongodb mongosh --quiet --eval 'use fin1; db.createCollection(\"ComplianceEvent\"); print(\"Collection created\")'"
```

**Hinweis:** Parse Server erkennt die Collection, aber das Schema muss trotzdem über Parse Server erstellt werden.

---

## 🧪 Testen

Nachdem die Klasse erstellt wurde:

1. **App neu starten**
2. **Console-Logs prüfen:**
   - Sollte keine 500-Fehler mehr zeigen
   - Compliance Events sollten erfolgreich gespeichert werden

3. **Parse Dashboard prüfen:**
   - Schema → ComplianceEvent
   - Sollte Objekte zeigen, die von der App erstellt wurden

---

## 📝 Felder-Übersicht

Die ComplianceEvent-Klasse benötigt folgende Felder:

- **`userId`** (String, required) - ID des Benutzers
- **`eventType`** (String, required) - Typ des Events (z.B. "riskCheck", "complianceReview")
- **`description`** (String, required) - Beschreibung des Events
- **`metadata`** (Object, optional) - Zusätzliche Metadaten
- **`timestamp`** (Date, required) - Zeitstempel des Events
- **`regulatoryFlags`** (Array, optional) - Regulatorische Flags (z.B. ["mifidII"])

**Automatische Felder (von Parse Server):**
- `objectId` - Eindeutige ID
- `createdAt` - Erstellungszeitpunkt
- `updatedAt` - Letzte Aktualisierung

---

## 🎯 Empfehlung

**Verwende Option 1 (Parse Dashboard)** - Das ist die einfachste und zuverlässigste Methode.

Die Klasse wird in wenigen Minuten erstellt und die 500-Fehler verschwinden sofort.
