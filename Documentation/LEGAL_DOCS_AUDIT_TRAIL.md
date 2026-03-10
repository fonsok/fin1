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

**Admin (nur mit Berechtigung `manageTemplates`):**
- `listTermsContent(documentType?, language?)` – listet TermsContent-Versionen, optional gefiltert nach `documentType` (`terms`|`privacy`|`imprint`) und/oder Sprache
- `getTermsContent(objectId)` – liefert eine Version inkl. `sections` zum Klonen/Bearbeiten
- `createTermsContent({ version, language, documentType, effectiveDate, isActive, sections })` – legt eine neue Version an (append-only)
- `setActiveTermsContent(objectId)` – setzt die angegebene Version für ihren `documentType`+`language` als aktiv, deaktiviert die bisher aktive
- `getDefaultLegalSnippetSections(language)` – liefert die Standard-Abschnitte für Legal Snippets (DE/EN) zur Verwendung beim Anlegen einer neuen Version (z. B. „Snippet-Abschnitte einfügen“ im Admin)

**Öffentlich (ohne Auth, nur statische Daten):**
- `getDefaultLegalSnippetSectionsPublic(language)` – gleiche Daten wie oben; für Seed-Skripte und automatisierte Anreicherung einer AGB-Version um die Snippet-Abschnitte

### Admin Panel „AGB & Rechtstexte“

Im Admin- bzw. CSR-Web-Portal ist unter der Navigation **„AGB & Rechtstexte“** die Verwaltung aller drei Dokumenttypen möglich:

- **Filter:** Dokumenttyp (AGB / Terms, Datenschutz, Impressum) und Sprache (DE/EN). Die Statistik-Karte zeigt den gewählten Typ mit lesbarem Label (z. B. „Datenschutz“).
- **Aktionen:** Neue Version (leer), Klonen aus bestehender Version, „Als aktiv setzen“. Es werden nur neue Versionen angelegt (append-only); bestehende werden nicht editiert.
- **Leerzustand:** Bei fehlenden Einträgen erscheint eine typ-spezifische Meldung (z. B. „Keine Datenschutz-Versionen gefunden“) mit Hinweis auf „+ Neue Version (leer)“ oder Klonen.

Die gleichen Cloud Functions (`listTermsContent`, `getTermsContent`, `createTermsContent`, `setActiveTermsContent`) und Trigger (Audit, Immutability) gelten unabhängig davon, ob eine Version über das Panel oder per Script angelegt wird. Im Panel stehen pro Version u. a. Anzeige von „Gültig ab“ und „Aktualisiert“ (mit Datum und Uhrzeit), pro Abschnitt ein **„Bearbeiten“‑Button** (öffnet Editor mit Fokus auf diesen Abschnitt), eine **Suchfunktion** in der Abschnittsliste und im Editor sowie **„Änderungen zur Vorgängerversion“** (Vergleich mit der vorherigen Version: hinzugefügt/entfernt/geändert).

**Seed-Skript für Legal Snippets:** Im Backend liegt `scripts/seed-legal-snippets.js`. Es holt die aktive AGB-Version (terms/de), mergt die Standard-Snippet-Abschnitte (ohne bestehende Abschnitte zu überschreiben) und legt eine neue TermsContent-Version an (zunächst inaktiv). Nach dem Lauf im Admin unter „AGB & Rechtstexte“ die neue Version öffnen und „Als aktiv setzen“ wählen. Aufruf (aus `backend/scripts`): `PARSE_SERVER_URL=… PARSE_APP_ID=… PARSE_MASTER_KEY=… node seed-legal-snippets.js` (Master Key ggf. aus `parse-server/.env`).

### Legal Snippets (Kurz-Hinweise in der App)

Zusätzlich zu den Haupt-Abschnitten der AGB können in der aktiven **TermsContent**-Version (documentType `terms`) weitere Abschnitte mit festen `section.id`-Keys angelegt werden. Die App lädt diese über `LegalSnippetProvider` und blendet sie an den jeweiligen Stellen ein; wenn kein passender Abschnitt existiert, wird der im Code hinterlegte Default verwendet (Fallback).

| section.id | Verwendungsort | Platzhalter (optional) |
|------------|----------------|------------------------|
| `dashboard_risk_note` | Dashboard, Risikohinweis | `{{MAX_RISK_PERCENT}}` |
| `order_legal_warning_buy` | Kauf-Order, Rechtliche Hinweise | – |
| `order_legal_warning_sell` | Verkauf-Order, Rechtliche Hinweise | – |
| `doc_tax_note_sell` | Dokumente (Collection Bill, Gutschrift): Steuerhinweis Verkauf | `{{TAX_RATE}}` |
| `doc_tax_note_buy` | Rechnungen (Kauf): Steuerhinweis | `{{TAX_RATE}}` |
| `doc_legal_note_wphg` | Dokumente: Rechtlicher Hinweis (WpHG/WpDVerOV) | – |
| `doc_tax_note_service_charge` | Rechnungen: Servicegebühr, Steuerhinweis | `{{VAT_RATE}}` |
| `riskclass7_max_loss_warning` | Onboarding: RiskClass7-Bestätigung – Totalverlustrisiko | – |
| `riskclass7_experienced_only` | Onboarding: RiskClass7-Bestätigung – nur für erfahrene Anleger | – |
| `doc_collection_bill_reference_info` | Collection Bill (Trader): Referenztext zum Steuerabzug / Differenzbetrag | – |
| `doc_collection_bill_legal_disclaimer` | Collection Bill (Trader): Rechtlicher Hinweis zu Abrechnung, Einspruch, Knock-out etc. | – |
| `doc_collection_bill_footer_note` | Collection Bill (Trader): Hinweis „maschinell erstellt, nicht unterschrieben“ / Kontakt Fin1-Service-Team | – |
| `account_statement_important_notice_de` | Kontoauszug / Account Statement: „Wichtige Hinweise“ (DE) | `{{LEGAL_COMPANY_*}}` (serverseitig) |
| `account_statement_important_notice_en` | Kontoauszug / Account Statement: „Important Notice“ (EN) | – |

