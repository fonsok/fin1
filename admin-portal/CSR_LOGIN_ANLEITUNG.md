# CSR Portal - Anmeldung

## Anmelde-URLs

CSR-Mitarbeiter können sich auf **zwei Wegen** anmelden:

### Option 1: Direkte CSR-Login-Seite (Empfohlen)
**URL:** `https://192.168.178.24/admin/csr/login`

- Dedizierte CSR-Login-Seite mit CSR-Branding
- Gradient-Design (fin1-primary → fin1-secondary)
- Klare Kennzeichnung als "CSR Portal"
- Automatische Umleitung zum CSR-Dashboard nach erfolgreicher Anmeldung

### Option 2: Admin-Login-Seite (Funktioniert auch)
**URL:** `https://192.168.178.24/admin/login`

- Standard Admin-Login-Seite
- CSR-User werden automatisch zum CSR-Portal umgeleitet
- Funktioniert für alle Rollen (Admin, CSR, etc.)

## Anmeldedaten

Die CSR-User wurden mit folgenden E-Mail-Adressen erstellt:

- **L1@fin1.de** - Level 1 Support
- **L2@fin1.de** - Level 2 Support
- **Fraud@fin1.de** - Fraud Analyst
- **Compliance@fin1.de** - Compliance Officer
- **Tech@fin1.de** - Tech Support
- **Lead@fin1.de** - Team Lead

**Passwörter (allgemein):** werden bei `createCSRUser` gesetzt; je nach Umgebung unterschiedlich. Bei unbekanntem Stand: zurücksetzen (`createCSRUser` mit Master-Key / `forcePasswordReset`, siehe `WEB_PANEL_LOGIN_CREDENTIALS.md`).

**Interne Dev-/iobox-Historie:** Für die CSR-Konten **`L1@fin1.de` … `Lead@fin1.de`** (und ggf. Kleinbuchstaben-Varianten `l1@fin1.de` …) war auf FIN1-**Entwicklungs**-Hosts zeitweise **für alle dieselbe** Zugangsphrase gesetzt: **`Test123!`** — nur zur lokalen/LAN-Entwicklung gedacht, **nicht** für Staging/Produktion und **ungültig**, sobald jemand die Passwörter geändert hat. Dann wie oben neu setzen.

## Nach der Anmeldung

Nach erfolgreicher Anmeldung werden CSR-User automatisch zum **CSR Dashboard** (`/admin/csr`) umgeleitet.

## Features im CSR-Portal

- ✅ Dashboard mit Metriken
- ✅ Ticket-Management (Erstellen, Bearbeiten, Zuweisen, Lösen)
- ✅ Ticket-Warteschlange
- ✅ Kundensuche & Kundendetails
- ✅ KYC-Status Übersicht
- ✅ Analytics & Performance
- ✅ Trends & Mustererkennung
- ✅ Templates-Verwaltung
- ✅ FAQ-Verwaltung

## Unterschied zum Admin-Portal

- **CSR-Portal**: Fokus auf Kundenservice, Tickets, Kunden
- **Admin-Portal**: Vollständige Administration, Compliance, Finance, Security

CSR-User sehen **keine** Admin-Features wie:
- Financial Dashboard
- Security Dashboard
- System-Status
- Configuration Management
