# Schema-Migrationen (Parse `SchemaMigration`)

## Zweck

- **Versionierte** Änderungen am Parse-Class-Schema (REST `PUT /schemas/:className`, Master-Key).
- **Audit**: jede erfolgreiche oder fehlgeschlagene Migration erzeugt eine Zeile in der Parse-Klasse **`SchemaMigration`**.
- **Idempotenz**: existiert zu einer `migrationId` bereits eine Zeile mit `success === true`, wird der `apply`-Schritt übersprungen.

## Code-Layout

| Datei | Rolle |
|-------|--------|
| `cloud/utils/schemaMigration/putParseSchemaFields.js` | Low-Level REST-PUT |
| `cloud/utils/schemaMigration/schemaMigrationsRegistry.js` | Geordnete Liste `SCHEMA_MIGRATIONS` (`migrationId`, `title`, `apply`) |
| `cloud/utils/schemaMigration/schemaMigrationRunner.js` | `runPendingSchemaMigrations`, Persistenz, `hasSuccessfulMigration` |

## Neue Felder hinzufügen

1. **Neue** `migrationId` in `schemaMigrationsRegistry.js` anhängen (Reihenfolge = Ausführungsreihenfolge).
2. **Niemals** eine bestehende Migration „umbiegen“ — sonst ist der Audit-Trail nicht mehr zuordenbar.
3. Deploy; beim nächsten Lauf (Startup `main.js`, Lazy-Ensure im `Investment`-`beforeSave`, oder Admin-Cloud `updateInvestmentClassSchemaFields`) wird die Migration ausgeführt.

**Beispiel:** `investment_trader_username_v1` ergänzt `Investment.traderUsername` (String) — Parse `_User.username` zum Zeitpunkt der Reservierung. **`investment_trader_username_backfill_v1`** setzt das Feld auf bestehenden Zeilen aus `traderId` → `_User.username` (idempotent, paginiert). **`gob_investment_pool_trading_amount_v1`** ergänzt `Investment.poolTradingAmount` (Number) — gebuchte Gesamtkaufkosten nach Aktivierung, abgestimmt mit Collection-Bill-`totalBuyCost`. **`gob_user_cash_balance_v1`:** Klasse `UserCashBalance` (`userId`, `currentBalance`) plus Mongo-Unique-Index auf `userId` — SSOT für atomare `$inc`-Buchungen (Phase 3b, `userCashBalanceAtomic.js`). **`investment_number_per_investor_compound_unique_v1`:** ersetzt globalen Unique auf `investmentNumber` durch **`(investorId, investmentNumber)`** `unique + sparse` — erforderlich für `generateInvestorInvestmentNumber` (siehe [`Documentation/ENGINEERING_GUIDE.md`](ENGINEERING_GUIDE.md), Abschnitt *Investment anlegen*).

**Einmalig Ops (falls Migration noch nicht gelaufen):** Legacy-Index `investmentNumber_1` (nur `investmentNumber` unique) auf Produktion prüfen; Skript `backend/mongodb/scripts/fix_unique_number_indexes_sparse_fin1.js` bzw. Compound-Migration aus Registry.

## Admin / Ops

- **`updateInvestmentClassSchemaFields`**: führt `runPendingSchemaMigrations` aus (Admin-Rolle).
- **`listSchemaMigrations`**: letzte Audit-Zeilen (Admin-Rolle, optional `params.limit`).

## Post-Deploy (Routine, ~2 Min.)

1. Nach `parse-server`/Cloud-Deploy: Logs prüfen (`Schema migrations … ok` / `partial`).
2. Admin: `listSchemaMigrations` — für jede aktive `migrationId` aus `schemaMigrationsRegistry.js` mindestens eine Zeile mit `success: true` (oder bewusst offen, wenn Master-Key lokal fehlt).
3. Bei Bedarf: `updateInvestmentClassSchemaFields` einmal auslösen, danach Schritt 2 wiederholen.

## Felder auf `SchemaMigration` (Runtime)

Persistiert vom Runner (kein separates Schema-Deploy nötig — Parse legt die Klasse beim ersten `save` mit Master-Key an):

- `migrationId` (String)
- `title` (String)
- `success` (Boolean)
- `applySkipped` (Boolean) — nur Metadaten; bei fehlendem `PARSE_SERVER_MASTER_KEY` wird **keine** Zeile geschrieben (Migration bleibt „offen“).
- `appliedAt` (Date)
- `durationMs` (Number)
- `applyStatus`, `applyNote`, `applyMessage` (optional)
- `errorMessage` (String, bei Fehler)

## Siehe auch

- `Documentation/BOOKING_AND_BELEG_SSOT.md` — GoB-Beleg-Pipeline inkl. `feeConfigSnapshot`.
