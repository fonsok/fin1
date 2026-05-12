# Database Schema

## Overview

Dieses Verzeichnis enthält das vollständige Datenbankschema für die Plattform.
Das Schema ist normalisiert (3NF) und für die Migration nach MongoDB dokumentiert.

## Schema Statistics

| Bereich | Tabellen | Beschreibung |
|---------|----------|--------------|
| Configuration | 5 | Zentrale Konfiguration, Environments |
| System | 4 | App-Versionen, Announcements |
| Users | 17 | User Management, KYC, Risk Assessment |
| Notifications | 4 | In-App, Push, Email |
| Trading | 11 | Securities, Orders, Trades, Holdings |
| Investments | 7 | Investments, Commissions, Pools |
| Finance | 9 | Invoices, Konto (Wallet deaktiviert), Documents |
| FAQ | 4 | FAQs, Feedback, Views |
| CSR | 12 | Support Tickets, Agents, 4-Eyes |
| Compliance | 8 | Audit Logs, GDPR, KYC Changes |
| Admin | 3 | Bank Reconciliation, Impersonation |
| **Total** | **84** | |

## Files

```
001_schema_config.sql      - Configuration Management
002_schema_system.sql      - App & System
003_schema_users.sql       - User Management (17 tables)
004_schema_notifications.sql - Notifications
005_schema_trading.sql     - Trading System
006_schema_investments.sql - Investment System
007_schema_finance.sql     - Finance & Documents
008_schema_faq.sql         - FAQ & Help
009_schema_csr.sql         - Customer Support
010_schema_compliance.sql  - Compliance & Audit
011_schema_admin.sql       - Admin Features
012_indexes.sql            - Additional Indexes
013_views.sql              - Consolidated Views
014_triggers.sql           - Audit Triggers
015_functions.sql          - Stored Procedures
016_seed_data.sql          - Initial Data
```

## Usage

### PostgreSQL (Direct)

```bash
# Via psql
psql -U postgres -d fin1 -f 001_schema_config.sql
psql -U postgres -d fin1 -f 002_schema_system.sql
# ... etc

# Oder alle auf einmal:
for f in /path/to/init/*.sql; do psql -U postgres -d fin1 -f "$f"; done
```

### Docker

Die Dateien werden automatisch geladen wenn sie in `/docker-entrypoint-initdb.d/` gemountet werden:

```yaml
# docker-compose.yml
services:
  postgres:
    image: postgres:16
    volumes:
      - ./postgres/init:/docker-entrypoint-initdb.d:ro
```

### Development Seed Data

Für Testdaten setze die Variable vor dem Seed:

```sql
SET app.seed_dev_data = 'true';
\i 016_seed_data.sql
```

## Migration zu MongoDB

Siehe `MONGODB_MIGRATION.md` für die Collection-Struktur und Migration.

### Grundprinzipien

| PostgreSQL | MongoDB |
|------------|---------|
| Table | Collection |
| Row | Document |
| Foreign Key | Embedded Document oder Reference |
| JOIN | $lookup oder Denormalization |
| Index | Index (ähnlich) |
| Transaction | Multi-Document Transaction |

### Empfohlene Collection-Struktur

```javascript
// Embedded (1:1 oder 1:few)
users: {
  _id, customer_id, email, role, status,
  profile: { first_name, last_name, ... },
  addresses: [...],
  security_settings: {...},
  preferences: {...}
}

// Referenced (1:many)
investments: {
  _id, investor_id: ObjectId, trader_id: ObjectId, ...
}

trades: {
  _id, trader_id: ObjectId, buy_order_id: ObjectId, ...
}
```

## Compliance Notes

- **10-Jahre Aufbewahrung**: audit_logs, compliance_events, *_audit_log Tabellen
- **GDPR**: data_access_logs, gdpr_requests, anonymize_user_data()
- **BaFin/GwG**: compliance_events mit regulatory_flags
- **MiFID II**: risk_assessments, investment_experience

## ER Diagram (Simplified)

```
┌─────────┐      ┌─────────────┐      ┌──────────┐
│  users  │──────│ investments │──────│  trades  │
└────┬────┘      └─────────────┘      └────┬─────┘
     │                                      │
     │           ┌──────────────┐          │
     └───────────│    orders    │──────────┘
                 └──────────────┘
                        │
                 ┌──────────────┐
                 │   invoices   │
                 └──────────────┘
```

## Support

Bei Fragen zum Schema kontaktiere das Backend-Team.
