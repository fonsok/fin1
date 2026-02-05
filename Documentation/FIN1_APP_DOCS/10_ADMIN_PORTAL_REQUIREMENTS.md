# FIN1 Admin-Web-Portal: Dokumentation

> **Datum:** 2026-02-02
> **Status:** MVP Implementiert ✅
> **URL:** `http://192.168.178.24/admin/`

---

## 1. Übersicht

### 1.1 Was ist das Admin Portal?

Ein web-basiertes Administrations-Portal für FIN1, das rollen-basierte Zugriffskontrolle bietet.

| Tool | Zielgruppe | Rechte |
|------|------------|--------|
| **iOS App** | `investor`, `trader` | End-User Funktionen |
| **Parse Dashboard** | `Server-Admin` | Master Key (Root) via SSH Tunnel |
| **Admin-Web-Portal** ✅ | `admin`, `business_admin`, `security_officer`, `compliance`, `customer_service` | Rollen-basiert |

### 1.2 Technologie-Stack

| Technologie | Version | Verwendung |
|-------------|---------|------------|
| React | 18+ | Frontend Framework |
| TypeScript | 5+ | Type Safety |
| Vite | 7+ | Build Tool |
| TailwindCSS | 3+ | Styling |
| TanStack Query | 5+ | Server State |
| React Router | 6+ | Routing |

### 1.3 Rollen-Übersicht

```
┌──────────────────┬─────────────────────────────────────────────┐
│ Rolle            │ Typische Position                           │
├──────────────────┼─────────────────────────────────────────────┤
│ admin            │ Platform Admin, CTO                         │
│ business_admin   │ CFO, Finance Manager, Accounting            │
│ security_officer │ CISO, Security Lead, DevSecOps              │
│ compliance       │ Compliance Officer, Legal, Regulatory       │
│ customer_service │ Support Agent, CSR Team                     │
└──────────────────┴─────────────────────────────────────────────┘
```

---

## 2. Implementierungsstatus

### ✅ Phase 1: MVP (Abgeschlossen)

| Feature | Status | Beschreibung |
|---------|:------:|--------------|
| Login/Logout | ✅ | E-Mail/Passwort Auth |
| Dashboard | ✅ | Statistiken, Quick Actions |
| Benutzer-Suche | ✅ | Nach Name, E-Mail, Status |
| Benutzer-Details | ✅ | Profil, KYC, Aktionen |
| Benutzer-Aktionen | ✅ | Suspend/Reactivate, Passwort-Reset |
| Ticket-Liste | ✅ | Filter nach Status, Priorität |
| 2FA-Flow | ✅ | Verification bei Login |

### ✅ Phase 2: Compliance & Finance (Abgeschlossen)

| Feature | Status | Beschreibung |
|---------|:------:|--------------|
| Compliance-Events | ✅ | Liste, Filter, Review |
| 4-Augen-Freigaben | ✅ | Approve/Reject |
| Audit-Logs | ✅ | Durchsuchbar, Filter |
| Mock-Daten | ✅ | 8 Tickets, 6 Events, 10 Logs |

### ✅ Phase 3: Security & Advanced (Abgeschlossen)

| Feature | Status | Beschreibung |
|---------|:------:|--------------|
| Finanzen-Dashboard | ✅ | Revenue, Fees, Korrekturen, Rundungsdifferenzen |
| Sicherheits-Dashboard | ✅ | Alerts, Sessions, Login-Historie |
| HTTPS | ✅ | Self-signed SSL-Zertifikat |
| 2FA Setup UI | ✅ | QR-Code, Backup-Codes, Einstellungen-Seite |

### ✅ Phase 4: Testing (Abgeschlossen)

| Feature | Status | Beschreibung |
|---------|:------:|--------------|
| Unit Tests | ✅ | Vitest, 183 Tests, 90% Coverage |
| Component Tests | ✅ | React Testing Library |
| API Mocking | ✅ | vi.mock für Parse API |

### ✅ Phase 5: Polish (Teilweise abgeschlossen)

| Feature | Status | Beschreibung |
|---------|:------:|--------------|
| E-Mail-Benachrichtigungen | ✅ | Brevo SMTP, Templates, Cloud Functions |
| Echte Backend-Daten | ⏳ | Cloud Functions erweitern |
| E2E Tests | ⏳ | Playwright für kritische Flows |

---

## 3. Projektstruktur

