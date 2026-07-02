# Admin-Listen-Suche (Summary Report & Co.)

## Ansatz (self-hosted MongoDB, kein Atlas-Pflicht)

Statt Atlas Search nutzt FIN1 **MongoDB Text Indexes** auf dem Feld `adminSearchBlob` (wie bereits `Security.name` / `symbol`).

| Komponente | Rolle |
|----------|--------|
| `adminSearchBlob` | Denormalisiert: Nr., Namen, IDs, Symbol — lowercase, max. 512 Zeichen |
| `beforeSave` Investment/Trade | Blob wird bei jedem Save aktualisiert |
| `$text` in Aggregate (`summaryReportMongoMatch`) | Indexierte Volltextsuche |
| Präfix/Equality | `INV-*` → `investmentNumber`, reine Ziffern → `tradeNumber`, Symbole → `symbol`; im `adminSearchBlob` auch **`YYYY-NNN`** (Trade-Anzeige) |

Schema-Migration: `admin_list_search_v1` (Parse-Feld + Index-Anlage via `PARSE_SERVER_DATABASE_URI`).

## Backfill

```bash
./scripts/backfill-trade-summary-flags.sh
```

Ruft `backfillTradeSummaryFlags` für `trade` und `investment` auf (Flags + `adminSearchBlob`).

## Atlas Search (optional, später)

Bei Umzug auf **MongoDB Atlas** kann ein Atlas Search Index `adminSearchBlob` ergänzt werden; die API-Schicht (`buildAdminListSearchMatchClause`) bleibt, nur die Query-Implementierung wechselt von `$text` zu `$search`.

## Resilienz (Production)

| Mechanismus | Zweck |
|-------------|--------|
| `$text` → **Prefix-Fallback** | Bei fehlendem Text-Index: `adminSearchBlob` Range-Query (`$gte`/`$lt`) |
| **Prefix-B-Tree-Index** | `Investment_adminSearchBlob_prefix`, `Trade_adminSearchBlob_prefix` |
| **maxTimeMS 20s** | Aggregate-Timeout für Summary-Report-Listen |
| **`searchMode` in API** | `none` \| `text` \| `prefix` — Transparenz im Response |
| **`getAdminListSearchHealth`** | Ops-Check: Indexes + Sample-Blobs |
| **`ensureAdminListSearchIndexes`** | Index-Reparatur (Master Key) |

```bash
# Health (Admin-Session oder Dashboard-Permission)
getAdminListSearchHealth

# Reparatur Indexes
ensureAdminListSearchIndexes  # Master Key

# Ops (lokal / Server)
./scripts/check-admin-list-search-health.sh
node scripts/monitor-admin-list-search-health.js   # CI / mit PARSE_* env
```

**Monitoring:** GitHub Actions `admin-list-search-health-monitor.yml` (wöchentlich). Abnahme: `Documentation/RELEASE_ABNAHME_SUMMARY_REPORT_SEARCH.md`.

## Grenzen

- Suchbegriff max. **80** Zeichen (wie Beleg-Suche).
- `$text` findet Wörter, keine beliebigen Substrings mitten im Token — Prefix-Fallback findet nur **Anfang** des `adminSearchBlob`.
- Präfix auf `investmentNumber` (`INV-…`) und Equality auf `tradeNumber` bleiben indexiert. Trade-**Anzeige** im Format `YYYY-NNN` — Spec: [`TRADE_NUMBER_REFERENCE.md`](./TRADE_NUMBER_REFERENCE.md).
