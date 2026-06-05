# Admin Portal Naming Convention Matrix

Geltungsbereich: `admin-portal/src/**` (React/TypeScript SPA)

Verwandte Regeln: [`.cursor/rules/admin-portal.md`](../.cursor/rules/admin-portal.md)  
Parse Cloud (nur **API-Verträge**): [`Documentation/PARSE_CLOUD_NAMING_CONVENTIONS.md`](PARSE_CLOUD_NAMING_CONVENTIONS.md)

## Gleiche Prinzipien wie Parse Cloud — andere Oberfläche

| Prinzip (Parse Cloud) | Admin Portal (entsprechend) |
|----------------------|-----------------------------|
| Domain-orientierte Ordner | `pages/Users/`, `pages/Reports/summaryReportTrades/` |
| Ein Name = ein Zweck | z. B. `TradeExpandPanel.tsx`, nicht `Details.tsx` |
| Keine Temp-/Legacy-Namen im Produktivpfad | kein `tmp/`, `backup`, `copy`, `.tmp` unter `src/` |
| Queries vs. Commands trennen | UI: lesen vs. schreiben trennen; **Cloud-Aufrufe** = Parse-Namen |
| Automatische Prüfung wo möglich | ESLint + Review (Dateigröße, Struktur) |

**Nicht** 1:1 übernehmen: Parse verlangt **`lowerCamelCase.js`** für **alle** Cloud-Dateien. Im Admin-Portal gelten **React/TypeScript-Konventionen** (PascalCase für Komponenten). Sonst bricht ESLint, Imports und der bestehende Bestand (`UserTradeCard.tsx`, `SummaryReportPage.tsx`).

## Naming-Matrix

| Ebene | Regel | Gut | Schlecht |
|--------|--------|-----|----------|
| Feature-Ordner (`pages/`) | **PascalCase**, Domänenname | `Users/`, `Reports/`, `KYBReview/` | `users/`, `kyb-review/` |
| Feature-Modul (Split) | **lowerCamelCase** Unterordner | `summaryReportTrades/`, `appLedger/` | `SummaryReportTrades/` (ok, aber inkonsistent zum Rest) |
| Seiten-Komponente | **PascalCase** + `Page` oder `*Dashboard` | `SummaryReportPage.tsx`, `SystemHealthPage.tsx` | `summaryReportPage.tsx` |
| UI-Komponente | **PascalCase** | `TradeMetricsGrid.tsx`, `UserTradeCard.tsx` | `tradeMetricsGrid.tsx` |
| Shared UI | `components/ui/` — PascalCase | `Button.tsx`, `Badge.tsx` | `button.tsx` |
| Hooks | **camelCase**, Präfix `use` | `useTicketList.ts`, `usePermissions.ts` | `TicketList.ts` |
| Utils / Hilfen | **camelCase** Dateiname | `format.ts`, `configResolve.ts` | `Format.ts` |
| Typen (Feature-lokal) | `types.ts` oder `*Types.ts` | `types.ts`, `csrTypes.ts` | `Types.tsx` (keine Komponente) |
| Tests | Suffix `.test.ts(x)` | `ConfigurationPage.test.tsx` | `testConfiguration.tsx` |
| Barrel | `index.ts` Re-Exports | `summaryReportTrades/index.ts` | mehrere `export *` ohne Struktur |
| API-Modul | Domäne unter `api/admin/` | `api/admin/users.ts` | `api/getUsers.ts` |

## Parse Cloud Function-Namen (Frontend-Vertrag)

Alle Aufrufe über `cloudFunction(...)` aus `src/api/`:

- Function-Name = **exakt** `Parse.Cloud.define` im Backend (**`lowerCamelCase` + Verb**).
- Matrix und erlaubte Verben: [`PARSE_CLOUD_NAMING_CONVENTIONS.md`](PARSE_CLOUD_NAMING_CONVENTIONS.md) (z. B. `getSummaryReportTradesPage`, `getUserDetails`, `searchDocuments`).
- **Kein** Umbenennen nur im Frontend — Backend und [`scripts/check-parse-cloud-naming-conventions.sh`](../scripts/check-parse-cloud-naming-conventions.sh) sind maßgeblich.

## Dateigröße und Struktur

| Artefakt | Ziel | Maßnahme bei Überschreitung |
|----------|------|-----------------------------|
| `*Page.tsx` | **≤ 400 Zeilen** | `components/`, `types.ts`, Feature-Modul-Ordner |
| andere `.tsx` / `.ts` | **≤ 300 Zeilen** (Engineering-Default) | Subkomponenten, `utils.ts` auslagern |
| eine Verantwortung pro Datei | wie Parse-Cloud-Modularisierung | nicht Page + Tabelle + API in einer Datei |

Beispiel (Reports): `SummaryReportTradesTable.tsx` (Re-Export) → `summaryReportTrades/SummaryReportTradesTable.tsx` + `TradeExpandPanel.tsx` + `types.ts`.

## Nicht erlaubt

- Temp-/Legacy-Dateinamen: `*tmp*`, `*backup*`, `*copy*`, `*.old.*` unter `src/`
- Direkte `fetch('/parse/...')` in Komponenten (nur `api/`-Layer)
- Generische Namen ohne Domäne: `helpers.tsx`, `data.tsx`, `utils2.ts`
- Neue `PLATFORM_*`-Konstanten für fachliche Labels (siehe `admin-portal.md`)

## Durchsetzung

- Lokal: `cd admin-portal && npm run build` (tsc + vite)
- Tests: `npm run test` (Vitest)
- ESLint (Pflicht in CI): `npm run lint` — **ohne** Dateigrößen-Limit (bestehender Bestand)
- **Dateigröße (optional, advisory):**
  - `./scripts/check-admin-portal-file-lines.sh` — schneller Überblick (300 / 400 für `*Page.tsx`); Exit 0, außer mit `--strict`
  - `cd admin-portal && npm run lint:file-size` — ESLint `max-lines` (leerzeilen-/kommentarfrei)
- CI: `admin-portal`-Job führt das Shell-Skript mit `continue-on-error: true` aus (sichtbar, blockiert nicht)
- Review-Checkliste: neue/geänderte Dateien unter Limit halten; PascalCase-Komponenten; Cloud-Namen gegen Parse-Matrix

## Wann neue Konventionen ergänzen

Neues Feature-Muster (z. B. neuer Cloud-Verb) → zuerst **Parse**-Doku/Skript, dann hier nur Verweis/Beispiel — keine divergierenden Frontend-Aliase.
