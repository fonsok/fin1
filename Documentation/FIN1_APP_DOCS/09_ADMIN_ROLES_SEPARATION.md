# Admin-Rollen und Aufgabentrennung (Separation of Duties)

**Stand:** 2026-02-02
**Zweck:** Klare Definition der Admin-Rollen, Rechte und Verantwortlichkeiten im FIN1-Projekt.

---

## 1. Executive Summary

FIN1 unterscheidet **zwei Ebenen** von Admin-Zugang:

| Ebene | Zugang | Rechte | Wer |
|-------|--------|--------|-----|
| **Parse Dashboard** | `DASHBOARD_USER/PASSWORD` + Master Key | Schema ändern, alle Daten R/W, Cloud Code | **Server-Admin** |
| **App-Admin (Cloud Functions)** | App-Login mit Admin-Rolle | Nur was Cloud Functions erlauben | **Fachliche Admins** |

**Kritisch:** Dashboard = Root-Zugriff. Dashboard-Credentials gehören **nur** zum Server-Admin.

---

## 2. Rollen im System

### 2.1 Technische Rollen (Parse/Postgres)

```
investor         - Investor (End-User)
trader           - Händler (End-User)
admin            - Voll-Administrator (App-Level)
business_admin   - Business/Accounting Administrator (CFO, Finance)
security_officer - Security Officer (CISO, DevSecOps)
compliance       - Compliance Officer (Legal, Regulatory)
customer_service - Customer Service Representative (CSR)
system           - System-Prozesse (kein Login)
```

### 2.2 Rollen-Hierarchie

```
┌─────────────────────────────────────────────────────────────────┐
│  Server-Admin (Dashboard Root) - NICHT im App-System           │
│  → SSH + backend/.env Zugang                                   │
├─────────────────────────────────────────────────────────────────┤
│  admin              - Alle App-Level-Rechte                    │
│  business_admin     - Financial/Accounting Oversight           │
│  security_officer   - Security & Release Gatekeeper            │
│  compliance         - Audit & Regulatory                       │
│  customer_service   - User Support                             │
├─────────────────────────────────────────────────────────────────┤
│  investor / trader  - End Users                                │
└─────────────────────────────────────────────────────────────────┘
```

### 2.2 Infrastruktur-Rollen (außerhalb der App)

| Rolle | Beschreibung | Credentials |
|-------|--------------|-------------|
| **Server-Admin** | Ubuntu/Docker/Nginx, Parse Dashboard | SSH + `.env` Secrets |
| **Xcode-Admin** | iOS-Entwicklung, App-Releases | Xcode, Apple Developer |

---

## 3. Ideale Rollenverteilung

### 3.1 Xcode-Admin (Frontend/iOS)

**Verantwortung:** iOS-App-Entwicklung, Builds, App-Releases

| Aufgabe | Erlaubt |
|---------|:-------:|
| SwiftUI/MVVM Code schreiben | ✅ |
| `.xcconfig` / Schemes konfigurieren | ✅ |
| SwiftLint/SwiftFormat, Tests | ✅ |
| App Store / TestFlight Releases | ✅ |
| Cloud Function Requirements definieren | ✅ |
| SSH auf Server | ❌ |
| Parse Dashboard Zugang | ❌ |
| Master Key kennen | ❌ |
| `backend/.env` einsehen | ❌ |
| Daten manuell ändern | ❌ |

**Credentials:**
- Parse Server URL: `https://192.168.178.24/parse`
- Parse App ID: `fin1-app-id`
- Apple Developer Portal Zugang

---

### 3.2 Server-Admin (Infrastruktur + Dashboard)

**Verantwortung:** Backend-Infrastruktur, Sicherheit, Dashboard-Betrieb

| Aufgabe | Erlaubt |
|---------|:-------:|
| SSH auf Ubuntu Server | ✅ |
| Docker/Nginx verwalten | ✅ |
| Parse Dashboard (nur via SSH-Tunnel) | ✅ |
| Schema-Änderungen ausrollen | ✅ |
| Backups/Restore | ✅ |
| Secrets verwalten (`.env`) | ✅ |
| Monitoring/Logs | ✅ |
| iOS-Code ändern | ❌ |
| Fachliche Entscheidungen treffen | ❌ |
| Daten "still" korrigieren | ❌ |

**Credentials:**
- SSH: `io@192.168.178.24`
- Dashboard: `admin` / `[aus .env]`
- Master Key: `[aus .env]`
- DB-Passwörter: `[aus .env]`

**WICHTIG:** Dashboard nur per SSH-Tunnel!
```bash
ssh -L 443:127.0.0.1:443 io@192.168.178.24
# Dann: https://localhost/dashboard/
```