Implementierung: `FIN1/Shared/Services/LegalSnippetProvider.swift`. Platzhalter werden clientseitig ersetzt (z. B. `{{TAX_RATE}}` → `CalculationConstants.TaxRates.capitalGainsTaxWithSoli`). **Überschriften:** Wo die App `snippet(for:defaultTitle:defaultContent:)` nutzt (z. B. Kontoauszug „Wichtige Hinweise“), wird `section.title` als Abschnittsüberschrift angezeigt; Titel und Inhalt sind im Admin unter AGB & Rechtstexte im jeweiligen Abschnitt bearbeitbar.

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

### Praktische Seeding-/Deployment-Skripte

- `scripts/export_legal_sections_from_swift.py`
  - exportiert die aktuellen Terms/Privacy-Sektionen aus den Swift-Quelldateien in JSON-Dateien
  - löst Swift-Interpolationen in Template-Platzhalter auf (`{{LEGAL_*}}`, `{{COMMISSION_RATE}}`, `{{CONTACT_*}}`)
- `scripts/deploy_updated_legal_docs.py`
  - erstellt **neue immutable** TermsContent-Versionen auf dem Server (GoB-konform: append-only)
  - **Pflichtfelder**: `--reason` (Begründung) und `--deployed-by` (Verantwortlicher) — für GoB Belegprinzip
  - erzeugt automatisch einen `AuditLog`-Eintrag (`legal_document_deployed_via_script`) mit vollständiger Nachvollziehbarkeit
  - deaktiviert die vorherige aktive Version
- `scripts/clone_termscontent_version_parse.py`
  - erstellt eine **neue** TermsContent Version (append-only) und deaktiviert die vorherige aktive Version
  - klont die bestehenden Sektionen (ohne Änderung)
- `scripts/apply_termscontent_sections_to_parse.py`
  - Legacy: updatet `TermsContent.sections` direkt (wird von Immutabilitäts-Trigger blockiert, wenn die Sektionen sich ändern)

### Workflow: Legal Docs aktualisieren

1. Swift-Quelldateien aktualisieren (z.B. `TermsOfServiceEnglishContent.swift`)
2. Export: `python3 scripts/export_legal_sections_from_swift.py --out-dir /tmp/legal-sections`
3. JSONs auf Server kopieren: `scp /tmp/legal-sections/*.json io@server:/tmp/legal-sections/`
4. Deploy auf Server: `python3 deploy_updated_legal_docs.py --input-dir /tmp/legal-sections --reason "..." --deployed-by "..."`
5. Verifizieren: `getCurrentTerms` aufrufen und Inhalt prüfen

## GoB-Compliance (Grundsätze ordnungsmäßiger Buchführung)

### Automatische Audit-Mechanismen

#### 1) `afterSave`-Trigger auf `TermsContent`
Egal wie eine neue Version entsteht (Admin-Portal, Script, Dashboard, direkte API) — es wird **automatisch** ein `AuditLog`-Eintrag erstellt:
- **`legal_document_version_created`** — bei jeder neuen Version (mit Hash, Sprache, Typ, Sektionen-Anzahl)
- **`legal_document_deactivated`** — wenn eine alte Version deaktiviert wird (`isActive: true → false`)

#### 2) Config-Reconciliation beim Server-Start
Bei jedem Neustart des Parse Servers wird automatisch geprüft, ob die **Code-Defaults** (`configHelper.js`) von den **DB-Werten** (`Configuration`-Klasse) abweichen. Bei Drift wird ein `AuditLog` mit `action: config_defaults_reconciliation` + allen Abweichungen geschrieben. Auch manuell aufrufbar via `reconcileConfigDefaults`.

#### 3) Löschschutz (Aufbewahrungspflicht)
Folgende Parse-Klassen sind durch `beforeDelete`-Trigger vor Löschung geschützt:
- `TermsContent` — Rechtstexte
- `LegalDocumentDeliveryLog` — Auslieferungs-Audit
- `LegalConsent` — Zustimmungs-Audit
- `ComplianceEvent` — Compliance-Events
- `AuditLog` — Audit-Protokoll
- `FourEyesRequest` — 4-Augen-Genehmigungen

### GoB-Prinzipien und ihre Umsetzung

| GoB-Prinzip | Umsetzung |
|---|---|
| **Belegprinzip** | Jede Änderung erzeugt AuditLog-Eintrag; Deploy-Script erfordert `--reason` + `--deployed-by` |
| **Zeitnähe** | AuditLog wird synchron bei jeder Aktion erstellt |
| **Nachvollziehbarkeit** | `afterSave`-Trigger fängt jeden Erstellungsweg ab; Config-Reconciliation erkennt Code-Drifts |
| **Unveränderlichkeit** | `TermsContent` immutabel (append-only); AuditLog löschgeschützt |
| **Aufbewahrungspflicht** | `beforeDelete`-Trigger auf allen audit-relevanten Klassen |
| **Ordnungsmäßigkeit** | 4-Augen-Prinzip für kritische Config-Parameter; Versionierung; SHA-256 Hash-Prüfung |

