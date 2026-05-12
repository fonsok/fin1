# Web-Panel Login-Credentials

**Kompakte Dev-Übersicht (E-Mails, Rollen, Abläufe):** [`Documentation/DEV_LOGIN_ACCOUNTS.md`](Documentation/DEV_LOGIN_ACCOUNTS.md)  
**Hinweis:** Passwörter und Master-Keys werden **nicht** in diesem Markdown im Klartext dokumentiert. Beispiele unten nutzen Platzhalter (`DEIN_MASTER_KEY`, `<…>`).

## Login-URL
**URL:** `https://192.168.178.24/admin/login`

Alle Rollen melden sich über die gleiche Login-Seite an. Die Umleitung erfolgt automatisch basierend auf der Rolle.

### Parse REST: Application ID und Master-Key

In diesem Repository ist die Standard-**Application ID** **`fin1-app-id`** (siehe `docker-compose.yml`, `Config/FIN1-Base.xcconfig`, `backend/env.example`).
Ältere Beispiele in Dokumentationen nutzen teils `fin1` — das führt zu **`unauthorized`**, wenn der Server `fin1-app-id` erwartet.

Der **Master-Key** stammt aus der Server-Konfiguration (z. B. `PARSE_SERVER_MASTER_KEY` in `backend/.env` / Docker), nicht aus diesem Dokument.

---

## Account-Lockout (Parse Server)

Nach **fehlgeschlagenen Login-Versuchen** sperrt Parse Server das Konto **temporär** (nicht nginx, nicht das Admin-Portal).

Konfiguration in `backend/parse-server/index.js` (`accountLockout`):

| Parameter | Wert | Bedeutung |
|-----------|------|-----------|
| `threshold` | **3** | Fehlversuche bis zur Sperre |
| `duration` | **5** | Sperrdauer in **Minuten** |

Typische Fehlermeldung (englisch): *Your account is locked due to multiple failed login attempts. Please try again after 5 minute(s).*

**Was tun (ohne Wartezeit):** Parse-Container mit **aktuellem Cloud-Code** neu starten, dann eine der folgenden Optionen:

1. **Nur Lockout aufheben (Master-Key):** Cloud Function `unlockParseAccountLockout` — entfernt `_failed_login_count` und `_account_lockout_expires_at` sofort.

```bash
curl -sk -X POST 'https://DEIN_HOST/parse/functions/unlockParseAccountLockout' \
  -H 'X-Parse-Application-Id: fin1-app-id' \
  -H 'X-Parse-Master-Key: DEIN_MASTER_KEY' \
  -H 'Content-Type: application/json' \
  -d '{"email":"finance@fin1.de"}'
```

2. **`createAdminUser` mit `forcePasswordReset: true`:** Setzt Passwort **und** hebt die Sperre auf (gleicher Cloud-Code wie oben).

Ohne Deploy: nur Wartezeit (~5 Minuten) oder manuell in MongoDB die Felder `_failed_login_count` / `_account_lockout_expires_at` am `_User`-Dokument entfernen.

---

## Admin

### Zwei typische Credential-Herkünfte

Für `admin@fin1.de` kann das Passwort je nach Anlagezeitpunkt und Skript variieren. **Nicht** raten aus Doku — stattdessen:

- Passwort bewusst setzen: `createAdminUser` mit **`forcePasswordReset: true`** und eigenem Passwort (siehe unten), oder
- Neuinstallation / Seed-Dokumentation in `Documentation/DEV_LOGIN_ACCOUNTS.md` beachten.

**Hinweis:** Auf einem **bestehenden** Server (Restore, manuelle Änderung) weicht das Live-Passwort oft von alten Beispielen ab.  
Falls Login scheitert: zuerst **Lockout** (Abschnitt oben) und die **richtige Application ID** (`fin1-app-id`) prüfen.

### Zugriff
- ✅ Vollzugriff auf Admin-Portal
- ✅ Alle Features: Dashboard, Benutzer, Tickets, Compliance, Finance, Security, Configuration
- ⚠️ 2FA erforderlich (falls aktiviert)

### Erstellung (Beispiel — Passwort selbst wählen)

```bash
curl -k -X POST https://192.168.178.24/parse/functions/createAdminUser \
  -H 'Content-Type: application/json' \
  -H 'X-Parse-Application-Id: fin1-app-id' \
  -H 'X-Parse-Master-Key: DEIN_MASTER_KEY' \
  -d '{
    "email": "admin@fin1.de",
    "password": "<SICHERES_PASSWORT>",
    "firstName": "Admin",
    "lastName": "User"
  }'
```

