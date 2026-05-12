# Dev-Login-Übersicht (Rollen & Quellen)

**Gültigkeit:** Entwicklung und interne Testumgebungen.  
**Keine Klartext-Passwörter in dieser Markdown-Doku:** Zugangsdaten gehören in Secret-Store, `.env` (gitignored) oder in die im Repo genannten **Quell-Dateien** — nicht in kopierfertiger Form in die Dokumentation.

**Gemeinsame Portal-URL (Web):** siehe `WEB_PANEL_LOGIN_CREDENTIALS.md` und `admin-portal/src/constants/portalLogin.ts`.

**Parse Application ID (Repo-Standard):** `fin1-app-id`.

---

## 1. Admin-Portal (Web) — wer meldet sich womit an?

| Anzeigename        | E-Mail              | Parse-Rolle        | Passwort / woher |
|--------------------|---------------------|--------------------|------------------|
| Technischer Admin  | `admin@fin1.de`     | `admin`            | Beim Anlegen per Cloud Function `createAdminUser` gewählt; auf bestehenden Umgebungen ggf. unbekannt → `forcePasswordReset` (siehe `WEB_PANEL_LOGIN_CREDENTIALS.md`). |
| **Finance Admin**  | `finance@fin1.de`   | `business_admin`   | `scripts/create-business-admin.sh`: Passwort **nur** über **`BA_PASSWORD`** (Pflicht beim Aufruf). |
| Test-Admin (Seed)  | `admin@test.com`    | `admin`            | Konstante **`TestConstants.password`** in `FIN1/Shared/Constants/TestUserConstants.swift` sowie `seedTestUsers`, sofern der User existiert. |
| Security Officer   | *(von euch gesetzt)* | `security_officer` | Nur per `createAdminUser` mit gewähltem Passwort. |
| Compliance (Portal)| *(von euch gesetzt)* | `compliance`       | Nur per `createAdminUser` mit gewähltem Passwort. |

**Investor- und Trader-Testuser** haben **keinen** Web-Panel-Login (Parse lehnt die Rolle ab).

---

## 2. CSR-Portal (Web, Rolle `customer_service`)

Gleiche Login-URL wie das Admin-Portal; nach Login Weiterleitung zum CSR-Bereich.

| E-Mail (Varianten) | Hinweis |
|--------------------|---------|
| `L1@fin1.de` … `Lead@fin1.de` (Schreibweise mit Großbuchstaben) | Typisch mit neueren Skripten angelegt. |
| `l1@fin1.de` … `lead@fin1.de` (Kleinbuchstaben) | Ältere Anlage möglich. |

Passwörter: beim Anlegen mit `createCSRUser` gesetzt; historisch zwei „Stile“ auf Servern möglich — **keine** festen Werte hier; bei Unsicherheit User per Master-Key neu setzen oder Funktion erneut aufrufen (siehe `WEB_PANEL_LOGIN_CREDENTIALS.md`).

*(Parse normalisiert E-Mails in der Regel case-insensitive; bei Problemen beide Schreibweisen testen.)*

---

## 3. iOS-App / Parse-Login — Investoren & Trader

| Konto                         | Parse-Rolle | Passwort / Quelle |
|-------------------------------|-------------|-------------------|
| `investor1@test.com` … `investor5@test.com` | `investor` | `FIN1/Shared/Constants/TestUserConstants.swift` (`TestConstants.password`), Backend `seedTestUsers`. |
| `trader1@test.com` … `trader10@test.com`  | `trader`   | dieselbe Quelle |

---

## 4. Hilfsfunktion (nur Dev)

| Aktion | E-Mail-Parameter | Ergebnis |
|--------|------------------|----------|
| `resetDevUserPassword` | z. B. `admin@test.com` | Neues Passwort nur in der **JSON-Antwort** der Cloud Function (`newPassword`); nicht in Doku hardcoden. |

---

## 5. Finance Admin anlegen / Passwort setzen

Auf dem Parse-Host (Docker), mit **eigenem** Passwort:

```bash
BA_EMAIL=finance@fin1.de BA_PASSWORD='<Ihr gewähltes Passwort>' bash scripts/create-business-admin.sh
```

Ohne `BA_PASSWORD` bricht das Skript mit Hinweis ab — es gibt **keinen** eingebauten Default mehr.

Wenn der User **schon existiert**, setzt das Skript das Passwort nur, wenn `forcePasswordReset`/Rollenlogik in `createAdminUser` greift — sonst `createAdminUser` mit `forcePasswordReset: true` und gewünschtem Passwort (Master-Key), siehe `WEB_PANEL_LOGIN_CREDENTIALS.md`.

---

## Quellen im Repository

| Thema | Pfad |
|-------|------|
| Finance-Admin-Skript | `scripts/create-business-admin.sh` |
| iOS-Test-Passwort-Konstante | `FIN1/Shared/Constants/TestUserConstants.swift` |
| Seed Investoren/Trader | `backend/parse-server/cloud/functions/seed/users.js` |
| Portal-Login-Copy (Dev-UI) | `admin-portal/src/constants/portalLogin.ts` |
