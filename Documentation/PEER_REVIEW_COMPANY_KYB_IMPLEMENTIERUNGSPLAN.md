# Peer Review: Company-KYB (KYB juristische Person) – Implementierungsplan & Stand

**Zielgruppe:** Senior Full-Stack-Developer / Lead Full-Stack-Engineer (externer fachlicher Review)  
**Sprache:** Deutsch  
**Stand:** März 2026 (Repo FIN1)

---

## 1. Zweck dieses Dokuments

Dieses Dokument fasst **Entscheidungen, Architektur und Umsetzungsstand** für das **Company-Onboarding (KYB)** in der FIN1-Plattform zusammen. Es soll als **Diskussionsgrundlage** dienen: Feedback zu **Vollständigkeit**, **Risiken**, **Skalierbarkeit**, **Sicherheit** und **API-Design** ist ausdrücklich erwünscht.

---

## 2. Kurzüberblick (Executive Summary)

| Thema | Inhalt |
|--------|--------|
| **Problem** | Juristische Personen als **Investor** brauchen ein **KYB** (Know Your Business), getrennt vom **persönlichen KYC** (natürliche Person). |
| **Ansatz** | Eigene **Parse-User-Felder**, eigene **Cloud Functions**, eigene **Joi-Schemas**, eigene **Audit-/Progress-Klassen** – analog zum bestehenden Personal-Onboarding, aber **nicht** gemischt mit `onboardingStep` / `onboardingCompleted`. |
| **Scope Produkt** | **Nur Investor + `accountType == company`**; kein Trader-Flow für Firmen. |
| **Phasen** | **P0** Spez/ADR ✅ · **P1** Backend + Joi + iOS-DTO/API-Skeleton ✅ · **P2** SwiftUI-Wizard + Routing · **P3** Admin/CSR, Vier-Augen, harte Tests |
| **Plattform-Stand** | Detailliert: **§6** iOS-App · **§7** Parse/Cloud Code · **§8** Web-Admin & CSR |

---

## 3. Geschäfts- und Produktkontext

### 3.1 Warum getrennt?

- **KYC** deckt die **natürliche Person** (Identität, Adresse, Erfahrung, Risiko, …) ab.
- **KYB** deckt die **juristische Person** ab (Register, UBOs, Vertretung, Firmendokumente, Erklärungen).
- Eine Vermischung in einem Wizard oder in denselben `User`-Feldern würde **Compliance**, **Audit** und **UI-Resume** unnötig verkomplizieren.

### 3.2 Wichtige Produktregeln (eingefroren in der Spezifikation)

- **Kein Parallelbetrieb** zweier aktiver Wizards: fachlich entweder Fokus auf Personal-Onboarding **oder** Company-KYB (Resume-Logik priorisiert KYB für Firmenkonten, solange KYB offen).
- **Server ist maßgeblich** für Validierung und spätere Prüfprozesse (Vier-Augen etc. in späteren Phasen).

**Referenz:** [`Documentation/COMPANY_KYB_ONBOARDING.md`](COMPANY_KYB_ONBOARDING.md)

---

## 4. Architekturentscheidungen (ADR)

| ADR | Inhalt |
|-----|--------|
| **ADR-002** | Personal-Onboarding: Codable auf iOS, **Joi** serverseitig, `sanitizeObject` vor Validierung. |
| **ADR-003** | Company-KYB: **eigene** Felder und APIs; **8 feste Schritte**; Resume-Regel für `company` + offenes KYB. |

**Referenz:** [`Documentation/ADR-003-Company-KYB-Onboarding.md`](ADR-003-Company-KYB-Onboarding.md)

---

## 5. Technischer Stack (relevant)

