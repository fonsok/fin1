# 🔧 Backend-Anpassungen für fin1-server - Erforderlich

**Datum:** 2026-02-05
**Status:** ⚠️ **Anpassungen erforderlich**

---

## ⚠️ Kritische Inkonsistenz gefunden

### Problem: SupportTicket Klassen-Name Mismatch

**Aktuelle Situation:**
- ✅ **Triggers** (`triggers/support.js`): Nutzen `SupportTicket` ✅
- ✅ **MongoDB Init**: Nutzt `SupportTicket` ✅
- ❌ **Cloud Functions** (`functions/support.js`): Nutzen `Ticket` ❌
- ✅ **App**: Nutzt `SupportTicket` ✅

**Problem:** Cloud Functions können keine Tickets finden, da sie nach `Ticket` suchen, aber die Klasse heißt `SupportTicket`!

---

## 🔧 Erforderliche Backend-Anpassungen

### 1. Cloud Functions: Ticket → SupportTicket (KRITISCH)

**Datei:** `backend/parse-server/cloud/functions/support.js`

**Änderungen erforderlich:**

#### 1.1 `getTickets` Cloud Function
```javascript
// ❌ AKTUELL (Zeile 22):
const Ticket = Parse.Object.extend('Ticket');

// ✅ SOLLTE SEIN:
const Ticket = Parse.Object.extend('SupportTicket');
```

**Betroffene Zeilen:**
- Zeile 22: `const Ticket = Parse.Object.extend('Ticket');`
- Zeile 99: `const Ticket = Parse.Object.extend('Ticket');`
- Zeile 129: `const Ticket = Parse.Object.extend('Ticket');`
- Zeile 167: `const Ticket = Parse.Object.extend('Ticket');`

#### 1.2 `getTicket` Cloud Function
```javascript
// ❌ AKTUELL (Zeile 99):
const Ticket = Parse.Object.extend('Ticket');

// ✅ SOLLTE SEIN:
const Ticket = Parse.Object.extend('SupportTicket');
```

#### 1.3 `updateTicket` Cloud Function
```javascript
// ❌ AKTUELL (Zeile 129):
const Ticket = Parse.Object.extend('Ticket');

// ✅ SOLLTE SEIN:
const Ticket = Parse.Object.extend('SupportTicket');
```

#### 1.4 `replyToTicket` Cloud Function
```javascript
// ❌ AKTUELL (Zeile 167):
const Ticket = Parse.Object.extend('Ticket');

// ✅ SOLLTE SEIN:
const Ticket = Parse.Object.extend('SupportTicket');
```

**TicketMessage:** Bleibt `TicketMessage` (ist korrekt)

---

### 2. Invoice: Prüfung erforderlich (Optional)

**Datei:** `backend/parse-server/cloud/functions/reports.js`

**Aktuelle Situation:**
- ✅ `Invoice` Parse-Klasse existiert
- ✅ `getInvoices` Cloud Function existiert
- ✅ `createServiceChargeInvoice` Cloud Function existiert
- ✅ App nutzt direkte Parse-Klasse für CRUD

**Mögliches Problem:**
- `getInvoices` nutzt `userId` Parameter
- App sendet `customerId` (aus `CustomerInfo`)
- **Prüfung erforderlich:** Funktioniert das Mapping?

**Empfehlung:**
- Testen ob `getInvoices` mit `userId` funktioniert
- Falls nicht: Cloud Function erweitern um `customerId` Support

---

## 📋 Implementierungs-Checkliste für Backend

### Sofort erforderlich (kritisch):

- [ ] **support.js Zeile 22:** `Ticket` → `SupportTicket`
- [ ] **support.js Zeile 99:** `Ticket` → `SupportTicket`
- [ ] **support.js Zeile 129:** `Ticket` → `SupportTicket`
- [ ] **support.js Zeile 167:** `Ticket` → `SupportTicket`

### Optional (Testing):

- [ ] **Invoice getInvoices:** Prüfen ob `userId`/`customerId` Mapping funktioniert
- [ ] **Invoice CRUD:** Testen ob direkte Parse-Klasse-Erstellung funktioniert

---

## 🚀 Deployment-Schritte

### 1. Backend-Dateien ändern

