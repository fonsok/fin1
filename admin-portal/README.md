# FIN1 Admin Portal

Web-basiertes Administrations-Portal für FIN1 App-Level-Admins.

## Live URL

| Environment | URL |
|-------------|-----|
| Production (HTTPS) | `https://192.168.178.24/admin/` |
| Production (HTTP) | `http://192.168.178.24/admin/` |
| Local Dev | `http://localhost:3000/` |

**Hinweis:** HTTPS verwendet ein Self-signed Zertifikat (Browser-Ausnahme erforderlich).

## Übersicht

Das Admin-Portal bietet rollen-basiertes Management für:

| Rolle | Funktionen |
|-------|------------|
| **admin** | Vollzugriff auf alle Funktionen |
| **business_admin** | Financial Dashboard, Korrekturen, Reports |
| **security_officer** | Security Dashboard, Session-Management |
| **compliance** | Compliance-Events, 4-Augen-Freigaben |
| **customer_service** | User-Support, Tickets |

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
- **Vite** - Build Tool
- **TailwindCSS** - Styling
- **React Router** - Navigation
- **TanStack Query** - Data Fetching
- **Parse JS SDK** - Backend-Anbindung

## Projektstruktur

```
admin-portal/
├── src/
│   ├── api/              # Parse API Integration
│   │   ├── parse.ts      # Parse SDK Setup
│   │   └── admin.ts      # Admin Cloud Functions
│   ├── components/       # Wiederverwendbare UI
│   │   ├── ui/           # Button, Input, Card, Badge
│   │   ├── Layout.tsx    # App-Layout mit Navigation
│   │   └── TwoFactorVerify.tsx
│   ├── context/          # React Context
│   │   └── AuthContext.tsx
│   ├── hooks/            # Custom Hooks
│   │   └── usePermissions.ts
│   ├── i18n/             # Übersetzungen (i18n-ready)
│   │   └── de.ts
│   ├── pages/            # Seiten/Screens
│   │   ├── Login.tsx
│   │   ├── Dashboard.tsx
│   │   └── Users/
│   └── utils/            # Hilfsfunktionen
│       └── format.ts
├── public/
├── index.html
├── package.json
├── vite.config.ts
├── tailwind.config.js
└── tsconfig.json
```

## Features

### ✅ Phase 1: MVP (Abgeschlossen)

- [x] Login mit E-Mail/Passwort
- [x] 2FA-Verifizierung (TOTP)
- [x] Rollen-basierte Navigation
- [x] Dashboard mit Statistiken
- [x] Benutzer-Suche und -Liste
- [x] Benutzer-Details
- [x] Status-Änderungen (Suspend/Reactivate)
- [x] Passwort-Reset

### ✅ Phase 2: Compliance & Finance (Abgeschlossen)

- [x] Ticket-Verwaltung
- [x] Compliance-Events
- [x] 4-Augen-Freigaben
- [x] Audit-Logs

### ✅ Phase 3: Security & Advanced (Abgeschlossen)

- [x] Financial Dashboard (Revenue, Fees, Korrekturen)
- [x] Security Dashboard (Sessions, Login-Historie, Alerts)
- [x] 2FA Setup UI (QR-Code, Backup-Codes)
- [x] HTTPS (Self-signed SSL)
- [x] Einstellungen-Seite

### ✅ Phase 4: Configuration & System (Abgeschlossen)

- [x] **Konfiguration** - System-Parameter verwalten mit 4-Augen-Workflow
- [x] **System-Status** - Server Health, Services, Datenbank-Status
- [x] Unit Tests (Vitest) - 183 Tests, 90% Coverage
- [x] E-Mail-Benachrichtigungen - Brevo SMTP, Templates, Cloud Functions

### ⏳ Phase 5: Refinement (In Arbeit)

- [ ] Echte Backend-Daten für System-Health (`getSystemHealth` Cloud Function)
- [ ] Configuration History (Audit-Trail UI)

## Testing

Das Projekt verwendet **Vitest** mit **React Testing Library**.

### Test-Befehle

```bash
npm run test          # Watch-Modus
npm run test:run      # Einmalig ausführen
npm run test:coverage # Mit Coverage-Report
```

### Test-Statistiken

| Metrik | Wert |
|--------|------|
| Tests | 183 |
| Test Files | 11 |
| Statement Coverage | 89% |
| Line Coverage | 90% |

### Test-Struktur

```
src/
├── api/
│   └── parse.test.ts           # API Layer Tests
├── components/
│   ├── TwoFactorVerify.test.tsx
│   └── ui/
│       ├── Badge.test.tsx
│       ├── Button.test.tsx
│       ├── Card.test.tsx
│       └── Input.test.tsx
├── context/
│   └── AuthContext.test.tsx    # Auth Flow Tests
├── hooks/
│   └── usePermissions.test.tsx
├── pages/
│   ├── Dashboard.test.tsx
│   └── Login.test.tsx
└── utils/
    └── format.test.ts
```

## Build für Production

```bash
npm run build
```

Die gebauten Dateien liegen in `dist/` und können statisch gehostet werden.

## Deployment

### Option 1: Gleicher Server (empfohlen)

Nginx-Konfiguration:

```nginx
location /admin {
    alias /var/www/admin-portal/dist;
    try_files $uri $uri/ /admin/index.html;
}
```

### Option 2: Separates Hosting

```bash
# Build
npm run build

# Upload dist/ zu Vercel, Netlify, oder anderem Static Host
```

## Sicherheit

- **2FA Pflicht** für elevated roles (admin, business_admin, security_officer, compliance)
- **Session-Timeout** nach 30 Minuten Inaktivität
- **Rollen-basierte Permissions** auf API-Ebene (Cloud Functions)
- **Audit-Logging** aller Admin-Aktionen

## Entwicklung

### Neue Seite hinzufügen

1. Erstelle Datei in `src/pages/`
2. Füge Route in `src/App.tsx` hinzu
3. Füge Navigation in `src/hooks/usePermissions.ts` hinzu

### Neue API-Funktion

1. Füge Cloud Function im Backend hinzu
2. Füge TypeScript-Wrapper in `src/api/admin.ts` hinzu

---

*Erstellt: 2026-02-02*
*Dokumentation: Documentation/FIN1_APP_DOCS/10_ADMIN_PORTAL_REQUIREMENTS.md*