| Schicht | Technologie |
|---------|-------------|
| **Backend** | Parse Server (Node), Cloud Functions (`Parse.Cloud.define`), REST `POST /parse/functions/<name>` |
| **Validierung** | **Joi** (`joi`), pro Schritt in `companyKybStepSchemas.js` |
| **Sanitizing** | `sanitizeObject` / `sanitize` in `validation.js` (Strings trimmen, Steuerzeichen) |
| **Persistenz** | `Parse.User` + Klassen **`CompanyKybProgress`** (Zwischenstände), **`CompanyKybAudit`** (abgeschlossene Schritte) |
| **iOS (P1)** | Swift, `Codable`-DTOs, `CompanyKybAPIService` über bestehenden `ParseAPIClient` (`callFunction`) |
| **DI** | `AppServices` / `AppServicesBuilder` – Service wie `OnboardingAPIService` injiziert |

---

## 6. Frontend (iOS-App) – aktuelle Situation

### 6.1 Rolle der App

- **Haupt-Frontend** für Endkund:innen (**Investor**, **Trader**): native **SwiftUI**-App (`FIN1/`), Zielplattform iOS.
- **Architektur:** **MVVM**, Dependency Injection über **`AppServices`** / `Environment(\.appServices)` (Composition Root u. a. `FIN1App.swift`); Services sprechen **`ParseAPIClient`** per REST (`callFunction`, …) an.
- **Backend-Integration:** Protokoll-basiert (`*ServiceProtocol`), async/await; viele Features haben eigene `Features/<Feature>/`-Struktur (Models, Views, ViewModels, Services).

### 6.2 Personal-Onboarding (KYC) – Stand heute

- **Flow:** Registrierung / **`SignUpView`** mit **`SignUpCoordinator`**, mehrere Schritte (persönliche Daten, Adresse, Steuer, Erfahrung, Risiko, Zustimmungen, Verifikation, …).
- **API:** **`OnboardingAPIService`** (`getOnboardingProgress`, `saveOnboardingProgress`, `completeOnboardingStep`, E-Mail-/SMS-Codes) – aktiv in Coordinator-Persistenz und Verifikation eingebunden (`onboardingAPIService` wird an `SignUpView`/`SignUpCoordinator` durchgereicht).
- **DTO:** `SavedOnboardingData` / `OnboardingProgress` – spiegeln das **Personal-KYC**, nicht Firmendaten.

### 6.3 Company-KYB – Stand heute (nach P1)

| Aspekt | Status |
|--------|--------|
| **API-Schicht** | `CompanyKybAPIService` + `SavedCompanyKybData` etc. sind implementiert und in **`AppServices.companyKybAPIService`** (live mit `ParseAPIClient`) registriert. |
| **UI / Wizard** | **Nicht** angebunden: Es gibt **keinen** SwiftUI-Wizard, **keine** Aufrufe aus `SignUpView`/`AuthenticationView`/`LandingView` für die KYB-Functions – **Phase P2**. |
| **Routing / Resume** | Spezifiziert (Company-KYB vor Personal-Onboarding bei `accountType == company` & offenem KYB), aber **noch nicht** in der Navigationslogik umgesetzt. |
| **In-App-„Admin“** | **`AdminDashboardView`** (nur für Admin-Rollen in der App): Hinweis, dass **Konfiguration, Reports und Operatives** über das **Web-Admin-Portal** laufen – die iOS-App ist hier bewusst **kein** vollwertiges Admin-Tool. |

### 6.4 Kurzfazit Frontend

- **Personal-KYC:** produktiv durchgängig (App ↔ Cloud Functions).  
- **Company-KYB:** **Backend-Vertrag + iOS-DTO/Service** vorhanden; **Nutzerführung und Screens** fehlen noch – das ist der größte Lücken-Block vor einem testbaren End-to-End-Flow.

---

## 7. Backend (Parse Server & Cloud Code) – aktuelle Situation

### 7.1 Einordnung

