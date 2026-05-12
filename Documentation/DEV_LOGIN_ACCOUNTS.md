# Dev-Login-Übersicht (Passwörter & Rollen)

**Gültigkeit:** Entwicklung und interne Testumgebungen.  
**Nicht** für Produktion verwenden — dort eigene Geheimnisse, Rotation und ggf. Vault.

**Gemeinsame Portal-URL (Web):** eine Login-Seite für technischen Admin, Finance Admin, Security, Compliance und CSR — siehe `WEB_PANEL_LOGIN_CREDENTIALS.md` und `admin-portal/src/constants/portalLogin.ts`.

**Parse Application ID (Repo-Standard):** `fin1-app-id`.

---

## 1. Admin-Portal (Web) — wer meldet sich womit an?

| Anzeigename        | E-Mail              | Parse-Rolle        | Passwort (Repo-/Script-Default) | Bemerkung |
|--------------------|---------------------|--------------------|-----------------------------------|-----------|
| Technischer Admin  | `admin@fin1.de`     | `admin`            | `AdminSecure2024!`                | Häufig in `createAdminUser`-Beispielen / `WEB_PANEL_LOGIN_CREDENTIALS.md` „Variante 1“. |
| Technischer Admin  | `admin@fin1.de`     | `admin`            | `Test123!`                        | Ältere / alternative Anlage („Variante 2“). |
| **Finance Admin**  | `finance@fin1.de`   | `business_admin`   | **`Finance2026!`**                | Standard aus `scripts/create-business-admin.sh` (`BA_PASSWORD`). Nach `createAdminUser`/`forcePasswordReset` kann das Live-Passwort abweichen. |
| Test-Admin (Seed)  | `admin@test.com`    | `admin`            | `TestPassword123!`                | Wie iOS `TestConstants.password` / `seedTestUsers`, sofern dieser User mit Rolle `admin` existiert. |
| Security Officer   | *(von euch gesetzt)* | `security_officer` | *(kein Repo-Default)*             | Nur per `createAdminUser` mit gewähltem Passwort. |
| Compliance (Portal)| *(von euch gesetzt)* | `compliance`       | *(kein Repo-Default)*             | Nur per `createAdminUser` mit gewähltem Passwort. |

**Investor- und Trader-Testuser** haben **keinen** Web-Panel-Login (Parse lehnt die Rolle ab).

---

## 2. CSR-Portal (Web, Rolle `customer_service`)

Gleiche Login-URL wie oben; nach Login Weiterleitung zum CSR-Bereich.

| E-Mail              | Passwort (Variante „neuere Scripts“) | Passwort (Variante „älter“) |
|---------------------|--------------------------------------|-----------------------------|
| `L1@fin1.de`        | `L1Secure2024!`                      | `l1@fin1.de` → `Test123!`   |
| `L2@fin1.de`        | `L2Secure2024!`                      | `l2@fin1.de` → `Test123!`   |
| `Fraud@fin1.de`     | `FraudSecure2024!`                   | `fraud@fin1.de` → `Test123!` |
| `Compliance@fin1.de`| `ComplianceSecure2024!`              | `compliance@fin1.de` → `Test123!` |
| `Tech@fin1.de`      | `TechSecure2024!`                    | `tech@fin1.de` → `Test123!` |
| `Lead@fin1.de`      | `LeadSecure2024!`                    | `lead@fin1.de` → `Test123!` |

*(Groß-/Kleinschreibung der Mail: Parse normalisiert E-Mails; bei Problemen beide Schreibweisen testen.)*

---

## 3. iOS-App / Parse-Login — Investoren & Trader

| Konto                         | Parse-Rolle | Passwort            | Quelle |
|-------------------------------|-------------|---------------------|--------|
| `investor1@test.com` … `investor5@test.com` | `investor` | `TestPassword123!` | `FIN1/Shared/Constants/TestUserConstants.swift`, `seedTestUsers` |
| `trader1@test.com` … `trader10@test.com`  | `trader`   | `TestPassword123!` | dieselbe |

---

## 4. Hilfsfunktion (nur Dev)

| Aktion | E-Mail-Parameter | Ergebnis-Passwort (Antwort der Function) |
|--------|------------------|------------------------------------------|
| `resetDevUserPassword` | z. B. `admin@test.com` | `DevTest123!Secure` (siehe Cloud Function) |

---

## 5. Finance Admin sofort verwendbar machen

Auf dem Parse-Host (Docker):

```bash
BA_EMAIL=finance@fin1.de BA_PASSWORD='Finance2026!' bash scripts/create-business-admin.sh
```

Wenn der User **schon existiert**, setzt das Skript das Passwort nur, wenn `forcePasswordReset`/Rollenlogik in `createAdminUser` greift — sonst `createAdminUser` mit `forcePasswordReset: true` und gewünschtem Passwort (Master-Key), siehe `WEB_PANEL_LOGIN_CREDENTIALS.md`.

---

## Quellen im Repository

| Thema | Pfad |
|-------|------|
| Finance-Admin-Skript | `scripts/create-business-admin.sh` |
| iOS-Passwort Konstante | `FIN1/Shared/Constants/TestUserConstants.swift` |
| Seed Investoren/Trader | `backend/parse-server/cloud/functions/seed/users.js` |
| Portal-Login-Copy (Dev-UI) | `admin-portal/src/constants/portalLogin.ts` |
