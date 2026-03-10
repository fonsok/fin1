# Web-Panel Login-Credentials

## Login-URL
**URL:** `https://192.168.178.24/admin/login`

Alle Rollen melden sich über die gleiche Login-Seite an. Die Umleitung erfolgt automatisch basierend auf der Rolle.

---

## Admin

### ⚠️ WICHTIG: Zwei mögliche Credential-Sets

Es gibt **zwei mögliche Varianten** für Admin-User, je nachdem welche erstellt wurden:

### Variante 1: Aktuelle Scripts (Neue Passwörter)
- **E-Mail:** `admin@fin1.de`
- **Passwort:** `AdminSecure2024!`

### Variante 2: Ältere User (Test123!)
- **E-Mail:** `admin@fin1.de`
- **Passwort:** `Test123!`

**Hinweis:** Falls beide Varianten nicht funktionieren, muss der Admin-User neu erstellt werden (siehe "User-Erstellung" weiter unten).

### Zugriff
- ✅ Vollzugriff auf Admin-Portal
- ✅ Alle Features: Dashboard, Benutzer, Tickets, Compliance, Finance, Security, Configuration
- ⚠️ 2FA erforderlich (falls aktiviert)

### Erstellung
Falls der Admin-User nicht existiert, kann er über die Cloud Function erstellt werden:
```bash
curl -k -X POST https://192.168.178.24/parse/functions/createAdminUser \
  -H 'Content-Type: application/json' \
  -H 'X-Parse-Application-Id: fin1' \
  -H 'X-Parse-Master-Key: fin1-master-key' \
  -d '{
    "email": "admin@fin1.de",
    "password": "AdminSecure2024!",
    "firstName": "Admin",
    "lastName": "User"
  }'
```

---

## Trader

### ⚠️ WICHTIG: Trader können sich NICHT im Web-Panel anmelden!

Trader sind **nicht** in den `ADMIN_ROLES` enthalten und werden beim Login abgelehnt:

```typescript
const ADMIN_ROLES = ['admin', 'business_admin', 'security_officer', 'compliance', 'customer_service'];
```

**Fehlermeldung:** `"Kein Zugriff. Nur Admin-Rollen erlaubt."`

### Test-User (nur für iOS-App)
- **E-Mail:** `trader1@test.com`, `trader2@test.com`, `trader3@test.com`
- **Passwort:** `TestPassword123!Secure` (falls über `createTestUsers` erstellt)

---

## Investor

### ⚠️ WICHTIG: Investoren können sich NICHT im Web-Panel anmelden!

Investoren sind **nicht** in den `ADMIN_ROLES` enthalten und werden beim Login abgelehnt.

**Fehlermeldung:** `"Kein Zugriff. Nur Admin-Rollen erlaubt."`

### Test-User (nur für iOS-App)
- **E-Mail:** `investor1@test.com`, `investor2@test.com`
- **Passwort:** `TestPassword123!Secure` (falls über `createTestUsers` erstellt)

---

## CSR (Customer Service)

### ⚠️ WICHTIG: Zwei mögliche Credential-Sets

Es gibt **zwei mögliche Varianten** der CSR-User, je nachdem welche erstellt wurden:

### Variante 1: Aktuelle Scripts (Großbuchstaben + neue Passwörter)
| E-Mail | Rolle | Passwort | Sub-Rolle |
|--------|-------|----------|-----------|
| `L1@fin1.de` | customer_service | `L1Secure2024!` | Level 1 Support |
| `L2@fin1.de` | customer_service | `L2Secure2024!` | Level 2 Support |
| `Fraud@fin1.de` | customer_service | `FraudSecure2024!` | Fraud Analyst |
| `Compliance@fin1.de` | customer_service | `ComplianceSecure2024!` | Compliance Officer |
| `Tech@fin1.de` | customer_service | `TechSecure2024!` | Tech Support |
| `Lead@fin1.de` | customer_service | `LeadSecure2024!` | Team Lead |

