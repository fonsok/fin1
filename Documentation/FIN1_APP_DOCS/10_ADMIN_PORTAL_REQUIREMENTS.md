# FIN1 Admin-Web-Portal: Dokumentation

> **Datum:** 2026-02-05
> **Status:** MVP Implementiert ✅
> **URL:** `https://192.168.178.24/admin/`

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
│   │   ├── Audit/            # AuditLogs
│   │   ├── Templates/        # Response Templates
│   │   └── CSR/              # CSR Web Panel (siehe Abschnitt 10)
│   │       ├── pages/        # CreateTicket, TicketDetails, etc.
│   │       ├── components/   # TemplateDropdown, CustomerSelection, etc.
│   │       ├── templates.ts  # Default-Textbausteine
│   │       └── api.ts        # CSR-spezifische API
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
| `getPendingApprovals` | Approvals | Ausstehende Freigaben, eigene Anträge, Historie, alle Anträge |
| `approveRequest` | Approvals | Genehmigen |
| `rejectRequest` | Approvals | Ablehnen |
| `withdrawRequest` | Approvals | Eigenen pending Antrag zurückziehen (nur Antragsteller) |
| `getAuditLogs` | Audit | Log-Liste |
| `getFAQCategories` | FAQs | FAQ-Kategorien für Landing/Help Center/CSR |
| `getFAQs` | FAQs | Server‑getriebene FAQs für Landing/Help Center/CSR |
| `createFAQ` | FAQs | Admin‑funktion, neue FAQ anlegen (inkl. Multi‑Kontext/Multi‑Kategorie) |
| `updateFAQ` | FAQs | Admin‑funktion, bestehende FAQ aktualisieren |
| `deleteFAQ` | FAQs | Admin‑funktion, FAQ archivieren (Soft Delete) |
| `createFAQCategory` | FAQs | Admin‑funktion, neue FAQ‑Kategorie anlegen (Slug + Flags) |
| `listTermsContent` | AGB & Rechtstexte | Rechtstext-Versionen listen (Filter: documentType, language) |
| `getTermsContent` | AGB & Rechtstexte | Eine Version inkl. Abschnitte zum Klonen/Bearbeiten |
| `createTermsContent` | AGB & Rechtstexte | Neue Version anlegen (terms/privacy/imprint, append-only) |
| `setActiveTermsContent` | AGB & Rechtstexte | Version für documentType+Sprache als aktiv setzen |
| `getDefaultLegalSnippetSections` | AGB & Rechtstexte | Standard-Snippet-Abschnitte (DE/EN) für neue Version (z. B. „Snippet-Abschnitte einfügen“) |
| `getDefaultLegalSnippetSectionsPublic` | Backend/Skripte | Wie oben, ohne Auth; für Seed-Skript `scripts/seed-legal-snippets.js` |

**Hinweis Navigation:** Die FAQ-Verwaltung erscheint in der Sidebar als **„Hilfe & Anleitung“**; Rechtstexte unter **„AGB & Rechtstexte“**.

**Seite Approvals (`/approvals`)** – vier Tabs:
- **Freigaben erteilen**: Pending Anträge anderer Admins (Genehmigen/Ablehnen)
- **Eigene Anträge**: Vom aktuellen User eingereichte, noch offene Anträge (mit Zurückziehen)
- **Alle Anträge**: Chronologische Liste aller Anträge aller Admins (neueste zuerst); bei eigenen pending Anträgen Button „Zurückziehen“
- **Abgeschlossen**: Genehmigte/abgelehnte/zurückgezogene Anträge (letzte 30 Tage)

**Sidebar „Freigaben“**: Solange offene Anträge existieren (Anträge zur Freigabe oder eigene pending Anträge), wird am Navigationspunkt „Freigaben“ ein rotes Badge mit der Anzahl angezeigt (Polling alle 30 s). Beide Admins sehen das Badge, bis alle Anträge bearbeitet sind.

---

## 5. Deployment

### 5.1 Aktuelle Konfiguration

- **Server:** Ubuntu 24.04 (192.168.178.24)
- **Pfad:** `/home/io/fin1-server/admin/`
- **URL:** `https://192.168.178.24/admin/`
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
    target: 'https://192.168.178.24',
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

## 10. CSR Web Panel (Standalone)

### 10.1 Übersicht

Das CSR Web Panel ist ein eigenständiges Portal für Kundenservice-Mitarbeiter (`customer_service` Rolle).