---

### 3.3 App-Level Admin-Rollen

Diese Rollen arbeiten **innerhalb der App** über Cloud Functions, **nicht** im Parse Dashboard.

#### 3.3.1 Admin (`role: 'admin'`)

**Zweck:** Voll-Administrator auf App-Ebene

| Berechtigung | Status |
|--------------|:------:|
| Dashboard-Stats sehen | ✅ |
| User suchen/verwalten | ✅ |
| User-Status ändern | ✅ |
| 4-Augen-Freigaben erteilen | ✅ |
| Compliance-Events reviewen | ✅ |
| Reports exportieren | ✅ |
| Korrekturbuchungen anlegen | ✅ |

#### 3.3.2 Customer Service (`role: 'customer_service'`)

**Zweck:** User-Support ohne Finanz-Eingriffe

| Berechtigung | Status |
|--------------|:------:|
| Dashboard-Stats sehen (eingeschränkt) | ✅ |
| User suchen | ✅ |
| Support-Tickets verwalten | ✅ |
| KYC-Status einsehen | ✅ |
| User-Status ändern | ⚠️ (nur suspend/reactivate) |
| 4-Augen-Freigaben erteilen | ❌ |
| Finanz-Daten ändern | ❌ |

#### 3.3.3 Business Admin (`role: 'business_admin'`)

**Zweck:** Financial/Accounting Oversight (CFO, Finance Manager)

| Berechtigung | Status |
|--------------|:------:|
| Financial Dashboard | ✅ |
| Investment/Trade Übersicht (read) | ✅ |
| Rundungsdifferenzen prüfen | ✅ |
| Korrekturbuchungen anlegen (mit 4-Augen) | ✅ |
| Bank-Abstimmung prüfen | ✅ |
| Financial Reports exportieren | ✅ |
| 4-Augen-Freigaben (finanziell) | ✅ |
| User-Status (suspend/reactivate) | ✅ |
| Schema-Änderungen | ❌ |
| Security-Konfiguration | ❌ |

#### 3.3.4 Security Officer (`role: 'security_officer'`)

**Zweck:** Security & Release Gatekeeper (CISO, DevSecOps)

| Berechtigung | Status |
|--------------|:------:|
| Security Dashboard | ✅ |
| Login-Historie einsehen | ✅ |
| Fehlgeschlagene Logins prüfen | ✅ |
| User-Sessions terminieren | ✅ |
| Passwort-Reset erzwingen | ✅ |
| Security-Events reviewen | ✅ |
| Data Access Logs einsehen | ✅ |
| Audit-Logs (vollzugriff) | ✅ |
| Release-Freigaben | ✅ |
| User-Status (lock/suspend/reactivate) | ✅ |
| Financial Reports | ❌ |
| Korrekturbuchungen | ❌ |

#### 3.3.5 Compliance (`role: 'compliance'`)

**Zweck:** Audit-Prüfung, Regulatory Affairs

| Berechtigung | Status |
|--------------|:------:|
| Compliance-Events reviewen | ✅ |
| Audit-Logs einsehen | ✅ |
| 4-Augen-Freigaben erteilen | ✅ |
| Reports exportieren | ✅ |
| GDPR-Anfragen bearbeiten | ✅ |
| KYC-Dokumente reviewen | ✅ |
| Legal Documents einsehen | ✅ |
| User-Status ändern | ❌ |
| Korrekturbuchungen anlegen | ❌ |
| Sessions terminieren | ❌ |

#### 3.3.6 Customer Service (`role: 'customer_service'`)

**Zweck:** User-Support (CSR Team)

| Berechtigung | Status |
|--------------|:------:|
| Dashboard (eingeschränkt) | ✅ |
| User suchen | ✅ |
| Support-Tickets verwalten | ✅ |
| KYC-Status einsehen | ✅ |
| User-Status (suspend/reactivate) | ✅ |
| Passwort-Reset anfordern | ✅ |
| Account entsperren | ✅ |
| Verifikations-E-Mail erneut senden | ✅ |
| 4-Augen-Freigaben | ❌ |
| Financial Reports | ❌ |
| Compliance-Events | ❌ |

---

## 4. RACI-Matrix

**R** = Responsible (führt aus)
**A** = Accountable (verantwortlich)
**C** = Consulted (wird befragt)
**I** = Informed (wird informiert)

### 4.1 Infrastruktur & Entwicklung

