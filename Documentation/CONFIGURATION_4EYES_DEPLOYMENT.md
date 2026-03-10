# Configuration 4-Eyes Deployment Guide

## Übersicht

Dieses Dokument beschreibt das Deployment der neuen 4-Augen-Konfigurationsverwaltung.

## Neue Dateien

### Backend (Parse Server)

| Datei | Beschreibung |
|-------|-------------|
| `cloud/utils/configHelper.js` | Zentrale Konfigurationsverwaltung mit Caching |
| `cloud/functions/configuration.js` | 4-Augen Cloud Functions |

### Geänderte Backend-Dateien

| Datei | Änderung |
|-------|----------|
| `cloud/main.js` | Import der neuen configuration.js |
| `cloud/triggers/trade.js` | Liest Commission Rate aus Configuration |
| `cloud/utils/permissions.js` | Neue Berechtigungen für business_admin und compliance |

### App (Swift)

| Datei | Beschreibung |
|-------|-------------|
| `Admin/ViewModels/PendingConfigurationChangesViewModel.swift` | ViewModel für 4-Augen UI |
| `Admin/Views/PendingConfigurationChangesView.swift` | View für Genehmigungen |

### Geänderte App-Dateien

| Datei | Änderung |
|-------|----------|
| `ConfigurationService.swift` | Neue Response-Modelle |
| `ConfigurationService+Updates.swift` | 4-Augen für kritische Parameter |
| `ConfigurationServiceProtocol.swift` | Neue Error-Cases |
| `ConfigurationInputSections.swift` | PendingApprovalsSection |
| `ConfigurationManagementView.swift` | Integration der PendingApprovalsSection |

---

## Deployment-Schritte

### 1. SSH-Tunnel prüfen

```bash
# Prüfe ob SSH-Tunnel offen ist
ssh -O check ra@192.168.178.24 2>/dev/null && echo "✅ Tunnel OK" || echo "❌ Tunnel nicht offen"
```

### 2. Backend deployen

```bash
cd /Users/ra/app/FIN1

# Option A: Mit Deploy-Script
./scripts/deploy-to-ubuntu.sh 192.168.178.24 ra

# Option B: Manuell nur Cloud Code
scp -r backend/parse-server/cloud ra@192.168.178.24:~/fin1-server/parse-server/
```

### 3. Parse Server neu starten

```bash
# SSH auf Server
ssh ra@192.168.178.24

# In das Verzeichnis wechseln
cd ~/fin1-server

# Parse Server neu starten
docker-compose restart parse-server

# Logs prüfen
docker-compose logs -f parse-server --tail=50
```

### 4. Health Check

```bash
# Auf dem Server oder lokal (mit SSH-Tunnel)
curl -k https://192.168.178.24/parse/functions/health \
  -H "X-Parse-Application-Id: fin1-app-id" \
  -H "Content-Type: application/json" \
  -d '{}'
```

Erwartete Antwort:
```json
{"result":{"status":"healthy","timestamp":"...","version":"1.0.0","cloudCode":true}}
```

### 5. Neue Cloud Functions testen

```bash
# Configuration abrufen (als Admin mit Session-Token)
curl -k https://192.168.178.24/parse/functions/getConfiguration \
  -H "X-Parse-Application-Id: fin1-app-id" \
  -H "X-Parse-Session-Token: <ADMIN_SESSION_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{}'
```

---

## Initiale Configuration anlegen

Falls noch keine Configuration-Klasse existiert:

```bash
# Parse Dashboard öffnen (via SSH-Tunnel)
open http://localhost:4040/dashboard

# Oder manuell über API:
curl -k https://192.168.178.24/parse/classes/Configuration \
  -H "X-Parse-Application-Id: fin1-app-id" \
  -H "X-Parse-Master-Key: <MASTER_KEY>" \
  -H "Content-Type: application/json" \
  -d '{
    "isActive": true,
    "traderCommissionRate": 0.10,
    "platformServiceChargeRate": 0.02,
    "minimumCashReserve": 20.0,
    "initialAccountBalance": 1.0
  }'
```

---

## Kritische Parameter

Die folgenden Parameter erfordern 4-Augen-Genehmigung:

| Parameter | Beschreibung | Standardwert |
|-----------|-------------|--------------|
| `traderCommissionRate` | Trader Commission | 10% |
| `platformServiceChargeRate` | Service Charge | 2% |
| `initialAccountBalance` | Startguthaben | €1,00 |
| `orderFeeRate` | Ordergebühr Rate | 0.5% |
| `orderFeeMin` | Ordergebühr Min | €5.00 |
| `orderFeeMax` | Ordergebühr Max | €50.00 |

---

## Workflow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  1. Admin A ändert Parameter in der App                                     │
│       ↓                                                                     │
│  2. App ruft requestConfigurationChange auf                                 │
│       ↓                                                                     │
│  3. Backend erstellt FourEyesRequest (Status: pending)                      │
│       ↓                                                                     │
│  4. Admin B öffnet Approvals-Seite (/approvals), Tab „Freigaben erteilen“    │
│       ↓                                                                     │
│  5. Admin B genehmigt oder lehnt ab                                         │
│       ↓                                                                     │
│  6. Bei Genehmigung: Backend aktualisiert Configuration                     │
│       ↓                                                                     │
│  7. Alle Services (inkl. trade.js) verwenden neuen Wert                     │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Troubleshooting

### "Configuration service not available"

→ ConfigurationService wurde nicht korrekt injiziert. Prüfe `appServices`.

### "No backend connection available"

→ Parse API Client nicht konfiguriert oder kein Netzwerk.

### "Cannot approve own request"

→ 4-Augen-Prinzip: Ein anderer Admin muss genehmigen.

### Eigenen Antrag zurückziehen

→ Antragsteller kann unter Approvals (Tab „Eigene Anträge“ oder „Alle Anträge“) einen eigenen pending Antrag per „Zurückziehen“ widerrufen (`withdrawRequest`).

### Commission Rate wird nicht aktualisiert

→ Cache invalidieren: Parse Server neu starten oder 5 Minuten warten.

---

## Audit-Trail

Alle Konfigurationsänderungen werden im `AuditLog` protokolliert:

- `configuration_change_requested` - Änderung beantragt
- `configuration_changed` - Änderung angewendet
- `configuration_change_approved` - Änderung genehmigt
- `configuration_change_rejected` - Änderung abgelehnt

Query für Audit-Trail:
```bash
curl -k https://192.168.178.24/parse/classes/AuditLog \
  -H "X-Parse-Application-Id: fin1-app-id" \
  -H "X-Parse-Master-Key: <MASTER_KEY>" \
  -G --data-urlencode 'where={"resourceType":"Configuration"}' \
  --data-urlencode 'order=-createdAt' \
  --data-urlencode 'limit=20'
```