| Merkmal | Beschreibung |
|---------|--------------|
| **URL** | `https://192.168.178.24/admin/csr/` |
| **Login** | Separater Login unter `/admin/csr/login` |
| **Rolle** | Nur `customer_service` Rolle erlaubt |

### 10.2 Features

| Feature | Status | Beschreibung |
|---------|:------:|--------------|
| Dashboard | ✅ | Ticket-Statistiken, Quick Actions |
| Ticket-Liste | ✅ | Filter nach Status, Priorität, Agent |
| Ticket-Details | ✅ | Vollständige Ticket-Ansicht, Antworten |
| Ticket erstellen | ✅ | Mit Kundenauswahl und Textbausteinen |
| Kunden-Suche | ✅ | Nach Name, E-Mail, ID |
| Kunden-Details | ✅ | Profil, KYC-Status, Tickets |
| Analytics | ✅ | Performance-Metriken |
| Templates | ✅ | Textbausteine verwalten |
| FAQs | ✅ | FAQ-Verwaltung (Sidebar: „Hilfe & Anleitung“, inkl. Multi‑Kontext/Multi‑Kategorie, neue Kategorien) |
| AGB & Rechtstexte | ✅ | Terms, Datenschutz, Impressum versioniert verwalten (Filter, neue Version, Klonen, Als aktiv setzen) |

#### 10.2.1 FAQ-Verwaltung – Details

- **Multi‑Kontext:** Eine FAQ kann gleichzeitig mehreren Kontexten zugeordnet werden, z.B. `Help Center`, `Landing Page`, `Investor`, `Trader` sowie zukünftigen, frei definierbaren Kontext‑Tags.
- **Multi‑Kategorie:** Eine FAQ kann mehreren FAQ‑Kategorien (`categoryIds`) zugeordnet werden; im UI werden alle Kategorien angezeigt und im Filter berücksichtigt.
- **Legacy‑Kompatibilität:** Das Backend hält die Felder `categoryId` (Primär‑Kategorie) und `source` (Primär‑Kontext) automatisch mit den Arrays (`categoryIds`, `contexts`) synchron, sodass bestehende Clients (Swift‑App, ältere Scripts) weiterhin funktionieren.
- **Neue Kategorien:** Im FAQ‑Editor können neue Kategorien direkt erzeugt werden. Diese werden serverseitig als `FAQCategory` mit `slug`, `title`, `displayName`, `icon`, `sortOrder`, `isActive`, `showOnLanding`, `showInHelpCenter`, `showInCSR` angelegt.

#### 10.2.2 AGB & Rechtstexte – Details

- **Dokumenttypen:** AGB/Terms of Service, Datenschutz (Privacy Policy), Impressum. Jeder Typ wird mit Sprache (DE/EN) und Versionierung geführt.
- **Filter:** Nach Dokumenttyp (Alle / AGB / Datenschutz / Impressum) und Sprache. Die Statistik-Karte „Dokumenttyp“ zeigt das lesbare Label (z. B. „Datenschutz“).
- **Workflow:** Neue Version (leer), oder aus bestehender Version klonen → Abschnitte bearbeiten → speichern (append-only) → „Als aktiv setzen“. Bestehende Versionen werden nicht editiert (Immutability).
- **Leerzustand:** Typ-spezifische Meldung (z. B. „Keine Datenschutz-Versionen gefunden“) mit Hinweis auf neue Version oder Klonen. Details: `Documentation/LEGAL_DOCS_AUDIT_TRAIL.md`.
- **Schritt-für-Schritt (Abschnitt ändern):** Siehe `Documentation/AGB_RECHTSTEXTE_ADMIN_ANLEITUNG.md`.
- **Versionsanzeige:** Pro Version werden „Gültig ab“ und „Aktualisiert“ mit **Datum und Uhrzeit** (TT.MM.JJ, HH:MM) angezeigt, damit der Stand der Version eindeutig erkennbar ist.
- **Bearbeiten-Button:** In der aufgeklappten Abschnittsliste hat jeder Abschnitt einen Button **„Bearbeiten“**. Ein Klick klont die Version und öffnet den Editor mit vorausgefüllter Suche auf diesen Abschnitt (Titel/ID), sodass der gewünschte Abschnitt sofort sichtbar ist.
- **Suchfunktion im Editor:** Beim Anlegen einer neuen Version (Klonen) kann im Editor nach Abschnitten gesucht werden (Titel, Inhalt, ID); die Abschnittsliste wird gefiltert, ohne die Reihenfolge oder Daten zu ändern.
- **Änderungen zur Vorgängerversion:** Beim Aufklappen einer Version erscheint der Bereich „Änderungen zur Vorgängerversion“. Über **„Änderungen anzeigen“** wird die unmittelbar vorherige Version geladen und ein Vergleich angezeigt (hinzugefügte, entfernte, geänderte Abschnitte) – ohne manuelles Durchsuchen der Vorgängerversion.