- **Laufzeit:** **Node.js** (Parse Server 6.x im Repo), zentral unter `backend/parse-server/`.
- **Einstieg Cloud Code:** `backend/parse-server/cloud/main.js` lädt u. a. **Trigger** (`triggers/`), **Functions** (`functions/`), Hilfsmodule (`utils/`).
- **User-Funktionen:** `backend/parse-server/cloud/functions/user.js` bindet Module ein, u. a. **`onboarding.js`** (Personal-KYC) und **`companyKyb.js`** (Company-KYB).

### 7.2 Personal-Onboarding vs. Company-KYB im Code

| Bereich | Personal (KYC) | Company (KYB) |
|---------|------------------|----------------|
| **Cloud Functions** | `getOnboardingProgress`, `saveOnboardingProgress`, `completeOnboardingStep`, … | `getCompanyKybProgress`, `saveCompanyKybProgress`, `completeCompanyKybStep` |
| **Joi** | `onboardingStepSchemas.js` → `validation.js` (`validateStepData` / `validatePartialOnboardingData`) | `companyKybStepSchemas.js` → `validateCompanyKybStepData` / `validatePartialCompanyKybData` |
| **Parse-Klassen** | `OnboardingProgress`, `OnboardingAudit` | `CompanyKybProgress`, `CompanyKybAudit` |
| **Tests** | Jest: `onboardingStepSchemas.test.js` | Jest: `companyKybStepSchemas.test.js` |

### 7.3 Weitere Backend-Bausteine (Kontext)

- Viele **domänenspezifische** Cloud Functions (Investments, Trading, Reports, Support, **Configuration** / Vier-Augen, Legal, 2FA, …) – das Admin-Web-Portal und die App hängen davon ab.
- **Separates** Projekt `backend/market-data/` (eigenes `package.json`) für Marktdaten – orthogonal zu KYB, aber Teil der Gesamt-Plattform.
- **Validierung:** zentrale `sanitizeObject`-Pipeline vor Joi; **Health** u. a. über Cloud Function `health`, Konfiguration über `getConfig` (u. a. `Configuration`-Klasse, Admin/4-Augen).

### 7.4 Kurzfazit Backend

- **KYB ist serverseitig in P1 implementiert** (Functions + Validierung + Audit/Progress-Pattern).  
- **Betrieb:** neue **`User`-Felder** und Klassen müssen im jeweiligen **Parse-Schema** freigeschaltet sein; **ACL/Master-Key-Nutzung** in Cloud Functions ist mit Operations/Compliance abzustimmen.

---

## 8. Web-Admin-Portal & CSR – aktuelle Situation

### 8.1 Was ist das „Admin“-Frontend?

- **Projekt:** `admin-portal/` – **React 18 + TypeScript**, **Vite**, **TailwindCSS**, **TanStack Query**, **React Router v6**.
- **Deployment:** typischerweise unter **`/admin`** (Nginx SPA-Fallback); Beispiel-URL und Hinweise in Repo-Doku (`admin-portal/README.md`, `Documentation/FIN1_APP_DOCS/10_ADMIN_PORTAL_REQUIREMENTS.md`).
- **API:** **Direkte REST-Aufrufe** an den Parse Server (`POST /parse/functions/<name>`, Session-Token), zentral z. B. über `src/api/parse.ts` (`cloudFunction`); **kein** Parse-JS-SDK im Bundle (Vite-Kompatibilität – siehe Cursor-Rule `admin-portal`).

### 8.2 Rollen und Oberflächen

- **Admin-Portal** (`/login`, geschützte Routen): für Rollen wie **admin**, **business_admin**, **security_officer**, **compliance** – u. a. Dashboard, Benutzer, Tickets, Compliance, Finance, Security, Freigaben, Audit, **Configuration**, Reports, **App-Ledger**, System, Templates, FAQs, AGB/Rechtstexte, …
- **CSR-Portal** (separates Layout, u. a. unter **`/csr/*`**): für **customer_service** – Tickets, Kunden, KYC-Ansichten, Analytics, Templates, FAQs – **kein** Zugriff auf volle Admin-Finance/Security-Navigation (Guards).

