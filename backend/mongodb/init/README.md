# MongoDB Initialization

## Übersicht

Diese Scripts werden beim ersten Start des MongoDB-Containers ausgeführt.
Sie erstellen Datenbank, User, Collections, Indexes und Schema-Validierung.

## Dateien

| Datei | Beschreibung |
|-------|--------------|
| `00_init_admin.js` | Datenbank, User, Collections, Initialdaten |
| `01_indexes.js` | Alle Performance-Indexes |
| `02_schema_validation.js` | Schema-Validierungsregeln |

## Ausführungsreihenfolge

MongoDB führt Scripts in alphabetischer Reihenfolge aus:
1. `00_init_admin.js` - Basis-Setup
2. `01_indexes.js` - Indexes
3. `02_schema_validation.js` - Validierung

## Docker-Integration

Die Scripts werden automatisch ausgeführt wenn sie in `/docker-entrypoint-initdb.d/` gemountet sind:

```yaml
# docker-compose.yml
mongodb:
  volumes:
    - ./backend/mongodb/init:/docker-entrypoint-initdb.d
```

## Manuell ausführen

```bash
# Via mongosh
mongosh mongodb://admin:password@localhost:27017/admin

# Dann:
load("/path/to/00_init_admin.js")
load("/path/to/01_indexes.js")
load("/path/to/02_schema_validation.js")
```

## Erstellte User

| User | Passwort | Rechte | Verwendung |
|------|----------|--------|------------|
| `admin` | aus ENV | root | Administration |
| `fin1_app` | `fin1-app-password` | readWrite, dbAdmin | Parse Server |
| `fin1_analytics` | `fin1-analytics-password` | read | Analytics |

**WICHTIG:** In Production Passwörter über ENV-Variablen setzen!

## Collections

~45 Collections werden erstellt, darunter:

**User Management:**
- UserProfile, UserAddress, UserKYCDocument, UserRiskAssessment, UserConsent, UserDevice

**Business:**
- Investment, Trade, Order, Holding, Commission, WalletTransaction

**Support:**
- SupportTicket, TicketResponse, CSRAgent, FourEyesRequest

**Compliance:**
- ComplianceEvent, AuditLog, DataAccessLog, GDPRRequest

## Schema-Validierung

Validierung ist auf "moderate" und "warn" eingestellt:
- Validiert bei Insert/Update
- Warnt bei Verstößen (lehnt nicht ab)

Für Production auf "error" umstellen:
```javascript
db.runCommand({ collMod: "CollectionName", validationAction: "error" })
```

## TTL Indexes

Automatisches Löschen:
- `MarketData`: Nach 90 Tagen
- `Notification` (gelesen): Nach 90 Tagen

## Troubleshooting

**Scripts werden nicht ausgeführt:**
- Nur beim ERSTEN Container-Start
- Volume löschen: `docker volume rm fin1_mongodb_data`

**Authentifizierungsfehler:**
- Prüfen ob MONGO_INITDB_ROOT_USERNAME/PASSWORD gesetzt
- Connection-String mit authSource: `?authSource=admin`