### 10.3 Textbausteine (Ticket-Erstellung)

Bei der Ticket-Erstellung stehen vordefinierte Textbausteine zur Verfügung:

**Betreff-Vorlagen (20 Stück):**
| Kategorie | Beispiele |
|-----------|-----------|
| 👤 Konto | Kontosperrung aufheben, Passwort zurücksetzen, Anmeldeproblem |
| 📋 KYC | Dokumente nachfordern, Verifizierung abgelehnt, Adressnachweis |
| 🔧 Technisch | App-Fehler, App-Update, Verbindungsproblem |
| 💰 Finanzen | Rückerstattung, Transaktion prüfen, Gebühren erklären |
| 📄 Allgemein | Allgemeine Anfrage, Feedback, Beschwerde |

**Beschreibungs-Vorlagen (14 Stück):**
| Kategorie | Beispiele |
|-----------|-----------|
| 👋 Begrüßung | Standard-Begrüßung, Formelle Begrüßung |
| 👤 Konto | Konto entsperrt, Passwort-Reset Anleitung |
| 📋 KYC | Dokumente anfordern, KYC erfolgreich |
| 🔧 Technisch | App-Update, Cache leeren, Neuinstallation |
| 💰 Finanzen | Rückerstattung eingeleitet, Transaktion wird geprüft |
| 🏁 Abschluss | Standard-Abschluss, Problem gelöst, Weiteres Vorgehen |

### 10.4 Backend-Integration

Templates werden aus der MongoDB-Collection `CSRResponseTemplate` geladen:

```javascript
// Cloud Function
Parse.Cloud.define('getResponseTemplates', async (request) => {
  requireAdminRole(request);
  const { role, category, language = 'de' } = request.params;
  // ... returns templates filtered by role
});
```

**Fallback**: Falls die API nicht verfügbar ist, werden Default-Templates aus dem Frontend verwendet.

### 10.5 Komponenten-Struktur

```
admin-portal/src/pages/CSR/
├── pages/
│   ├── CreateTicket.tsx       # 362 Zeilen (refactored)
│   └── ...
├── components/
│   ├── TemplateDropdown.tsx   # Wiederverwendbare Template-Auswahl
│   ├── CustomerSelection.tsx  # Kundenauswahl-Komponenten
│   └── CustomerInfoSidebar.tsx # Kunden-Info Sidebar
├── templates.ts               # Default-Textbausteine
├── types.ts                   # TypeScript-Interfaces
└── api.ts                     # CSR API-Funktionen
```

### 10.6 CSR-Rollen und Berechtigungen (RBAC)

Die CSR-Berechtigungen folgen dem **Least Privilege Principle** und sind in der iOS-App unter `CustomerSupportPermission.swift` und `CustomerSupportPermissionSet.swift` definiert.

#### 10.6.1 Level 1 Support (L1)

| Kategorie | Berechtigung |
|-----------|--------------|
| **👁️ Ansicht** | Kundenprofil anzeigen |
| | KYC-Status anzeigen |
| | Investments anzeigen |
| | Dokumente anzeigen |
| | Benachrichtigungen anzeigen |
| | Support-Verlauf anzeigen |
| **✏️ Bearbeitung** | Kontaktdaten aktualisieren |
| **💬 Support** | Support-Ticket erstellen |
| | Support-Ticket beantworten |
| | Interne Notiz hinzufügen |

> ⚠️ **Banking Best Practice:** L1 hat bewusst **keinen** Zugriff auf Trades (Preise, Volumen, Strategien). Trade-Anfragen müssen an L2 eskaliert werden.

#### 10.6.2 Level 2 Support (L2)

*Enthält alle L1-Berechtigungen plus:*

