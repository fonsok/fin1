# Dev-Login-Übersicht (Rollen & Quellen)

**Gültigkeit:** Entwicklung und interne Testumgebungen.
**Keine Klartext-Passwörter in dieser Markdown-Doku:** Zugangsdaten gehören in Secret-Store, `.env` (gitignored) oder in die im Repo genannten **Quell-Dateien** — nicht in kopierfertiger Form in die Dokumentation.

**Gemeinsame Portal-URL (Web):** siehe `WEB_PANEL_LOGIN_CREDENTIALS.md` und `admin-portal/src/constants/portalLogin.ts`.

**Parse Application ID (Repo-Standard):** `fin1-app-id`.

---

## 1. Admin-Portal (Web) — wer meldet sich womit an?

| Anzeigename        | E-Mail              | Parse-Rolle        | Passwort / woher |
|--------------------|---------------------|--------------------|------------------|
| Technischer Admin  | `admin@fin1.de`     | `admin`            | `scripts/create-tech-admin.sh` mit **`BA_PASSWORD`** (optional `BA_EMAIL` / `BA_FIRST` / `BA_LAST`). |
| **Finance Admin**  | `finance@fin1.de`   | `business_admin`   | `scripts/create-business-admin.sh` mit **`BA_PASSWORD`** (optional `BA_EMAIL`). |
| Test-Admin (Seed)  | `admin@test.com`    | `admin`            | Konstante **`TestConstants.password`** in `FIN1/Shared/Constants/TestUserConstants.swift` sowie `seedTestUsers`, sofern der User existiert. |
| Security Officer   | *(von euch gesetzt)* | `security_officer` | Nur per `createAdminUser` mit gewähltem Passwort. |
| Compliance (Portal)| Standard `compliance@fin1.de` (überschreibbar) | `compliance`       | `scripts/create-compliance-admin.sh` mit **`BA_PASSWORD`** (optional `BA_EMAIL` / Namen). |

**Investor- und Trader-Testuser** haben **keinen** Web-Panel-Login (Parse lehnt die Rolle ab).

---

## 2. CSR-Portal (Web, Rolle `customer_service`)

Gleiche Login-URL wie das Admin-Portal; nach Login Weiterleitung zum CSR-Bereich.

| E-Mail (Varianten) | Hinweis |
|--------------------|---------|
| `L1@fin1.de` … `Lead@fin1.de` (Schreibweise mit Großbuchstaben) | Typisch mit neueren Skripten angelegt. |
| `l1@fin1.de` … `lead@fin1.de` (Kleinbuchstaben) | Ältere Anlage möglich. |

Passwörter: beim Anlegen mit `createCSRUser` gesetzt; historisch zwei „Stile“ auf Servern möglich — **keine** festen Werte in dieser zentralen Übersicht, außer dem **CSR-Dev-Hinweis** in `admin-portal/CSR_LOGIN_ANLEITUNG.md` (dort: früheres gemeinsames Testpasswort auf internen Dev-Hosts, falls noch unverändert).

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

## 5. Portal-Admins anlegen / Passwort setzen (Finance, Technisch, Compliance)

Auf dem Parse-Host (Docker), jeweils mit **eigenem** Passwort (`BA_PASSWORD`). Optional dieselbe Variable in **`scripts/.env.server`** (gitignored), Vorlage **`scripts/.env.server.example`**.

**Hinweis:** Wenn `BA_PASSWORD` in `.env.server` steht, gilt sie für **den jeweils aufgerufenen** Bootstrap — vor dem nächsten Skript ggf. Zeile anpassen oder Passwort inline setzen.

### Finance Admin (`business_admin`)

```bash
BA_EMAIL=finance@fin1.de BA_PASSWORD='<Ihr gewähltes Passwort>' bash scripts/create-business-admin.sh
```

### Technischer Admin (`admin`)

```bash
BA_PASSWORD='<Ihr gewähltes Passwort>' bash scripts/create-tech-admin.sh
# Standard-E-Mail: admin@fin1.de — oder z. B. BA_EMAIL=ops@fin1.de …
```

### Compliance-Admin (`compliance`)

```bash
BA_PASSWORD='<Ihr gewähltes Passwort>' bash scripts/create-compliance-admin.sh
# Standard-E-Mail: compliance@fin1.de — oder BA_EMAIL=…
```

Ohne `BA_PASSWORD` in der Shell (und ohne gesetztes `BA_PASSWORD` nach dem Laden von `scripts/.env.server`) brechen die Skripte mit Hinweis ab.

Wenn der User **schon existiert**, greifen `createAdminUser` und **`forcePasswordReset: true`** in den Skripten; Details siehe `WEB_PANEL_LOGIN_CREDENTIALS.md`.

---

## Quellen im Repository

| Thema | Pfad |
|-------|------|
| Finance-Admin-Skript | `scripts/create-business-admin.sh` |
| Technischer-Admin-Skript | `scripts/create-tech-admin.sh` |
| Compliance-Admin-Skript | `scripts/create-compliance-admin.sh` |
| iOS-Test-Passwort-Konstante | `FIN1/Shared/Constants/TestUserConstants.swift` |
| Seed Investoren/Trader | `backend/parse-server/cloud/functions/seed/users.js` |
| Portal-Login-Copy (Dev-UI) | `admin-portal/src/constants/portalLogin.ts` |
