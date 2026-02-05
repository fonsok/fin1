# FIN1 – Server‑Driven Legal Docs & Audit‑Trail

## Ziele

- **Server‑driven** Auslieferung von Rechtstexten (AGB/Datenschutz/Impressum)
- **Hybrid-Fallback** in der App (Server → Cache → Bundled)
- **Audit‑Trail**: intern nachvollziehbar, welche **App‑Version** welche **Dokument‑Version** (inkl. optionalem Hash) **ab wann** erhalten/angezeigt hat
- **Consent‑Audit**: Akzeptanz wird append‑only gespeichert (optional auch ohne Login, über `deviceInstallId`)

## Backend (Parse Cloud Code)

### Cloud Functions

- `getCurrentTerms(language, documentType)`
  - `language`: `"en" | "de"`
  - `documentType`: `"terms" | "privacy" | "imprint"`
  - Rückgabe: `{ version, effectiveDate, documentHash, sections, ... }`

- `logLegalDocumentDelivery(...)`
  - schreibt **Delivery Audit** in `LegalDocumentDeliveryLog`
  - dedupliziert serverseitig (gleiches Gerät/App/Dokument/Version innerhalb 24h)

- `recordLegalConsent(...)`
  - schreibt **Consent Audit** in `LegalConsent`

### Parse Klassen (MongoDB / Parse)

#### 1) `TermsContent` (Source of Truth)

Pflichtfelder:
- `version` (String)
- `language` (String: `en|de`)
- `documentType` (String: `terms|privacy|imprint`)
- `effectiveDate` (Date)
- `isActive` (Boolean)
- `sections` (Array von `{ id, title, content, icon }`)

Automatisch (Trigger):
- `documentHash` (SHA‑256 über kanonisierten Inhalt)

Security (Best Practice):
- `TermsContent` ist **server-managed**: `beforeSave` blockt Writes ohne Master Key.
- `LegalDocumentDeliveryLog` und `LegalConsent` sind **append-only server-managed**: Writes ohne Master Key werden geblockt.

Immutability (Audit Best Practice):
- `TermsContent` ist **append-only**: bestehende Rechtstexte werden **nicht** editiert.
- Aktivierung/Deaktivierung erfolgt nur über `isActive` (altes Dokument wird deaktiviert, neues aktiviert).

Server-side Rendering (iOS/Audit clean):
- Platzhalter wie `{{LEGAL_*}}` und `{{COMMISSION_RATE}}` werden **serverseitig** beim Speichern von `TermsContent` aufgelöst.
- Dadurch entspricht `documentHash` dem **tatsächlich ausgelieferten/angezeigten Text** (keine clientseitigen Mutationen).

Bundled Fallback (iOS):
- Falls die App auf **Bundled** zurückfällt (kein Server/Cache), stammen Kontakt-E-Mails aus `CompanyContactInfo`:
  - `CompanyContactInfo.email` (allgemein)
  - `CompanyContactInfo.privacyEmail` / `CompanyContactInfo.dpoEmail` (Datenschutz)
  - Diese Werte sind per Info.plist überschreibbar (`LegalCompanyEmail`, `LegalPrivacyEmail`, `LegalDPOEmail`).

### Server-Konfiguration (ENV-Keys)

**Wo setzen?**
- Ubuntu / Docker (Prod): Datei `backend/.env` (wird via `docker-compose.production.yml` als `env_file` in den `parse-server` Container geladen).
- Nach Änderung: `docker compose -f docker-compose.production.yml restart parse-server`

**Wichtig (Audit):**
- Diese Werte dürfen sich inhaltlich ändern, aber dann muss das über eine **neue** `TermsContent` Version passieren (append-only), z.B. via `scripts/clone_termscontent_version_parse.py`.
- Historische `TermsContent` niemals in-place verändern.