```
admin-portal/
├── src/
│   ├── api/
│   │   ├── parse.ts          # Parse REST API (direkt, kein SDK)
│   │   └── admin.ts          # Cloud Function Wrapper
│   ├── components/
│   │   ├── ui/               # Button, Card, Input, Badge
│   │   ├── Layout.tsx        # Sidebar + Header
│   │   └── TwoFactorVerify.tsx
│   ├── context/
│   │   └── AuthContext.tsx   # Auth State Management
│   ├── hooks/
│   │   └── usePermissions.ts # Permission-basierte Navigation
│   ├── i18n/
│   │   └── de.ts             # Deutsche Übersetzungen
│   ├── pages/
│   │   ├── Login.tsx
│   │   ├── Dashboard.tsx
│   │   ├── Users/            # UserList, UserDetail
│   │   ├── Tickets/          # TicketList
│   │   ├── Compliance/       # ComplianceEvents
│   │   ├── Approvals/        # ApprovalsList
│   │   └── Audit/            # AuditLogs
│   ├── utils/
│   │   └── format.ts         # Date, Currency, Status Formatter
│   ├── App.tsx               # Routes
│   └── main.tsx              # Entry Point
├── vite.config.ts
├── tailwind.config.js
└── package.json
```

---

## 4. API-Integration

### 4.1 Architektur

Das Admin Portal verwendet **direkte REST API Calls** zum Parse Server (kein Parse SDK wegen Vite-Kompatibilität).

```typescript
// src/api/parse.ts
async function cloudFunction<T>(name: string, params?: Record<string, unknown>): Promise<T> {
  const response = await fetch(`/parse/functions/${name}`, {
    method: 'POST',
    headers: {
      'X-Parse-Application-Id': 'fin1-app-id',
      'X-Parse-Session-Token': sessionToken,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(params || {}),
  });
  const result = await response.json();
  return result.result;
}
```

### 4.2 Verwendete Cloud Functions

| Function | Bereich | Beschreibung |
|----------|---------|--------------|
| `searchUsers` | Users | Benutzersuche |
| `getUserDetails` | Users | Benutzerdetails |
| `updateUserStatus` | Users | Status ändern |
| `forcePasswordReset` | Users | Passwort zurücksetzen |
| `getAdminDashboard` | Dashboard | Statistiken |
| `getTickets` | Tickets | Ticket-Liste |
| `getComplianceEvents` | Compliance | Events-Liste |
| `reviewComplianceEvent` | Compliance | Event prüfen |
| `getPendingApprovals` | Approvals | Ausstehende Freigaben |
| `approveRequest` | Approvals | Genehmigen |
| `rejectRequest` | Approvals | Ablehnen |
| `getAuditLogs` | Audit | Log-Liste |

---

## 5. Deployment

### 5.1 Aktuelle Konfiguration

- **Server:** Ubuntu 24.04 (192.168.178.24)
- **Pfad:** `/home/io/fin1-server/admin/`
- **URL:** `http://192.168.178.24/admin/`
- **Nginx:** Location `/admin` mit SPA-Routing

### 5.2 Build & Deploy

```bash
# Auf Mac (Development)
cd admin-portal
npm run build

# Auf Server kopieren
scp -r dist/* io@192.168.178.24:~/fin1-server/admin/
```

### 5.3 Nginx-Konfiguration

```nginx
location /admin {
    alias /var/www/admin;
    try_files $uri $uri/ @admin_fallback;
}

location @admin_fallback {
    root /var/www;
    rewrite ^ /admin/index.html break;
}
```

---

## 6. Sicherheit

### 6.1 Authentifizierung

- Login via Parse `/login` Endpoint
- Session Token in `localStorage`
- Automatische Session-Validierung bei App-Start
- Logout löscht alle lokalen Daten

### 6.2 Autorisierung

- Jede Cloud Function prüft `requireAdminRole()`
- Permissions werden via `getMyPermissions` geladen
- Navigation wird rollen-basiert angezeigt
- 4-Augen-Prinzip verhindert Selbst-Genehmigung

### 6.3 Geplant: HTTPS

- Let's Encrypt Zertifikate
- Automatische Erneuerung via Certbot

---

## 7. Entwicklung

### 7.1 Lokale Entwicklung

```bash
cd admin-portal
npm install
npm run dev
# Öffne http://localhost:3000
```

### 7.2 Vite Proxy

```typescript
// vite.config.ts
proxy: {
  '/parse': {
    target: 'http://192.168.178.24',
    changeOrigin: true,
  },
}
```

