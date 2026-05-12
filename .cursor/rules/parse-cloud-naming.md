---
filePatterns:
  - "backend/parse-server/cloud/**/*.js"
  - "backend/parse-server/cloud/**/*.ts"
---

# Parse Cloud Naming Conventions

Nutze diese Regeln fuer alle Dateien unter `backend/parse-server/cloud/**`.

## Ziel

- Eindeutige, vorhersagbare Namen fuer Domain-Logik und Endpunkte
- Klare Trennung zwischen Command- und Query-Funktionen
- Keine Legacy-/Temp-Namensreste im produktiven Pfad

## Naming-Matrix

- **Dateien (Functions/Triggers/Utils):** `lowerCamelCase.js|ts` (z. B. `appLedger.js`, `companyKyb.js`, `emailService.js`)
- **Cloud Function Name (`Parse.Cloud.define`)**: `lowerCamelCase`, beginnt mit Verb
- **Trigger-Dateien:** Singularer Domainname (`investment.js`, `trade.js`, `order.js`, `user.js`)
- **Orchestratoren:** Verb + Domain (`settleAndDistribute`, `repairTradeSettlement`)
- **Calculator/Builder/Resolver:** Suffix klar machen (`compute*`, `build*`, `resolve*`, `find*`)
- **Admin-Endpunkte:** admin-Kontext im Pfad (`functions/admin/...`), nicht im Dateinamen doppeln

## Erlaubte Verben fuer Cloud Functions

- `get`, `list`, `create`, `update`, `delete`, `upsert`
- `confirm`, `cancel`, `activate`, `record`, `book`
- `repair`, `backfill`, `reconcile`, `cleanup`, `run`
- `calculate`, `execute`, `place`, `discover`, `audit`
- `import`, `export`, `reset`

## Nicht erlaubt

- Temp-/Legacy-Pfade oder Namen im produktiven Cloud-Pfad (`tmp`, `.tmp`, `backup`, `copy`)
- `snake_case` oder `PascalCase` fuer Dateinamen/Funktionsnamen
- Unscharfe Namen ohne Verb fuer Cloud Functions

## Durchsetzung

- Vor Commit/PR (geänderte Cloud-Dateien): `./scripts/check-parse-cloud-naming-conventions.sh`
- Vollscan bei Bedarf: `./scripts/check-parse-cloud-naming-conventions.sh --all`
- CI: Workflow `ci.yml` fuehrt den Check automatisch aus.
- Detail-Matrix und Beispiele: `Documentation/PARSE_CLOUD_NAMING_CONVENTIONS.md`
