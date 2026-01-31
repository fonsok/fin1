# Price-Alerts Backend Integration

**Datum**: Januar 2026  
**Status**: Parse API Integration vervollständigt ✅

---

## ✅ Abgeschlossen

### 1. ParseAPIClient erweitert ✅

**Datei**: `FIN1/Shared/Services/ParseAPIClient.swift`

**Neue Methode:**
- `deleteObject(className:objectId:)` - Löscht Objekte aus Parse Server

**Bestehende Methoden:**
- `createObject()` - Erstellt neue Objekte
- `updateObject()` - Aktualisiert bestehende Objekte
- `fetchObjects()` - Lädt Objekte mit Query
- `fetchObject()` - Lädt einzelnes Objekt

### 2. PriceAlertService Parse API Integration ✅

**Datei**: `FIN1/Shared/Services/PriceAlertService.swift`

**Implementierte API Calls:**

#### createAlert()
- ✅ Erstellt Price Alert in Parse Server via `createObject()`
- ✅ Speichert `objectId` aus Response
- ✅ Fallback zu lokalem Cache bei Fehler

#### updateAlert()
- ✅ Aktualisiert Price Alert in Parse Server via `updateObject()`
- ✅ Aktualisiert lokalen Cache

#### deleteAlert()
- ✅ Löscht Price Alert aus Parse Server via `deleteObject()`
- ✅ Entfernt aus lokalem Cache

#### loadAlerts()
- ✅ Lädt Price Alerts von Parse Server via `fetchObjects()`
- ✅ Query: `{"userId": userId}`
- ✅ Sortierung: `-createdAt` (neueste zuerst)
- ✅ Limit: 100 Alerts

#### triggerAlert() / expireAlert()
- ✅ Aktualisiert getriggerte/expired Alerts in Parse Server
- ✅ Status wird auf `triggered` oder `expired` gesetzt

---

## 🔧 Backend-Integration

### Parse Server Konfiguration

**Datei**: `backend/parse-server/index.js`

**PriceAlert Schema:**
```javascript
PriceAlert: {
  userId: String (required),
  symbol: String (required),
  alertType: String (required), // "above", "below", "change"
  thresholdPrice: Number,
  thresholdChangePercent: Number,
  status: String (required, default: "active"),
  createdAt: Date (required),
  triggeredAt: Date,
  expiresAt: Date,
  notificationSent: Boolean (default: false),
  isEnabled: Boolean (default: true),
  notes: String
}
```

**Live Query:**
- `PriceAlert` ist in `liveQuery.classNames` enthalten
- Echtzeit-Updates für Price Alerts aktiviert

### MongoDB Integration

- Parse Server verwendet MongoDB als Datenbank
- Price Alerts werden in MongoDB gespeichert
- Live Query ermöglicht Echtzeit-Updates

### fin1-server Integration

**Verfügbare Services:**
- **Parse Server** (Port 1337) - Haupt-API
- **MongoDB** (Port 27017) - Datenbank
- **PostgreSQL** (Port 5432) - Analytics (optional)
- **Market Data Service** (Port 8080) - Real-time Market Data
- **Redis** (Port 6379) - Caching

**Verbindung:**
- Parse Server URL: `http://fin1-server:1337/parse` (oder localhost)
- Live Query URL: `ws://fin1-server:1337/parse` (oder localhost)

---

## 📋 API-Endpunkte

### Price Alert Endpunkte

#### POST /parse/classes/PriceAlert
**Erstellt neuen Price Alert**
```json
{
  "userId": "user123",
  "symbol": "DAX",
  "alertType": "above",
  "thresholdPrice": 15000.0,
  "status": "active",
  "isEnabled": true
}
```

#### GET /parse/classes/PriceAlert?where={"userId":"user123"}
**Lädt Price Alerts für Benutzer**

#### PUT /parse/classes/PriceAlert/{objectId}
**Aktualisiert Price Alert**

#### DELETE /parse/classes/PriceAlert/{objectId}
**Löscht Price Alert**

---

## 🔄 Datenfluss

### Price Alert Lifecycle

1. **Create Alert**
   - User erstellt Alert in App
   - `PriceAlertService.createAlert()` wird aufgerufen
   - Alert wird in Parse Server gespeichert
   - `objectId` wird zurückgegeben
   - Alert wird zu lokalem Cache hinzugefügt

2. **Load Alerts**
   - App startet oder View erscheint
   - `PriceAlertService.loadAlerts()` wird aufgerufen
   - Alerts werden von Parse Server geladen
   - Lokaler Cache wird aktualisiert
   - Live Query Subscription wird eingerichtet

3. **Alert Trigger**
   - Market Data Update wird empfangen
   - `PriceAlertService.checkAlerts()` prüft Bedingungen
   - Wenn Bedingung erfüllt: `triggerAlert()` wird aufgerufen
   - Alert wird in Parse Server aktualisiert (status: "triggered")
   - Notification wird gepostet

4. **Update/Delete Alert**
   - User ändert oder löscht Alert
   - Parse Server wird aktualisiert/gelöscht
   - Lokaler Cache wird synchronisiert

---

## ✅ Build-Status

- **BUILD SUCCEEDED** ✅
- Keine Compile-Fehler
- Parse API Integration vollständig implementiert

---

## 🎯 Abgedeckte Features

### Parse API Integration
- ✅ Create Price Alert
- ✅ Load Price Alerts
- ✅ Update Price Alert
- ✅ Delete Price Alert
- ✅ Trigger Alert (Update Status)
- ✅ Expire Alert (Update Status)

### Error Handling
- ✅ Fallback zu lokalem Cache bei API-Fehlern
- ✅ Error Logging für Debugging
- ✅ Graceful Degradation

---

## 📋 Nächste Schritte (Optional)

1. **Market Data Service Backend Integration**
   - Market Data Service mit fin1-server verbinden
   - Market Data Updates in Parse Server speichern

2. **Push Notifications**
   - Integration mit Notification Service
   - Push-Notifications bei getriggerten Alerts

3. **Analytics**
   - Price Alert Analytics in PostgreSQL
   - Trigger-Statistiken

---

Die Price-Alerts Backend Integration ist vollständig implementiert! 🚀

Die App kann jetzt:
- Price Alerts in Parse Server (MongoDB) speichern
- Alerts von Parse Server laden
- Alerts aktualisieren und löschen
- Echtzeit-Updates via Live Query empfangen

Die Integration mit dem fin1-server ist bereit!