### 7.3 Cursor Rules

Siehe `.cursor/rules/admin-portal.md` für:
- TypeScript Standards
- React Component Patterns
- TailwindCSS Guidelines
- API Layer Patterns

---

## 8. Testing

### 8.1 Test-Setup

```bash
# Tests ausführen
npm run test:run

# Mit Watch-Modus
npm run test

# Coverage-Report
npm run test:coverage
```

### 8.2 Test-Statistiken

| Metrik | Wert |
|--------|------|
| Test Files | 11 |
| Tests | 183 |
| Statement Coverage | 89% |
| Line Coverage | 90% |

### 8.3 Test-Kategorien

| Kategorie | Tests | Dateien |
|-----------|:-----:|---------|
| UI Components | 45 | Badge, Button, Card, Input |
| Pages | 28 | Login, Dashboard |
| Auth | 34 | AuthContext, TwoFactorVerify |
| API | 18 | parse.ts |
| Utilities | 49 | format.ts |
| Hooks | 9 | usePermissions |

---

## 9. E-Mail-Benachrichtigungen

### 9.1 Konfiguration

E-Mail-Benachrichtigungen werden über **Brevo (ehemals Sendinblue)** SMTP versendet.

**Backend-Konfiguration** (`docker-compose.yml`):
```yaml
environment:
  - SMTP_HOST=smtp-relay.brevo.com
  - SMTP_PORT=587
  - SMTP_USER=a16f37001@smtp-brevo.com
  - SMTP_PASS=<smpt-key>
  - SMTP_FROM=noreply@fin1.de
  - SMTP_SECURE=false
  - SUPPORT_EMAIL=a16f37001@smtp-brevo.com
```

### 9.2 Verfügbare E-Mail-Funktionen

| Funktion | Cloud Function | Beschreibung |
|----------|----------------|--------------|
| **Tickets** | Automatisch via Trigger | Neue Tickets, Updates, Antworten |
| **4-Augen-Freigaben** | Automatisch via Trigger | Benachrichtigung an Approver |
| **Security Alerts** | `sendSecurityAlertEmail` | Kritische Sicherheitswarnungen |
| **Passwort-Reset** | `sendPasswordResetEmail` | Reset-Link per E-Mail |
| **Test-E-Mail** | `sendTestEmail` | SMTP-Konfiguration testen |

### 9.3 E-Mail-Templates

Templates befinden sich in `backend/parse-server/cloud/utils/emailService.js`:
- **HTML + Plain Text** - Alle E-Mails haben beide Formate
- **Branding** - FIN1-Farben und -Styling
- **Deutsche Sprache** - Alle Texte auf Deutsch

### 9.4 Cloud Functions

E-Mail-bezogene Cloud Functions in `backend/parse-server/cloud/functions/notifications.js`:
- `testEmailConfig` - Testet SMTP-Konfiguration
- `sendTestEmail` - Sendet Test-E-Mail an beliebige Adresse
- `sendPasswordResetEmail` - Passwort-Reset E-Mail
- `sendSecurityAlertEmail` - Security-Warnung senden

---

## 10. Bekannte Einschränkungen

1. **Kein Parse SDK** - Direkte REST Calls wegen Vite-Kompatibilität
2. **Self-signed SSL** - Browser-Ausnahme für HTTPS erforderlich
3. **Mock-Daten** - Finance/Security Dashboards zeigen teilweise Testdaten

---

## 11. Nächste Schritte

- [x] ~~HTTPS aktivieren~~ (Self-signed Zertifikat aktiv)
- [x] ~~Finanzen-Dashboard implementieren~~
- [x] ~~Sicherheits-Dashboard implementieren~~
- [x] ~~2FA Setup UI~~
- [x] ~~Unit Tests (Vitest)~~ - 183 Tests, 90% Coverage
- [x] ~~E-Mail-Benachrichtigungen~~ (Brevo SMTP konfiguriert)
- [ ] Let's Encrypt (bei öffentlicher Domain)
- [ ] E2E Tests (Playwright)
- [ ] Echte Backend-Daten für Dashboards

---

## 12. Zugehörige Dokumentation

- [Admin Roles Separation](./09_ADMIN_ROLES_SEPARATION.md)
- [Cursor Rules: Admin Portal](../.cursor/rules/admin-portal.md)
- [Backend Permissions](../backend/parse-server/cloud/utils/permissions.js)

---

*Erstellt: 2026-02-02*
*Letzte Änderung: 2026-02-03*
