# FIN1 Admin Portal

Web-basiertes Administrations-Portal für FIN1 App-Level-Admins und CSR (`customer_service`).

## Live URL

| Environment | URL |
|-------------|-----|
| Production (HTTPS) | `https://192.168.178.24/admin/` |
| Local Dev | `http://localhost:3000/` |

**Hinweis:** HTTPS verwendet ein Self-signed Zertifikat (Browser-Ausnahme erforderlich). CSR-Login: `/admin/csr/login` (siehe `CSR_PORTAL_SETUP.md`).

## Übersicht

Das Admin-Portal bietet rollen-basiertes Management für:

| Rolle | Funktionen |
|-------|------------|
| **admin** | Vollzugriff auf alle Funktionen |
| **business_admin** | Financial Dashboard, Korrekturen, Reports, KYB-Prüfung/Entscheid |
| **security_officer** | Security Dashboard, Session-Management |
| **compliance** | Compliance-Events, 4-Augen-Freigaben, KYB-Prüfung/Entscheid |
| **customer_service** | User-Support, Tickets, KYC-/KYB-**Lesen** im CSR-Web (kein `reviewCompanyKyb`) |

## Setup

### 1. Dependencies installieren

```bash
cd admin-portal
npm install
```

### 2. Environment konfigurieren

```bash
cp .env.example .env
# Edit .env with your Parse Server details
```

### 3. Development Server starten

```bash
npm run dev
```

Das Portal ist dann unter `http://localhost:3000` erreichbar.

## Technologie-Stack

- **React 18** + TypeScript
- **Vite** – Build Tool
- **TailwindCSS** – Styling
- **React Router** – Navigation
- **TanStack Query** – Data Fetching
- **Parse REST** – Backend (`src/api/parse.ts`, kein Parse JS SDK im Bundle)

## Lint

ESLint **9** mit **Flat Config** (`eslint.config.js`): TypeScript (`typescript-eslint`), React Hooks, React Refresh.

```bash
npm run lint
```

## Testing

**Vitest** + **React Testing Library**. Gemeinsamer `render` in `src/test/test-utils.tsx` (u. a. `MemoryRouter`, `ThemeProvider`).

```bash
npm run test          # Watch-Modus
npm run test:run      # Einmalig (CI)
npm run test:coverage # Coverage-Report
```

**Stand (Orientierung):** ca. **191** Tests in **12** Dateien – exakte Zahlen: `npm run test:run` bzw. `test:coverage`.

## Build für Production

```bash
npm run build
```

Führt `tsc` und `vite build` aus; `postbuild` synchronisiert `dist/` nach `../admin/` (siehe `scripts/sync-admin-portal-to-admin.sh`).

## Projektstruktur (Auszug)

```
admin-portal/
├── eslint.config.js
├── vitest.config.ts
├── src/
│   ├── api/
│   │   ├── admin/          # Admin Cloud-API modular (types, dashboard, users, tickets, …)
│   │   ├── admin.ts        # Barrel: re-exportiert ./admin/* und cloudFunction
│   │   └── parse.ts
│   ├── components/
│   ├── context/
│   ├── hooks/
│   ├── pages/          # u. a. KYBReview/, CSR/, FAQs/
│   ├── test/           # setup.ts, test-utils.tsx
│   ├── App.tsx
│   └── main.tsx
├── package.json
└── vite.config.ts
```

## CSR-Web / KYB

- **KYC-Status:** Route ` /csr/kyc` (nach Login unter `/admin/csr/`).
- **KYB-Status (Firmen):** Route `/csr/kyb` – nutzt die gleiche Oberfläche wie `/kyb-review`, aber **ohne** Prüfen/Zurücksetzen, sofern die Session keine entsprechenden Cloud-Permissions hat.

## Hilfe & Anleitung (FAQs)

- **Export (Backup):** lädt ein JSON mit allen `FAQCategory`- und `FAQ`-Daten vom Backend (`exportFAQBackup`). Hover-Tooltip beschreibt den Umfang.
- **Import (Restore):** wählt eine Backup-Datei → **Dry-Run**-Preview (`importFAQBackup`) → nach Bestätigung Schreiblauf. Kategorien per `slug`, FAQs per `faqId` (Upsert).
- **Development Maintenance:** gelbe Karte — DEV-Baseline-Reset (`devResetFAQsBaseline`), analog zur Karte bei **AGB & Rechtstexte**. Erfordert auf dem Parse-Host **`ALLOW_FAQ_HARD_DELETE=true`**; bei `NODE_ENV=production` zusätzlich **`ALLOW_FAQ_HARD_DELETE_IN_PRODUCTION=true`**. Nach `.env`-Änderung den `parse-server`-Container neu starten.

## Deployment

Siehe `Documentation/FIN1_APP_DOCS/10_ADMIN_PORTAL_REQUIREMENTS.md` (Nginx, Pfade, Sicherheit).

---

*Vollständige produktseitige Doku: `Documentation/FIN1_APP_DOCS/10_ADMIN_PORTAL_REQUIREMENTS.md`*