### 8.3 Bezug zum Onboarding / KYC

- Es gibt eine **Onboarding-Funnel**-Seite (`OnboardingFunnelPage`, u. a. Route `/onboarding`), die **`getOnboardingFunnel`** nutzt – Fokus **Personal-Onboarding** (Schritt-Labels wie `personal`, `address`, `experience`, … in `OnboardingFunnel.tsx`).
- **Benutzer-Detail**-Ansichten im Admin behandeln **KYC** im Support-Sinne (Profil, Status) – **keine** dedizierte **Company-KYB**-Maske oder eigener KYB-Funnel im Web-Frontend **Stand jetzt**.

### 8.4 Company-KYB im Web-Admin – Lücke (bewusst / P3)

| Thema | Stand |
|--------|--------|
| **UI** | Keine Seite „Company KYB“, keine Anzeige von `companyKybStatus` / `companyKybStep` in einer dedizierten Ansicht (außer ggf. generische User-Felder, falls manuell im Dashboard gepflegt). |
| **Cloud Functions** | Die neuen Functions **`getCompanyKybProgress` / `save*` / `complete*`** sind **nicht** in der dokumentierten Admin-API-Tabelle in `10_ADMIN_PORTAL_REQUIREMENTS.md` als vom Portal genutzt aufgeführt (dort: `searchUsers`, `getUserDetails`, …). |
| **CSR** | Kein eigener **KYB-Review-Workflow** analog zu späteren Compliance-Anforderungen – **Phase P3** (Admin/CSR, Vier-Augen, ggf. Queue für `pending_review`). |

### 8.5 Kurzfazit Web-Admin

- Das Web-Frontend ist **reif für Betrieb** (MVP+ laut interner Doku: Dashboard, User, Compliance, Freigaben, Finance, …).  
- **Company-KYB** ist dort **noch nicht** als Produktfeature sichtbar – End-to-End geht aktuell nur über **API/Tests** bzw. Parse-Dashboard, bis **P2 (App)** und **P3 (Admin/CSR)** nachziehen.

---

## 9. Kanonische Schrittliste (Backend-Keys)

Reihenfolge ist **fix** (Wizard, `validSteps`, Validierung):

1. `legal_entity` – Unternehmen (Firma, Rechtsform, Register, …)  
2. `registered_address` – eingetragener Sitz / Anschrift  
3. `tax_compliance` – USt-Id, Steuernummern, Kennzeichen „keine USt-Id“, …  
4. `beneficial_owners` – UBOs oder Erklärung „kein UBO über 25 %“  
5. `authorized_representatives` – Vertretung  
6. `documents` – Nachweise (Metadaten / Referenzen; Upload-Konzept über bestehende Dokumenten-/Storage-Idee)  
7. `declarations` – PEP, Sanktionen, Richtigkeit, …  
8. `submission` – **Einreichung** → serverseitig u. a. Status `pending_review`

---

## 10. Datenmodell (Kurz)

### 10.1 `Parse.User` (geplante / genutzte Felder für KYB)

| Feld | Bedeutung (Kurz) |
|------|-------------------|
| `accountType` | u. a. `company` für Firmenkonten |
| `role` | u. a. `investor` (Guard in Cloud Functions) |
| `companyKybStep` | aktueller Schritt-Key |
| `companyKybCompleted` | Boolean – Wizard abgeschlossen / eingereicht |
| `companyKybStatus` | z. B. `draft`, `pending_review`, später `approved`, … |
| `companyKybCompletedAt` | Zeitpunkt der Einreichung (bei `submission`) |
| `companyFourEyesRequestId` | optional, Verknüpfung zu Vier-Augen (später ausgebaut) |

### 10.2 Parse-Klassen

| Klasse | Rolle |
|--------|--------|
| `CompanyKybProgress` | `userId`, `step`, `data` (Object), `isPartial`, `updatedAt` – analog `OnboardingProgress` |
| `CompanyKybAudit` | `userId`, `step`, `completedAt`, `answers` (Snapshot für Audit) – analog `OnboardingAudit` |