| Aufgabe | Xcode-Admin | Server-Admin |
|---------|:-----------:|:------------:|
| iOS-Code/Architektur | **R/A** | I |
| App-Build-Konfiguration | **R/A** | I |
| App Store Releases | **R/A** | I |
| Server-Betrieb (Docker/Nginx) | I | **R/A** |
| Parse Dashboard Zugang | - | **R/A** |
| Schema-Änderungen produktiv | C | **R/A** |
| Backups/Restore | - | **R/A** |
| Secrets-Management | - | **R/A** |

### 4.2 App-Level Admin-Aufgaben

| Aufgabe | admin | business_admin | security_officer | compliance | customer_service |
|---------|:-----:|:--------------:|:----------------:|:----------:|:----------------:|
| **User-Support/Tickets** | C | - | - | I | **R/A** |
| **User-Status ändern** | **R/A** | R | R | I | R (eingeschränkt) |
| **KYC-Reviews** | C | - | - | **R/A** | R (einsehen) |
| **Compliance-Events** | I | I | C | **R/A** | - |
| **4-Augen-Freigaben** | **R** | **R** | **R** | **R/A** | - |
| **Korrekturbuchungen** | R | **R/A** | - | C | - |
| **Rundungsdifferenzen** | I | **R/A** | - | C | - |
| **Audit-Log Reviews** | I | I | **R** | **R/A** | - |
| **Security-Alerts** | I | - | **R/A** | C | - |
| **Session-Terminierung** | R | - | **R/A** | I | - |
| **Passwort-Reset** | R | - | **R** | - | **R** |
| **Release-Freigaben** | C | - | **R/A** | I | - |
| **GDPR-Anfragen** | I | - | C | **R/A** | I |
| **Financial Reports** | R | **R/A** | - | C | - |
| **Login-Historie prüfen** | R | - | **R/A** | C | - |

---

## 5. Rollen-Struktur (Wachstumsstrategie)

### 5.1 Implementierte Rollen

Alle Rollen sind **bereits implementiert** und können bei Bedarf aktiviert werden:

| Rolle | Status | Wann aktivieren? |
|-------|:------:|------------------|
| `admin` | ✅ Implementiert | Ab Tag 1 |
| `customer_service` | ✅ Implementiert | Ab erstem Support-Mitarbeiter |
| `compliance` | ✅ Implementiert | Ab Compliance Officer / MiFID II |
| `business_admin` | ✅ Implementiert | Ab CFO / Finance Team |
| `security_officer` | ✅ Implementiert | Ab CISO / SOC2 Audit |

### 5.2 Wachstums-Szenarien

#### Phase 1: Startup (2-4 Personen)
```
Xcode-Admin + Server-Admin + admin (gleiche Person möglich)
```

#### Phase 2: Kleines Team (5-10 Personen)
```
Xcode-Admin
Server-Admin
admin
customer_service (1-2 CSR)
compliance (Teil- oder Vollzeit)
```

#### Phase 3: Wachstum (10-25 Personen)
```
Xcode-Admin (Team)
Server-Admin (Team)
admin + business_admin (Finance Team)
compliance (Compliance Team)
customer_service (CSR Team)
```

#### Phase 4: Scale-Up (25+ Personen)
```
Xcode-Admin (iOS Team Lead)
Server-Admin (DevOps Team)
admin (App Admin)
business_admin (CFO, Finance)
security_officer (CISO, Security Team)
compliance (Compliance, Legal)
customer_service (CSR Team)
```

### 5.3 Aktuelle Rollen-Architektur

```
┌─────────────────────────────────────────────────────────────────┐
│                      INFRASTRUKTUR                              │
│                                                                 │
│    Xcode-Admin                    Server-Admin                  │
│    (iOS/App-Code)                 (Dashboard Root)              │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    APP-LEVEL ROLLEN                             │
│                                                                 │
│   ┌──────────┐ ┌──────────────┐ ┌────────────────┐             │
│   │  admin   │ │business_admin│ │security_officer│             │
│   │          │ │  (Finance)   │ │   (Security)   │             │
│   └──────────┘ └──────────────┘ └────────────────┘             │
│                                                                 │
│   ┌──────────────┐ ┌────────────────┐                          │
│   │  compliance  │ │customer_service│                          │
│   │   (Audit)    │ │     (CSR)      │                          │
│   └──────────────┘ └────────────────┘                          │
│                                                                 │
│   ✅ Alle Rollen implementiert und bereit für Aktivierung      │
└─────────────────────────────────────────────────────────────────┘
```

---

## 6. Security Hardening Checkliste

### 6.1 Parse Dashboard

- [ ] Dashboard **nur via SSH-Tunnel** erreichbar
- [ ] `DASHBOARD_PASSWORD` sicher gewählt (nicht default)
- [ ] `PARSE_SERVER_MASTER_KEY_IPS` konfiguriert (IP-Whitelist)
- [ ] Master Key nicht in Git/Code/Logs

