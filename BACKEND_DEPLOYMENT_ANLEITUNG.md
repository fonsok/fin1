# 🚀 Backend-Deployment Anleitung - fin1-server

**Datum:** 2026-02-05
**Zweck:** Anleitung für Backend-Anpassungen auf dem fin1-server

---

## ⚠️ KRITISCH: SupportTicket Klassen-Name Fix

### Problem
Cloud Functions nutzen `Ticket`, aber die Parse-Klasse heißt `SupportTicket`.

### Lösung
**Datei geändert:** `backend/parse-server/cloud/functions/support.js`

**4 Stellen geändert:**
- ✅ Zeile 22: `Ticket` → `SupportTicket`
- ✅ Zeile 99: `Ticket` → `SupportTicket`
- ✅ Zeile 129: `Ticket` → `SupportTicket`
- ✅ Zeile 167: `Ticket` → `SupportTicket`

**Status:** ✅ **Datei bereits im Repo geändert**

---

## 📋 Deployment-Schritte

### Schritt 1: Dateien auf Server kopieren

**Option A: Git Pull (empfohlen)**
```bash
# Auf dem Server (via SSH):
ssh io@192.168.178.24
cd ~/fin1-server
git pull origin main  # oder dein Branch-Name
```

**Option B: Manuell kopieren**
```bash
# Vom Mac aus:
scp backend/parse-server/cloud/functions/support.js io@192.168.178.24:~/fin1-server/backend/parse-server/cloud/functions/support.js
```

### Schritt 2: Parse Server neu starten

```bash
# Auf dem Server:
cd ~/fin1-server
docker compose -f docker-compose.production.yml restart parse-server
```

### Schritt 3: Verifikation

**Vom Mac aus (via SSH Tunnel):**
```bash
# SSH Tunnel öffnen (falls nicht bereits offen):
ssh -L 443:127.0.0.1:443 io@192.168.178.24
# Dann: https://localhost/parse/... (bei self-signed: curl -k)

# In neuem Terminal (vom Mac):
curl -k -X POST https://localhost/parse/functions/getTickets \
  -H "X-Parse-Application-Id: fin1-app-id" \
  -H "Content-Type: application/json" \
  -d '{"limit": 1}'
```

**Erwartetes Ergebnis:**
- ✅ `{"tickets": [...], "total": X}` (auch wenn leer)
- ❌ **NICHT:** `{"code": 101, "error": "Object not found"}`

---

## ✅ Was bereits funktioniert (keine Änderung nötig)

### Invoice Backend
- ✅ `Invoice` Parse-Klasse existiert
- ✅ `getInvoices` Cloud Function existiert (nutzt `userId`)
- ✅ `createServiceChargeInvoice` Cloud Function existiert
- ✅ App nutzt direkte Parse-Klasse für CRUD (funktioniert)

**Hinweis:** `getInvoices` nutzt `user.id` aus Session Token, nicht `customerId` Parameter. Das ist korrekt, da die App mit authentifiziertem User arbeitet.

### SupportTicket Backend (nach Fix)
- ✅ `SupportTicket` Parse-Klasse existiert
- ✅ `getTickets` Cloud Function (nach Fix)
- ✅ `getTicket` Cloud Function (nach Fix)
- ✅ `updateTicket` Cloud Function (nach Fix)
- ✅ `replyToTicket` Cloud Function (nach Fix)
- ✅ Triggers existieren (`beforeSave`, `afterSave`)

---

## 🔍 Weitere Prüfungen (Optional)

### 1. Invoice Schema Mapping

**Frage:** Funktioniert `getInvoices` mit der App-Integration?

**Test:**
```bash
# Vom Mac (mit Session Token):
curl -k -X POST https://localhost/parse/functions/getInvoices \
  -H "X-Parse-Application-Id: fin1-app-id" \
  -H "X-Parse-Session-Token: <session-token>" \
  -H "Content-Type: application/json" \
  -d '{"limit": 10}'
```

**Erwartung:** Liste von Invoices für den User

### 2. SupportTicket Schema Mapping

**Frage:** Stimmen die Feldnamen zwischen App und Backend überein?

**App sendet:**
- `customerId` (aus `SupportTicketCreate`)
- `subject`
- `description`
- `priority`

**Backend erwartet (aus Trigger):**
- `customerId` ✅
- `subject` ✅
- `description` ✅
- `priority` ✅
- `category` (wird validiert, Default: `general`)

**Mögliches Problem:** App sendet kein `category` Feld!

**Lösung:** App sollte `category: "general"` als Default senden, oder Backend Trigger setzt Default.

**Status:** ✅ Backend Trigger setzt Default (Zeile 46-50 in `triggers/support.js`)

---

## 📝 Zusammenfassung

### ✅ Bereits geändert (im Repo):
- [x] `support.js` - Alle `Ticket` → `SupportTicket` geändert

### ⏭️ Auf Server durchzuführen:
1. [ ] Dateien auf Server kopieren (Git Pull oder SCP)
2. [ ] Parse Server neu starten
3. [ ] Verifikation durchführen

### ✅ Keine weiteren Änderungen nötig:
- Invoice Backend funktioniert bereits
- SupportTicket Triggers sind korrekt
- Schema-Initialisierung ist korrekt

---

## 🎯 Nach Deployment

**Testen:**
1. App starten
2. Customer Support öffnen
3. Tickets sollten vom Backend geladen werden
4. Ticket erstellen → sollte synchronisiert werden

**Bei Problemen:**
- Parse Server Logs prüfen: `docker compose logs parse-server`
- Cloud Function Logs prüfen
- Parse Dashboard öffnen (via SSH Tunnel) → `SupportTicket` Klasse prüfen

---

**Status:** ✅ **Backend-Datei geändert, Deployment erforderlich**