**Hinweis für Betrieb:** Je nach Parse-Konfiguration müssen **Schema/ACL** im Dashboard oder per Migration angelegt werden – das ist ein **operativer** Punkt für Review.

---

## 11. Cloud Functions (API-Vertrag)

Alle drei Functions sind **session-basiert** (`X-Parse-Session-Token`). Zusätzlich gilt:

**Guard:** `accountType === 'company'` **und** `role === 'investor'` – sonst **`OPERATION_FORBIDDEN`**.

| Function | Zweck |
|----------|--------|
| `getCompanyKybProgress` | Liefert u. a. `currentStep`, `completedSteps` (aus Audit), `companyKybCompleted`, `companyKybStatus`, `savedData` (letzter `CompanyKybProgress`-Blob) |
| `saveCompanyKybProgress` | Params `{ step, data?, partial? }` – Zwischenstand; `data` bei Vorhandensein mit **partial Joi** |
| `completeCompanyKybStep` | Params `{ step, data }` – **`data` ist Pflicht**; **complete Joi**; schreibt Audit; bei `submission` setzt Server u. a. `companyKybCompleted`, `companyKybStatus` (z. B. `pending_review`) |

**Implementierung:** `backend/parse-server/cloud/functions/user/companyKyb.js`  
**Joi:** `backend/parse-server/cloud/utils/companyKybStepSchemas.js`  
**Wiring:** `backend/parse-server/cloud/utils/validation.js`, `require` in `backend/parse-server/cloud/functions/user.js`

---

## 12. Validierungsstrategie

- **Complete-Step:** Strikte Joi-Schemas für den **Abschluss** eines Schritts (Pflichtfelder pro Schritt, inkl. Custom-Regeln z. B. Steuern/UBO).
- **Partial-Save:** Nur Typ-/Form-Prüfung, wenn Keys gesendet werden – **keine** vollständigen Pflichtfelder, damit „Speichern & später fortsetzen“ möglich ist.
- **Payload-Größe:** Obergrenze analog Onboarding (z. B. ~50k JSON-Zeichen), um Missbrauch zu begrenzen.

**Tests (Jest):** `backend/parse-server/cloud/utils/__tests__/companyKybStepSchemas.test.js`

---

## 13. iOS (P1 – API-Skeleton, Kurzreferenz)

> Detaillierte Einordnung der **iOS-App** (Personal-KYC vs. KYB, fehlende UI): **Abschnitt 6**.

- **DTO:** `SavedCompanyKybData` (+ Unterstrukturen für UBO, Vertreter, Dokument-Manifest), alles optional für partial saves.
- **Service:** `CompanyKybAPIService` / `CompanyKybAPIServiceProtocol` – Spiegel der drei Cloud Functions; Encoding wie `SavedOnboardingData` → `encodeToJSONDictionary()`.
- **DI:** `AppServices.companyKybAPIService` (optional, live mit `ParseAPIClient`).

**Datei:** `FIN1/Features/Authentication/Services/CompanyKybAPIService.swift`

**Bewusst nicht in P1:** dedizierter SwiftUI-Wizard, `AuthenticationView`-Routing, Resume-UI – siehe Phase P2.

---

## 14. Phasen-Roadmap (Was ist wo?)

| Phase | Inhalt | Status (grob) |
|-------|--------|------------------|
| **P0** | Schrittliste, ADR, `COMPANY_KYB_ONBOARDING.md` | erledigt |
| **P1** | Parse-Felder (Konzept), Cloud Functions + Joi, iOS-Modelle + API, Doku-Schnitt `03_TECHNISCHE_SPEZIFIKATION` | **umgesetzt** (Backend + iOS-Service + Tests) |
| **P2** | 8-Schritt-Wizard, Resume, Navigation (`AuthenticationView` etc.) | offen |
| **P3** | Admin/CSR, Vier-Augen-Produktivierung, Last-/E2E-Tests, Policy-Parameter (Dokumentalter, …) | offen |