### Variante 2: Ältere User (Kleinbuchstaben + Test123!)
| E-Mail | Rolle | Passwort | Sub-Rolle |
|--------|-------|----------|-----------|
| `l1@fin1.de` | customer_service | `Test123!` | Level 1 Support |
| `l2@fin1.de` | customer_service | `Test123!` | Level 2 Support |
| `fraud@fin1.de` | customer_service | `Test123!` | Fraud Analyst |
| `compliance@fin1.de` | customer_service | `Test123!` | Compliance Officer |
| `tech@fin1.de` | customer_service | `Test123!` | Tech Support |
| `lead@fin1.de` | customer_service | `Test123!` | Team Lead |

**Hinweis:** Parse Server speichert E-Mail-Adressen normalerweise case-insensitive, aber die tatsächliche Schreibweise kann variieren. Versuchen Sie beide Varianten, falls eine nicht funktioniert.

### Zugriff
- ✅ Automatische Umleitung zum CSR-Portal (`/admin/csr`)
- ✅ CSR-Dashboard, Tickets, Kunden, KYC, Analytics, Templates, FAQs
- ❌ Kein Zugriff auf Admin-Features (Finance, Security, Configuration)
- ✅ Keine 2FA erforderlich (CSR-User überspringen 2FA)

### Alternative Login-URL
**Direkte CSR-Login-Seite:** `https://192.168.178.24/admin/csr/login`

---

## Weitere Admin-Rollen

### Business Admin
- Kann über `createAdminUser` mit `role: 'business_admin'` erstellt werden
- ⚠️ 2FA erforderlich (falls aktiviert)

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
  -H 'X-Parse-Application-Id: fin1' \
  -H 'X-Parse-Master-Key: fin1-master-key' \
  -d '{
    "email": "admin@fin1.de",
    "password": "AdminSecure2024!",
    "firstName": "Admin",
    "lastName": "User"
  }'
```

### CSR-User erstellen
```bash
curl -k -X POST https://192.168.178.24/parse/functions/createCSRUser \
  -H 'Content-Type: application/json' \
  -H 'X-Parse-Application-Id: fin1' \
  -H 'X-Parse-Master-Key: fin1-master-key' \
  -d '{
    "email": "L1@fin1.de",
    "password": "L1Secure2024!",
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

## 🔍 Welche Credentials sind gültig?

### Admin-User: Zwei mögliche Varianten

**Variante 1 (Neue Scripts):**
- E-Mail: `admin@fin1.de`
- Passwort: `AdminSecure2024!`

**Variante 2 (Ältere User):**
- E-Mail: `admin@fin1.de`
- Passwort: `Test123!`

### CSR-User: Zwei mögliche Varianten

**Variante 1 (Neue Scripts):**
- E-Mail: `L1@fin1.de`, `L2@fin1.de`, etc. (Großbuchstaben)
- Passwort: `L1Secure2024!`, `L2Secure2024!`, etc.

**Variante 2 (Ältere User):**
- E-Mail: `l1@fin1.de`, `l2@fin1.de`, etc. (Kleinbuchstaben)
- Passwort: `Test123!` (für alle)

### Empfehlung zum Testen

1. **Versuchen Sie zuerst Variante 2** (die gestern funktioniert hat):
   - **Admin:** `admin@fin1.de` / `Test123!`
   - **CSR:** `l1@fin1.de` / `Test123!`, `l2@fin1.de` / `Test123!`, etc.

2. **Falls das nicht funktioniert**, versuchen Sie Variante 1:
   - **Admin:** `admin@fin1.de` / `AdminSecure2024!`
   - **CSR:** `L1@fin1.de` / `L1Secure2024!`, `L2@fin1.de` / `L2Secure2024!`, etc.

3. **Falls beide nicht funktionieren**, müssen die User neu erstellt werden (siehe "User-Erstellung" weiter unten).