**Auf dem Server (via SSH):**
```bash
# SSH Tunnel öffnen (bereits vorhanden)
ssh -L 443:127.0.0.1:443 io@192.168.178.24

# Auf dem Server:
cd ~/fin1-server/backend/parse-server/cloud/functions
nano support.js
# Ändere alle 'Ticket' zu 'SupportTicket' (4 Stellen)
```

### 2. Parse Server neu starten

```bash
# Auf dem Server:
cd ~/fin1-server
docker compose -f docker-compose.production.yml restart parse-server
```

### 3. Verifikation

```bash
# Vom Mac aus (via SSH Tunnel):
curl -k -X POST https://localhost/parse/functions/getTickets \
  -H "X-Parse-Application-Id: fin1-app-id" \
  -H "Content-Type: application/json" \
  -d '{}'
```

**Erwartetes Ergebnis:** Liste von Tickets (oder leere Liste), **kein Fehler**

---

## 🔍 Detaillierte Änderungen

### Datei: `backend/parse-server/cloud/functions/support.js`

**Zeile 22 (getTickets):**
```javascript
// ❌ VORHER:
const Ticket = Parse.Object.extend('Ticket');

// ✅ NACHHER:
const Ticket = Parse.Object.extend('SupportTicket');
```

**Zeile 99 (getTicket):**
```javascript
// ❌ VORHER:
const Ticket = Parse.Object.extend('Ticket');

// ✅ NACHHER:
const Ticket = Parse.Object.extend('SupportTicket');
```

**Zeile 129 (updateTicket):**
```javascript
// ❌ VORHER:
const Ticket = Parse.Object.extend('Ticket');

// ✅ NACHHER:
const Ticket = Parse.Object.extend('SupportTicket');
```

**Zeile 167 (replyToTicket):**
```javascript
// ❌ VORHER:
const Ticket = Parse.Object.extend('Ticket');

// ✅ NACHHER:
const Ticket = Parse.Object.extend('SupportTicket');
```

**TicketMessage bleibt unverändert:**
```javascript
// ✅ KORREKT (bleibt so):
const Message = Parse.Object.extend('TicketMessage');
```

---

## 📝 Warum diese Änderung kritisch ist

**Ohne Änderung:**
- ❌ `getTickets` Cloud Function findet keine Tickets
- ❌ `getTicket` Cloud Function findet kein Ticket
- ❌ `updateTicket` Cloud Function kann Ticket nicht aktualisieren
- ❌ `replyToTicket` Cloud Function kann Ticket nicht finden
- ❌ **App kann keine Tickets vom Backend laden**

**Mit Änderung:**
- ✅ Alle Cloud Functions funktionieren korrekt
- ✅ App kann Tickets laden und synchronisieren
- ✅ Konsistenz zwischen Triggers und Functions

---

## 🧪 Testing nach Änderung

### 1. Cloud Function Test
```bash
# Vom Mac (via SSH Tunnel):
curl -k -X POST https://localhost/parse/functions/getTickets \
  -H "X-Parse-Application-Id: fin1-app-id" \
  -H "X-Parse-Session-Token: <session-token>" \
  -H "Content-Type: application/json" \
  -d '{"limit": 10}'
```

**Erwartetes Ergebnis:** `{"tickets": [...], "total": X}`

### 2. App-Test
- App starten
- Customer Support öffnen
- Tickets sollten vom Backend geladen werden (nicht nur Mock-Daten)

---

## 📚 Referenzen

- **Backend Cloud Functions:** `backend/parse-server/cloud/functions/support.js`
- **Backend Triggers:** `backend/parse-server/cloud/triggers/support.js`
- **MongoDB Init:** `backend/mongodb/init/00_init_admin.js` (Zeile 113: `SupportTicket`)

---

## ⚠️ WICHTIG

**Diese Änderung ist KRITISCH für die Customer Support Backend-Integration!**

Ohne diese Änderung funktionieren die Cloud Functions nicht, da sie nach der falschen Klasse suchen.

**Empfehlung:** Änderung sofort auf dem Server durchführen, dann Parse Server neu starten.

---

**Status:** ⚠️ **Backend-Anpassung erforderlich vor Testing**