---

## 15. Dokumentation im Repo

| Dokument | Inhalt |
|----------|--------|
| [`Documentation/COMPANY_KYB_ONBOARDING.md`](COMPANY_KYB_ONBOARDING.md) | Produktregeln, Tabelle der Schritte, Cloud-Function-Namen |
| [`Documentation/ADR-003-Company-KYB-Onboarding.md`](ADR-003-Company-KYB-Onboarding.md) | Architekturentscheid |
| [`Documentation/FIN1_APP_DOCS/03_TECHNISCHE_SPEZIFIKATION.md`](FIN1_APP_DOCS/03_TECHNISCHE_SPEZIFIKATION.md) | API-Funktionen, Fehlercodes, Parse-Klassen (kurz) |

---

## 16. Vorschläge für den Review-Fokus (konkrete Fragen)

Die folgenden Punkte sind **explizit** als Input für einen Senior/Lead gedacht:

1. **API-Design:** Reicht die Spiegelung des Personal-Onboarding-Musters (`get*`, `save*`, `complete*`) für KYB, oder fehlt z. B. `idempotency`, `version` des Fragebogens oder `correlationId` für Support?
2. **Guard:** Nur `company` + `investor` – ist **„Trader mit Firmenanteil“** oder **Legacy-`accountType`-Werte** ausgeschlossen genug? Braucht es explizite Migration/Alias (`business` vs `company`)?
3. **Audit:** Reicht ein **reduziertes `answers`-Snapshot** pro Schritt für spätere Compliance, oder sollte **vollständiger Payload** (gehasht/gekürzt) gespeichert werden?
4. **Einreichung (`submission`):** Ist `pending_review` ohne weiteren **Workflow** (Queue, Benachrichtigung) aus Sicht Architektur noch konsistent, oder sollte die Function nur „draft“ setzen, bis ein Backend-Job läuft?
5. **Vier-Augen:** `companyFourEyesRequestId` optional – passt das **früh** zur späteren `FourEyesRequest`-Integration, oder sollte die Function erst **gar keinen** Vier-Augen-Platzhalter haben?
6. **Parallelität:** Wie verhindert man **konkurrierende** `save`/`complete` von zwei Clients (optimistische Locking, `updatedAt`-Check, `revision` auf User)?
7. **iOS:** `savedData` als verschachteltes JSON – **Decoding** bei variablen Keys: ist ein **flexibles** Modell (z. B. `AnyCodable` / `JSONValue`) für spätere Schema-Erweiterungen sinnvoller als striktes `Codable`?
8. **Sicherheit:** ACL für `CompanyKybProgress` / `CompanyKybAudit` – nur **Master Key** in Cloud Code vs. **User-lesbare** Objekte: welche Anforderung hat Compliance?
9. **Web-Admin / CSR:** Soll **`pending_review`** zwingend eine **sichtbare Queue** im Admin oder CSR-Portal auslösen (Welche Rolle bearbeitet KYB-Fälle?), oder reicht zunächst **Parse Dashboard** / manuelle Prozesse bis P3?

---

## 17. Bekannte Einschränkungen / Next Steps

- **UI/Routing** für KYB ist **nicht** in P1 enthalten.
- **Parse-Schema** (neue Felder/Klassen) muss im Ziel-Deployment **verifiziert** werden.
- **Legal/Compliance** sollte Pflichtfelder und Dokument-Policy (Alter, Formate) **final** benennen; Joi kann daran angepasst werden.

---

## 18. Kontakt für Rückfragen

Dieses Dokument beschreibt den **Plan und den implementierten P1-Stand** im Repo; technische Details sind in den oben verlinkten Dateien nachvollziehbar.

---

*Dokument für Peer Review erstellt zur externen fachlichen Einordnung des Company-KYB-Implementierungsplans (FIN1).*