### 6.2 Server

- [ ] SSH nur mit Key-Auth (kein Passwort)
- [ ] Firewall aktiv (nur nötige Ports offen)
- [ ] Docker-Container non-root wo möglich
- [ ] Regelmäßige Updates/Patches
- [ ] Backup-Script aktiv und getestet

### 6.3 Secrets

- [ ] `backend/.env` nur auf Server (nicht in Git)
- [ ] Secrets regelmäßig rotieren
- [ ] Keine Secrets in Logs/Error Messages
- [ ] Keychain/Vault für kritische Secrets

### 6.4 Audit

- [ ] `ComplianceEvent` ist Master-Key-only (immutable)
- [ ] Audit-Logs haben 10-Jahre Retention
- [ ] Delete-Protection für kritische Klassen aktiv
- [ ] 4-Augen-Prinzip für kritische Aktionen

---

## 7. Change-Prozess

### 7.1 Schema-Änderungen

```
1. Xcode-Admin erstellt "Schema-Change-Request":
   - Neue Klasse/Felder
   - Zweck/Business-Case
   - Impact-Analyse

2. Review durch Compliance (bei Finanz-Daten)

3. Server-Admin setzt um:
   - Idealerweise per Migration-Script
   - Dokumentation der Änderung

4. Xcode-Admin testet in Staging

5. Production-Rollout mit Protokoll
```

### 7.2 Daten-Korrekturen

```
1. NIEMALS "stille" Korrekturen im Dashboard!

2. Korrektur-Anfrage durch App-Admin:
   - Grund dokumentieren
   - Betroffene Daten identifizieren

3. 4-Augen-Freigabe durch Compliance

4. Korrekturbuchung (Reversal-Pattern):
   - Original-Buchung bleibt erhalten
   - Gegenbuchung + Korrektur-Buchung
   - Audit-Trail automatisch

5. Dokumentation im Audit-Log
```

---

## 8. Technische Implementierung

### 8.1 Differenzierte Rechte in Cloud Functions

Die aktuellen Cloud Functions behandeln `admin`, `customer_service` und `compliance` gleich.

**Empfehlung:** Differenzierte Berechtigungsprüfungen einführen.

Siehe: `backend/parse-server/cloud/utils/permissions.js` (neu zu erstellen)

### 8.2 Beispiel-Implementierung

> **Hinweis (Stand Code):** Die produktive Rollen-Matrix liegt in **`backend/parse-server/cloud/utils/permissions/constants.js`**. Die Rolle `customer_service` enthält dort u. a. auch **`getCompanyKybSubmissions`** und **`getCompanyKybSubmissionDetail`** (Lesen von Firmen-KYB im Admin-/CSR-Web-Portal), nicht aber `reviewCompanyKyb` / `resetCompanyKyb`. Das folgende Snippet ist nur ein vereinfachtes **Muster** und nicht 1:1 der Live-Stand.

```javascript
// permissions.js
const PERMISSIONS = {
  admin: ['*'], // Alle Rechte
  customer_service: [
    'getAdminDashboard',
    'searchUsers',
    'getTickets',
    'updateTicket',
    'viewKYCStatus'
  ],
  compliance: [
    'getAdminDashboard',
    'searchUsers',
    'getComplianceEvents',
    'reviewComplianceEvent',
    'getPendingApprovals',
    'approveRequest',
    'getAuditLogs',
    'exportReports'
  ]
};

function requirePermission(request, permission) {
  if (!request.user) {
    throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, 'Login required');
  }

  const role = request.user.get('role');
  const allowed = PERMISSIONS[role];

  if (!allowed) {
    throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN, 'Invalid role');
  }

  if (allowed[0] !== '*' && !allowed.includes(permission)) {
    throw new Parse.Error(
      Parse.Error.OPERATION_FORBIDDEN,
      `Permission '${permission}' not allowed for role '${role}'`
    );
  }
}

module.exports = { requirePermission, PERMISSIONS };
```

---

## 9. Referenzen

- `FIN1_PROJECT_STATUS.md` - Aktuelle Verbindungs-/URL-Infos
- `backend/README.md` - Docker-Setup
- `06A_BACKEND_UBUNTU_IOBOX_RUNBOOK.md` - Server-Betrieb
- `06B_CSR_SUPPORT_WORKFLOW.md` - Support-Prozesse
- `backend/parse-server/cloud/functions/admin.js` - Aktuelle Admin-Funktionen

---

## 10. Versionsverlauf

| Datum | Änderung | Autor |
|-------|----------|-------|
| 2026-02-02 | Erstversion | - |