| Kategorie | Berechtigung |
|-----------|--------------|
| **👁️ Ansicht** | Trades anzeigen |
| **✏️ Bearbeitung** | Adresse aktualisieren *(4-Augen)* |
| | Name aktualisieren *(4-Augen)* |
| | Passwort zurücksetzen |
| | Konto entsperren |
| **💬 Support** | An Admin eskalieren |
| **📋 Compliance** | KYC-Prüfung einleiten |

#### 10.6.3 Fraud Analyst

*Enthält alle L1-Berechtigungen plus:*

| Kategorie | Berechtigung |
|-----------|--------------|
| **🔍 Betrugsbekämpfung** | Fraud-Alerts anzeigen |
| | Transaktionsmuster anzeigen |
| | Verdächtige Aktivität melden |
| | Konto temporär sperren (<24h) |
| | Konto erweitert sperren (>24h) *(4-Augen)* |
| | Zahlungskarte sperren |
| | Chargeback einleiten *(4-Augen)* |
| **📋 Compliance** | AML-Flags anzeigen |
| **💬 Support** | An Admin eskalieren |

#### 10.6.4 Compliance Officer

*Enthält alle L1-Berechtigungen plus:*

| Kategorie | Berechtigung |
|-----------|--------------|
| **👁️ Ansicht** | Trades anzeigen *(für AML/SAR)* |
| | Audit-Protokolle anzeigen |
| **📋 Compliance** | Compliance-Prüfung anfordern |
| | KYC-Prüfung einleiten |
| | KYC-Entscheidung genehmigen *(4-Augen)* |
| | AML-Flags anzeigen |
| | SAR-Meldungen anzeigen |
| | SAR-Meldung erstellen *(4-Augen)* |
| | DSGVO-Anfrage bearbeiten |
| | DSGVO-Löschung genehmigen *(4-Augen)* |
| **🔐 Genehmigung** | SAR-Einreichung genehmigen |
| | Kontosperrung genehmigen |

#### 10.6.5 Tech Support

*Enthält alle L1-Berechtigungen plus:*

| Kategorie | Berechtigung |
|-----------|--------------|
| **📋 Compliance** | Audit-Protokolle anzeigen |
| **💬 Support** | An Admin eskalieren |

> ℹ️ Tech Support hat **keinen Schreibzugriff** auf Kundendaten – Fokus liegt auf technischer Analyse.

#### 10.6.6 Teamlead

*Enthält alle L2-Berechtigungen plus:*

| Kategorie | Berechtigung |
|-----------|--------------|
| **🔍 Betrugsbekämpfung** | Fraud-Alerts anzeigen |
| | Transaktionsmuster anzeigen |
| **📋 Compliance** | AML-Flags anzeigen |
| | Audit-Protokolle anzeigen |
| | SAR-Meldungen anzeigen |
| | Compliance-Prüfung anfordern |
| **🔐 Genehmigung** | Kontosperrung genehmigen |
| | Chargeback genehmigen |
| | SAR-Einreichung genehmigen |
| | KYC-Entscheidung genehmigen |
| | DSGVO-Löschung genehmigen |
| **⚙️ Administration** | Agenten-Berechtigungen verwalten |

#### 10.6.7 4-Augen-Prinzip

Folgende Aktionen erfordern eine Genehmigung durch **Teamlead** oder **Compliance Officer**:

| Aktion | Genehmiger |
|--------|------------|
| Adresse aktualisieren | Teamlead, Compliance |
| Name aktualisieren | Teamlead, Compliance |
| Konto erweitert sperren (>24h) | Teamlead, Compliance |
| Chargeback einleiten | Teamlead |
| SAR-Meldung erstellen | Compliance |
| DSGVO-Löschung | Teamlead, Compliance |

> ⚠️ **Wichtig:** Requester ≠ Approver (Backend-enforced)

#### 10.6.8 Berechtigungs-Kategorien

| Icon | Kategorie | Beschreibung |
|:----:|-----------|--------------|
| 👁️ | Ansicht | Nur-Lesen-Zugriff auf Kundendaten |
| ✏️ | Bearbeitung | Schreibzugriff (teilweise mit Genehmigung) |
| 💬 | Support | Ticket-Operationen |
| 📋 | Compliance | KYC/AML/GDPR-Operationen |
| 🔍 | Betrugsbekämpfung | Fraud-Detection und Kontosperrungen |
| 🔐 | Genehmigung | 4-Augen-Approver-Rechte |
| ⚙️ | Administration | Team-Management |

