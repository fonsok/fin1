# Parse Cloud Naming Convention Matrix

Geltungsbereich: `backend/parse-server/cloud/**`

## Matrix

| Ebene | Regel | Gut | Schlecht |
|---|---|---|---|
| Ordner | domain-orientiert, klein, ohne Temp-Namen | `functions/admin/reports/` | `functions/tmp/` |
| Dateiname | `lowerCamelCase.js|ts` | `appLedger.js` | `app_ledger.js`, `AppLedger.js` |
| Trigger-Datei | singularer Domainname | `trade.js` | `trades.js` |
| Cloud Function Name | `lowerCamelCase` + Verbprefix | `getTradeHistory` | `tradeHistory`, `GetTradeHistory` |
| Orchestrator-Funktion | Verb + Domain + Intent | `settleAndDistribute` | `doSettlementStuff` |
| Query-Funktion | `get*`/`list*` | `getHoldings` | `fetchHoldingsDataNow` |
| Command-Funktion | zustandsaenderndes Verb | `recordPoolTradeParticipation` | `poolTradeParticipation` |
| Schema-/Setup-Command | `initialize*` — einmaliges oder admin-gesteuertes Anlegen von Klassen/Feldern | `initializeNewSchemas` | `newSchemas`, `schemasInit` |
| Mess-/Last-Command | `benchmark*` — reproduzierbare Laufzeit-/Konsistenz-Messung (Admin/Ops) | `benchmarkTradeSettlementConsistency` | `tradeSettlementBenchmark` |
| Helper-Funktionen | intentbasiert (`compute/build/resolve/find`) | `computeTradingFees` | `helper1` |
| Admin-Kontext | ueber Pfad ausdruecken | `functions/admin/financial.js` | `functions/financialAdminStuff.js` |
| Legacy/Temp | im produktiven Pfad verboten | `trade.js` | `trade.js.tmp`, `backupTrade.js` |

## Verb-Katalog fuer `Parse.Cloud.define(...)`

Die Prüfung erlaubt nur Namen, die mit einem der **genehmigten Präfix-Verben** beginnen (siehe Tabelle unten und `verb_prefixes` in `scripts/check-parse-cloud-naming-conventions.sh`). Neuere Ergänzungen mit fester Bedeutung:

| Präfix | Rolle | Typische Nutzung | Beispiele im Repo |
|--------|--------|------------------|-------------------|
| `initialize` | Zustand/Struktur **herstellen** (Klassen, Default-Schema, initiale Datenpfade) | Admin- oder Dev-Hilfen nach Deploy, nicht für jeden User-Request | `initializeNewSchemas` |
| `benchmark` | **Messen** (Dauer, Durchsatz, Drift) ohne fachlichen Zustandswechsel der Domäne | Ops- und Admin-Diagnose, synthetische Last optional | `benchmarkTradeSettlementConsistency`, `benchmarkTradeSettlementConsistencySynthetic` |

**Alle übrigen genehmigten Präfixe (alphabetisch im Skript):** `get`, `list`, `create`, `update`, `delete`, `upsert`, `confirm`, `cancel`, `activate`, `record`, `book`, `repair`, `backfill`, `reconcile`, `cleanup`, `run`, `calculate`, `execute`, `place`, `discover`, `audit`, `import`, `export`, `reset`, `approve`, `reject`, `withdraw`, `request`, `search`, `send`, `verify`, `enable`, `disable`, `setup`, `mark`, `complete`, `save`, `resolve`, `close`, `assign`, `escalate`, `reply`, `respond`, `seed`, `force`, `unlock`, `terminate`, `migrate`, `check`, `encrypt`, `set`, `log`, `render`, `review`, `regenerate`, sowie **`initialize`** und **`benchmark`** (siehe Tabelle oben).

**Vollständige und autoritative Liste:** immer `verb_prefixes` im Shell-Skript — bei neuem Verb dort und in dieser Doku ergänzen.

**Legacy-Ausnahmen** (bewusst ohne Katalog-Präfix, z. B. Kompatibilität oder Dev-only): `legacy_cloud_function_allowlist` im gleichen Skript (z. B. `health`, `traderActivateReservedInvestment`, `devReset*`, `testEmailConfig`).

## Design-Prinzipien

- Ein Name beschreibt genau **einen** fachlichen Zweck.
- Commands und Queries werden im Namen klar getrennt.
- Keine doppelte Domain-Logik in mehreren gleich benannten Modulen.
- Keine technischen Platzhalter in produktiven Namen.

## Automatische Pruefung

- Lokal (geänderte Cloud-Dateien): `./scripts/check-parse-cloud-naming-conventions.sh`
- Vollscan (alle vorhandenen Cloud-Dateien auf der Platte): `./scripts/check-parse-cloud-naming-conventions.sh --all`  
  (nutzt Dateisystem-Enumeration, nicht `git ls-files`, damit kein Index mit gelöschten Pfaden den Lauf bricht.)
- CI: `.github/workflows/ci.yml` (Job `parse-smoke-local-mock`: Naming-Check + `scripts/ci-smoke-local-mock.sh`)

Der Check validiert Dateinamen, Cloud-Function-Namen und Legacy-/Temp-Pfade. Ausnahmen (z. B. Legacy-Funktionsnamen, erlaubte „backup“-Fragmente im Dateinamen) sind in `scripts/check-parse-cloud-naming-conventions.sh` als Allowlists hinterlegt.

HTTP-Vertrags-Smoke (nur Loopback, ohne DB): `./scripts/ci-smoke-local-mock.sh` — prüft die JSON-Form von `GET /health` und `POST /parse/functions/getConfig` an einem minimalen Mock-Server.