**Verfügbare Keys (mit Defaults):**
- `FIN1_LEGAL_COMMISSION_RATE_PERCENT` (z.B. `10`)
- `FIN1_LEGAL_PLATFORM_NAME` (z.B. `FIN1`)
- `FIN1_LEGAL_COMPANY_LEGAL_NAME` (z.B. `FIN1 Investing GmbH`)
- `FIN1_LEGAL_COMPANY_ADDRESS`
- `FIN1_LEGAL_COMPANY_CITY`
- `FIN1_LEGAL_COMPANY_ADDRESS_LINE`
- `FIN1_LEGAL_COMPANY_REGISTER_NUMBER`
- `FIN1_LEGAL_COMPANY_VAT_ID`
- `FIN1_LEGAL_COMPANY_MANAGEMENT`
- `FIN1_LEGAL_BANK_NAME`
- `FIN1_LEGAL_BANK_IBAN`
- `FIN1_LEGAL_BANK_BIC`
- `FIN1_LEGAL_COMPANY_EMAIL`
- `FIN1_LEGAL_COMPANY_PHONE`
- `FIN1_LEGAL_COMPANY_WEBSITE`

#### 2) `LegalDocumentDeliveryLog` (append‑only)

Empfohlene Felder (werden aus Cloud Function gesetzt):
- `documentType`, `language`
- `servedVersion`, optional `servedHash`
- `source` (`server|cache|bundled`)
- `platform`, `appVersion`, `buildNumber`
- `deviceInstallId` (pseudonym)
- optional `userId` (String)
- Kontext: `ipAddress`, `userAgent`, optional `servedAt`

#### 3) `LegalConsent` (append‑only)

Felder:
- `consentType` (`terms_of_service|privacy_policy|imprint`)
- `version`, optional `documentHash`, optional `documentUrl`
- `accepted` (Boolean), `acceptedAt` (Date)
- `platform`, `appVersion`, `buildNumber`, `deviceInstallId`
- optional `userId` (String)
- Kontext: `ipAddress`, `userAgent`

## App (Swift) – Hybrid Client

### Implementiert

- `FIN1/Shared/Services/ParseAPIClient.swift`
  - ergänzt um `callFunction(_:parameters:)`

- `FIN1/Shared/Services/TermsContentService.swift`
  - Fetch: `getCurrentTerms`
  - Cache: `UserDefaults`
  - Delivery‑Logging: `logLegalDocumentDelivery` (sparsam dedupliziert)

- `FIN1/Shared/ViewModels/TermsOfServiceViewModel.swift`
  - nutzt server‑driven Terms, wenn verfügbar, sonst Bundled

- `FIN1/Shared/ViewModels/PrivacyPolicyViewModel.swift`
  - nutzt server‑driven Privacy, wenn verfügbar, sonst Bundled

- `FIN1/Shared/ViewModels/ImprintViewModel.swift`
  - lädt server‑driven Impressum (Server → Cache → Bundled) und loggt Delivery

- `FIN1/Shared/Components/Profile/Components/Modals/ImprintView.swift`
  - eigener Impressum‑Screen (Profil + Landing verlinkt)

- `FIN1/Shared/ViewModels/TermsAcceptanceViewModel.swift`
  - recordet Consent in `LegalConsent` (best effort)

## Ops / Rollout (kurz)

1. **Parse Server deployen/restarten**, damit Cloud Code `functions/legal.js` + `triggers/legal.js` geladen werden.
2. In **Parse Dashboard** `TermsContent` anlegen:
   - `documentType = "terms"`, `language = "de"`, `version = "1.0"`, `effectiveDate`, `isActive = true`, `sections = [...]`
   - analog für `privacy` und optional `imprint`
3. App öffnen → Terms/Privacy aufrufen → es sollten Einträge in:
   - `LegalDocumentDeliveryLog`
   - `LegalConsent` (bei Akzeptanz)
4. Optional: **CLPs** so setzen, dass nur Admin/Server schreiben darf (Public read für `TermsContent`, Create-only für Logs).

### Praktische Seeding-Skripte

- `scripts/apply_termscontent_sections_to_parse.py`
  - updatet `TermsContent.sections` für ein einzelnes `(documentType, language)` (Master Key via server `.env`)
- `scripts/imprint_de_sections.json`
  - Template für ein vollständigeres Impressum (mit Platzhaltern `{{LEGAL_*}}`)
- `scripts/clone_termscontent_version_parse.py`
  - erstellt eine **neue** TermsContent Version (append-only) und deaktiviert die vorherige aktive Version