---

## Trader

### WICHTIG: Trader können sich NICHT im Web-Panel anmelden!

Trader sind **nicht** in den `ADMIN_ROLES` enthalten und werden beim Login abgelehnt:

```typescript
const ADMIN_ROLES = ['admin', 'business_admin', 'security_officer', 'compliance', 'customer_service'];
```

**Fehlermeldung:** `"Kein Zugriff. Nur Admin-Rollen erlaubt."`

### Test-User (nur für iOS-App / Parse-Login, nicht Web-Panel)

Trader haben **keinen** Web-Panel-Zugang; die Accounts dienen der **mobilen App** und ggf. API-Tests.

- **E-Mail:** `trader1@test.com` … `trader10@test.com` (10 Trader)
- **Passwort:** Wert aus `TestConstants.password` in `FIN1/Shared/Constants/TestUserConstants.swift`; Backend-Vollprofile per Cloud Function `seedTestUsers` (`backend/parse-server/cloud/functions/seed/users.js`).

---

## Investor

### WICHTIG: Investoren können sich NICHT im Web-Panel anmelden!

Investoren sind **nicht** in den `ADMIN_ROLES` enthalten und werden beim Login abgelehnt.

**Fehlermeldung:** `"Kein Zugriff. Nur Admin-Rollen erlaubt."`

### Test-User (nur für iOS-App / Parse-Login, nicht Web-Panel)

- **E-Mail:** `investor1@test.com` … `investor5@test.com` (5 Investoren)
- **Passwort:** wie bei Trader — `TestUserConstants.swift` und `seedTestUsers`.

---

## CSR (Customer Service)

### Zwei typische E-Mail-Schreibweisen

| Variante | E-Mails | Passwort |
|----------|---------|----------|
| Neuere Anlage (typisch) | `L1@fin1.de`, `L2@fin1.de`, … | Beim `createCSRUser` gesetzt; siehe Seed/Skript-Historie eurer Umgebung. |
| Ältere Anlage | `l1@fin1.de`, `l2@fin1.de`, … | Ebenfalls beim Anlegen gesetzt; oft ein einheitliches einfaches Dev-Passwort — **nicht** hier dokumentiert. |

**Hinweis:** Parse speichert E-Mails in der Regel case-insensitive; bei Problemen beide Schreibweisen testen.

### Zugriff
- ✅ Automatische Umleitung zum CSR-Portal (`/admin/csr`)
- ✅ CSR-Dashboard, Tickets, Kunden, KYC, Analytics, Templates, FAQs
- ❌ Kein Zugriff auf Admin-Features (Finance, Security, Configuration)
- ✅ Keine 2FA erforderlich (CSR-User überspringen 2FA)

### Alternative Login-URL
**Direkte CSR-Login-Seite:** `https://192.168.178.24/admin/csr/login`

---

## Weitere Admin-Rollen

### Business Admin (`finance@fin1.de`)

- Anlage auf dem Server: `BA_PASSWORD='<…>' bash scripts/create-business-admin.sh` — **`BA_PASSWORD` ist erforderlich** (kein stiller Default im Skript). Alternativ `BA_PASSWORD` in **`scripts/.env.server`** (gitignored), siehe **`scripts/.env.server.example`**.
- **Wichtig:** Existiert der User bereits, bleibt das Passwort unverändert, sofern ihr **nicht** `forcePasswordReset: true` setzt. Nach DB-Restore oder manueller Änderung: Zurücksetzen per Cloud Function (siehe unten).
- ⚠️ 2FA: erhöhte Rollen können 2FA nutzen; im Portal sind **6-stellige TOTP-Codes** und **8-stellige Backup-Codes** (alphanumerisch) möglich.

**Passwort gezielt setzen / zurücksetzen (Master-Key):**

```bash
curl -k -X POST https://192.168.178.24/parse/functions/createAdminUser \
  -H 'Content-Type: application/json' \
  -H 'X-Parse-Application-Id: fin1-app-id' \
  -H 'X-Parse-Master-Key: DEIN_MASTER_KEY' \
  -d '{
    "email": "finance@fin1.de",
    "password": "<NEUES_SICHERES_PASSWORT>",
    "firstName": "Finance",
    "lastName": "Admin",
    "role": "business_admin",
    "forcePasswordReset": true
  }'
```

