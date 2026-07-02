# Dev-Portal-Login — Single Source of Truth (Übersicht)

**Gültigkeit:** Entwicklung / interne iobox (keine Produktions-Secrets im Git).

Diese Seite ist die **einzige** Doku, die beschreibt, **wo** welche Zugangsdaten für das Web-Portal herkommen. Konkrete Passwörter gehören nur in gitignorierte Dateien (`scripts/.env.server`) oder in die genannten Skript-Arrays — nicht in kopierfertiger Form in weitere Markdown-Dateien duplizieren.

---

## 1. Kanonische **E-Mails & Rollen** (committed, eine Quelle)

| Nutzergruppe | Quelle im Repo |
|----------------|----------------|
| **3 Portal-Admins** (Technisch, Finance, Compliance) | `admin-portal/src/constants/portalLogin.ts` → `PORTAL_DEV_PORTAL_ACCOUNTS` |
| **CSR-Postfächer** (nur E-Mail, keine Passwörter in TS) | dieselbe Datei → `PORTAL_DEV_CSR_ACCOUNTS` |

Die **Dev-Login-Box** auf `/admin/login` (nur `import.meta.env.DEV`) liest dieselben Konstanten — damit UI und Doku nicht auseinanderlaufen.

---

## 2. Passwörter — wo sie **gesetzt** werden (Dev)

### Portal-Admins (`admin`, `business_admin`, `compliance`)

- **Ein gemeinsames Operator-Passwort** für alle drei Bootstrap-Läufe: Variable **`BA_PASSWORD`** in **`scripts/.env.server`** (Vorlage: `scripts/.env.server.example`, Datei ist gitignored).
- **Am Mac (interaktiv, Eingabe versteckt):** vom Repo-Root `./scripts/configure-local-ba-password.sh` — schreibt/aktualisiert nur `BA_PASSWORD` in `scripts/.env.server` (gitignored).
- Auf dem Parse-Host nacheinander ausführen (jeweils mit demselben `BA_PASSWORD` in `.env.server` oder inline):

  ```bash
  bash scripts/create-tech-admin.sh
  bash scripts/create-business-admin.sh
  bash scripts/create-compliance-admin.sh
  ```

- Damit sind **E-Mail** (SSOT oben) und **Passwort** (nur `.env.server`) klar getrennt; du musst nicht drei verschiedene Doku-Dateien pflegen.

### CSR (`customer_service`)

- **Passwörter und Namen** für das Anlegen per Cloud Function: **`backend/scripts/create_csr_users.js`** → Konstante **`CSR_USERS`** (einzige Stelle im Repo für CSR-**Passwort**-Strings in Dev).
- E-Mail-Spalte dort muss mit **`PORTAL_DEV_CSR_ACCOUNTS`** übereinstimmen; bei neuen CSR-Zeilen beide Stellen anpassen.

---

## 3. Weitere Doku (ohne Passwort-Duplikate)

| Thema | Datei |
|--------|--------|
| Rollen, Skripte, iOS-Testuser (ohne Passwort-SSOT) | `Documentation/DEV_LOGIN_ACCOUNTS.md` |
| CSR-URLs & Hinweise zu Kleinbuchstaben / historischem Testpasswort | `admin-portal/CSR_LOGIN_ANLEITUNG.md` |

---

## 4. Smoke / SSH-Tunnel vom Mac

- **LAN:** `./scripts/smoke-admin-get-user-details.sh` (liest `BA_PASSWORD` aus `scripts/.env.server`).
- **Commission 4-Augen E2E (global):** `./scripts/smoke-commission-rate-bundle-e2e.sh` (admin beantragt → finance genehmigt → Revert; optional `SMOKE_APPROVER_PASSWORD` wenn Approver-Passwort abweicht).
- **Per-user Overrides 4-Augen E2E:** `./scripts/smoke-user-commission-rate-bundle-e2e.sh`, `./scripts/smoke-user-app-service-charge-e2e.sh`, `./scripts/smoke-user-open-depot-limit-e2e.sh` (Antrag auf Benutzer-Detail → zweiter Admin genehmigt → `getUserDetails` prüft Controls → Revert). SSOT: [`COMMISSION_OVERRIDE_REFERENCE.md`](COMMISSION_OVERRIDE_REFERENCE.md).
- **Legal App-Name 4-Augen E2E:** `./scripts/smoke-legal-app-name-e2e.sh` (`legalAppName` via `requestConfigurationChange` → `approveRequest` → Revert).
- **Nach Deploy (automatisch):** Parse-Cloud-Deploy und Admin-Portal-Deploy rufen `./scripts/post-deploy-smoke.sh` auf (`POST_DEPLOY_SMOKE=0` zum Überspringen; Profile: `full` | `admin` | `parse`).
- **SSH-Tunnel** (Terminal 1 offen lassen): `ssh -L 8443:127.0.0.1:443 io@192.168.178.20`  
  Terminal 2: `PARSE_URL=https://127.0.0.1:8443/parse ./scripts/smoke-admin-get-user-details.sh`

---

## 5. Kurz-Checkliste nach „wir erinnern uns nicht mehr“

- **Account lockout (Parse):** nach 3 Fehlversuchen ~5 Min. Sperre. Master-Key-Freigabe: Cloud Function `unlockParseAccountLockout` mit `{ "email": "…@fin1.de" }` — oder auf dem Parse-Host `reset-portal-login.sh` (setzt Passwort neu + Lockout weg).

1. Admins: `./scripts/configure-local-ba-password.sh` (Mac) oder `BA_PASSWORD='…'` in `scripts/.env.server`, dann drei `create-*-admin.sh` auf dem Server ausführen.  
2. Compliance vergessen: nur `create-compliance-admin.sh` mit neuem `BA_PASSWORD` reicht.  
3. CSR: `node backend/scripts/create_csr_users.js` gegen eure Parse-URL + Master Key (siehe Skript-Kopf), oder Passwörter in `CSR_USERS` anpassen und Skript erneut laufen lassen.