**Source of Truth (Code):**
- iOS: `FIN1/Features/CustomerSupport/Models/CustomerSupportPermission.swift`
- iOS: `FIN1/Features/CustomerSupport/Models/CustomerSupportPermissionSet.swift`
- iOS: `FIN1/Features/CustomerSupport/Models/CSRRole.swift`
- Backend: `backend/parse-server/cloud/functions/seed.js` (seedCSRPermissions)
- Backend: `backend/parse-server/cloud/functions/support.js` (Cloud Functions)

### 10.6.9 Backend-Integration (MongoDB)

Die CSR-Berechtigungen sind auch im Backend (MongoDB) verfügbar:

**Collections:**
| Collection | Beschreibung |
|------------|--------------|
| `CSRPermission` | Einzelne Berechtigungen mit Metadaten |
| `CSRRole` | Rollen mit Berechtigungs-Sets |

**Seeding:**
```bash
# Via Admin Portal oder curl:
curl -k -X POST "https://192.168.178.24/parse/functions/seedCSRPermissions" \
  -H "X-Parse-Application-Id: FIN1_APP_2024" \
  -H "X-Parse-Session-Token: <session-token>" \
  -H "Content-Type: application/json"

# Force Reseed (löscht existierende zuerst):
curl -k -X POST "https://192.168.178.24/parse/functions/forceReseedCSRPermissions" ...
```

**Cloud Functions:**
| Function | Beschreibung |
|----------|--------------|
| `getCSRPermissions` | Alle Berechtigungen (gruppiert nach Kategorie) |
| `getCSRRoles` | Alle Rollen mit Berechtigungen |
| `getCSRRolePermissions` | Berechtigungen einer spezifischen Rolle |
| `checkCSRPermission` | Prüft ob User eine Berechtigung hat |
| `getCSRAgentsWithRoles` | Alle CSR-Agenten mit Rollen-Info |
| `updateCSRUserRole` | Ändert CSR-Sub-Rolle eines Users |

**Beispiel-Response `getCSRRolePermissions`:**
```json
{
  "role": {
    "key": "fraud",
    "displayName": "Fraud Analyst",
    "canApprove": false
  },
  "permissionCount": 18,
  "permissions": [
    {
      "category": "viewing",
      "displayName": "Ansicht",
      "icon": "👁️",
      "permissions": [
        { "key": "viewCustomerProfile", "displayName": "Kundenprofil anzeigen" },
        ...
      ]
    },
    {
      "category": "fraud",
      "displayName": "Betrugsbekämpfung",
      "icon": "🔍",
      "permissions": [
        { "key": "viewFraudAlerts", "displayName": "Fraud-Alerts anzeigen" },
        { "key": "suspendAccountExtended", "displayName": "Konto erweitert sperren (>24h)", "requiresApproval": true },
        ...
      ]
    }
  ]
}
```

---

## 11. Bekannte Einschränkungen

1. **Kein Parse SDK** - Direkte REST Calls wegen Vite-Kompatibilität
2. **Self-signed SSL** - Browser-Ausnahme für HTTPS erforderlich
3. **Mock-Daten** - Finance/Security Dashboards zeigen teilweise Testdaten

---

## 12. Nächste Schritte

- [x] ~~HTTPS aktivieren~~ (Self-signed Zertifikat aktiv)
- [x] ~~Finanzen-Dashboard implementieren~~
- [x] ~~Sicherheits-Dashboard implementieren~~
- [x] ~~2FA Setup UI~~
- [x] ~~Unit Tests (Vitest)~~ - 183 Tests, 90% Coverage
- [x] ~~E-Mail-Benachrichtigungen~~ (Brevo SMTP konfiguriert)
- [x] ~~CSR Web Panel~~ (Textbausteine, Ticket-Erstellung)
- [ ] Let's Encrypt (bei öffentlicher Domain)
- [ ] E2E Tests (Playwright)
- [ ] Echte Backend-Daten für Dashboards

---

## 13. Zugehörige Dokumentation

- [Admin Roles Separation](./09_ADMIN_ROLES_SEPARATION.md)
- [CSR Support Workflow](./06B_CSR_SUPPORT_WORKFLOW.md)
- [Customer Support System](../CUSTOMER_SUPPORT_SYSTEM.md)
- [Cursor Rules: Admin Portal](../.cursor/rules/admin-portal.md)
- [Backend Permissions](../backend/parse-server/cloud/utils/permissions.js)

---

*Erstellt: 2026-02-02*
*Letzte Änderung: 2026-02-05*