Hinweis: `passwordPolicy.maxPasswordHistory` (siehe `backend/parse-server/index.js`) verbietet Wiederholung der **letzten 5** Passwörter — bei Fehler *New password should not be the same as last 5 passwords* ein noch nicht verwendetes Passwort wählen.

### Security Officer
- Kann über `createAdminUser` mit `role: 'security_officer'` erstellt werden
- ⚠️ 2FA erforderlich (falls aktiviert)

### Compliance
- Kann über `createAdminUser` mit `role: 'compliance'` erstellt werden
- ⚠️ 2FA erforderlich (falls aktiviert)

---

## Technische Details

### Erlaubte Rollen für Web-Panel
```typescript
const ADMIN_ROLES = [
  'admin',
  'business_admin',
  'security_officer',
  'compliance',
  'customer_service'  // CSR
];
```

### Rollen mit 2FA-Anforderung
```typescript
const ELEVATED_ROLES = [
  'admin',
  'business_admin',
  'security_officer',
  'compliance'
];
// Hinweis: CSR-User überspringen 2FA
```

### Automatische Umleitungen
- **CSR-User:** Automatisch zu `/admin/csr` nach Login
- **Admin-Rollen:** Bleiben im Admin-Portal (`/admin`)

---

## User-Erstellung

### Admin-User erstellen
```bash
curl -k -X POST https://192.168.178.24/parse/functions/createAdminUser \
  -H 'Content-Type: application/json' \
  -H 'X-Parse-Application-Id: fin1-app-id' \
  -H 'X-Parse-Master-Key: DEIN_MASTER_KEY' \
  -d '{
    "email": "admin@fin1.de",
    "password": "<SICHERES_PASSWORT>",
    "firstName": "Admin",
    "lastName": "User"
  }'
```

### CSR-User erstellen
```bash
curl -k -X POST https://192.168.178.24/parse/functions/createCSRUser \
  -H 'Content-Type: application/json' \
  -H 'X-Parse-Application-Id: fin1-app-id' \
  -H 'X-Parse-Master-Key: DEIN_MASTER_KEY' \
  -d '{
    "email": "L1@fin1.de",
    "password": "<SICHERES_PASSWORT>",
    "firstName": "Lisa",
    "lastName": "Level-1"
  }'
```

Die Sub-Rolle wird automatisch aus der E-Mail erkannt:
- `L1@fin1.de` → `level_1`
- `L2@fin1.de` → `level_2`
- `Fraud@fin1.de` → `fraud_analyst`
- `Compliance@fin1.de` → `compliance_officer`
- `Tech@fin1.de` → `tech_support`
- `Lead@fin1.de` → `teamlead`

---

## Zusammenfassung

| Rolle | Web-Panel Zugriff | Login-URL | 2FA | Umleitung |
|-------|-------------------|-----------|-----|-----------|
| **Admin** | ✅ Ja | `/admin/login` | ⚠️ Ja (wenn aktiviert) | `/admin` |
| **Trader** | ❌ Nein | - | - | - |
| **Investor** | ❌ Nein | - | - | - |
| **CSR** | ✅ Ja | `/admin/login` oder `/admin/csr/login` | ❌ Nein | `/admin/csr` |
| **Business Admin** | ✅ Ja | `/admin/login` | ⚠️ Ja (wenn aktiviert) | `/admin` |
| **Security Officer** | ✅ Ja | `/admin/login` | ⚠️ Ja (wenn aktiviert) | `/admin` |
| **Compliance** | ✅ Ja | `/admin/login` | ⚠️ Ja (wenn aktiviert) | `/admin` |

---

## Welche Credentials sind gültig?

Es gibt **keine** fest im Repo dokumentierten Portal-Passwörter, die garantiert auf eurem Server stimmen.

### Vorgehen

1. **Bekanntes Passwort:** direkt einloggen.
2. **Unbekannt / nach Restore:** `createAdminUser` bzw. `createCSRUser` mit **`forcePasswordReset: true`** und **neu gewähltem** Passwort (Master-Key), oder `scripts/create-business-admin.sh` mit **`BA_PASSWORD=…`**.
3. **Lockout:** Abschnitt „Account-Lockout“ oben.
4. **Application ID:** immer `fin1-app-id` bei REST-Calls, sofern der Server so konfiguriert ist.
