# Company-Onboarding (KYB) – Spezifikation & Phasen

**Status:** Schrittliste **festgelegt** (siehe §3); Umsetzung in Phasen  
**Zielgruppe:** iOS, Backend, Compliance, Produkt  
**Bezug:** Persönliches Onboarding (KYC) bleibt eigenständig; **KYB** gilt nur für **juristische Personen** als **Investor**.

---

## 1) Produktregeln

| Regel | Beschreibung |
|--------|---------------|
| **Rolle** | Company-Konto nur **Investor**, **kein** Trader-Flow für Firmen. |
| **Kein Parallelbetrieb** | Nicht gleichzeitig zwei aktive Wizards: **entweder** Personal-Onboarding **oder** Company-KYB bearbeiten (ein aktiver Pfad). |
| **Routing-Priorität (Resume)** | Wenn `accountType == company` und `companyKybCompleted == false` → **Company-KYB-Wizard**; sonst bei offenem Personal-Onboarding → **SignUpView** wie heute. |
| **Empfohlene fachliche Reihenfolge** | Für Firmenkonten: zuerst **KYB der juristischen Person** abschließen, danach **KYC der natürlichen Person** (Vertretung/UBO), soweit noch offen – damit Vertragspartner und Registerdaten klar sind, bevor Personendokumente final angebunden werden. |
| **Status getrennt** | `onboardingStep` / `onboardingCompleted` / `kycStatus` = **natürliche Person**; KYB nutzt **eigene** Felder (`companyKyb*`). |
| **Server ist maßgeblich** | Validierung, Audit, Vier-Augen – siehe [`ADR-002-Onboarding-Codable-DTO.md`](ADR-002-Onboarding-Codable-DTO.md). |

---

## 2) Festgelegte Schrittliste (Backend-Keys & Inhalt)

Reihenfolge ist **canonical** (für `validSteps`, Wizard, Fortschritt).

| # | Backend-Key `step` | Kurzname (UI) | Pflichtinhalte (Mindestumfang) |
|---|----------------------|---------------|----------------------------------|
| 1 | `legal_entity` | Unternehmen | Handels-/Firma **vollständig**, **Rechtsform** (z. B. GmbH, UG, AG, SE, eingetragener Verein …), **Registerart** (HRB/HRA/PR/… oder „nicht eingetragen“ mit Begründung), **Registernummer**, **Registergericht** (Ort), **Land** der Gründung |
| 2 | `registered_address` | Sitz & Anschrift | **Eingetragener Sitz** gemäß Register: Straße, PLZ, Ort, Land (analog KYC-Adresse; bei Abweichung Geschäftsanschrift optional als zweites Feld) |
| 3 | `tax_compliance` | Steuern & Identifikatoren | **USt-Id** (falls vorhanden / beantragt), **nationale Steuernummer** (z. B. DE), optional **Wirtschafts-Identifikationsnummer**; Kennzeichen „keine USt-Id (Kleinunternehmer o. ä.)“ falls zutreffend |
| 4 | `beneficial_owners` | Wirtschaftlich Berechtigte | **Mindestens ein** UBO oder Erklärung „kein UBO über 25 %“ gemäß interner Policy; pro UBO: **Name**, **Geburtsdatum** (natürliche Person), **Staatsangehörigkeit**, **unmittelbarer/mittelbarer Anteil** (%) wo erfassbar |
| 5 | `authorized_representatives` | Vertretung | **Vertretungsberechtigte** (Name, Funktion); mindestens eine Person mit **Handlungsvollmacht** für Kontoführung; **Verknüpfung** zum **App-Account-Inhaber** („bin selbst vertretungsberechtigt“) wo möglich |
| 6 | `documents` | Nachweise | **Metadaten** zu vorgesehenen Dokumenten: z. B. aktueller **Handelsregisterauszug** (nicht älter als X Monate – Policy), ggf. **Gesellschaftsvertrag/Auszug**, **Transparenzregister**-Nachweis falls Pflicht; Upload über bestehendes Dokumenten-/Storage-Konzept (URLs/IDs in `savedData`) |
| 7 | `declarations` | Erklärungen | **PEP**-Erklärung (ja/nein + ggf. Details), **Sanktionen**/embargo self-declaration, **Richtigkeit** der Angaben, **keine Treuhand für Dritte** (o. ä. nach Legal-Vorgabe) |
| 8 | `submission` | Einreichung | **Zusammenfassung** bestätigen, **Einreichung** → serverseitig `companyKybStatus` z. B. `pending_review`, optional Vier-Augen-Anlage |

**Konstante für Backend / iOS:**

```text
legal_entity → registered_address → tax_compliance → beneficial_owners
→ authorized_representatives → documents → declarations → submission
```

---

## 3) Datenmodell (Parse `User`)

| Feld | Typ | Bedeutung |
|------|-----|-----------|
| `accountType` | String | `individual` / `company` |
| `companyKybCompleted` | Boolean | KYB-Wizard durchlaufen und eingereicht |
| `companyKybStep` | String? | aktueller Schritt-Key (siehe Tabelle) |
| `companyKybStatus` | String? | z. B. `draft`, `pending_review`, `approved`, `rejected`, `more_info_requested` |
| `companyFourEyesRequestId` | String? | optional |

**Persistenz Zwischenstände:** Klasse **`CompanyKybProgress`** empfohlen: `userId`, `step`, `data` (Object), `isPartial`, `updatedAt` – analog `OnboardingProgress`.

---

## 4) Cloud Functions

| Function | Zweck |
|----------|--------|
| `getCompanyKybProgress` | Session → `currentStep`, `completedSteps`, `companyKybCompleted`, `companyKybStatus`, `savedData` |
| `saveCompanyKybProgress` | `step`, `data`, `partial` – nur Position + Blob; **kein** `completedSteps`-Append außer bei `complete` |
| `completeCompanyKybStep` | Schritt validieren (Joi), Audit, `completedSteps` erweitern |

**Validierung:** `cloud/utils/companyKybStepSchemas.js` (Joi, analog `onboardingStepSchemas.js`).

---

## 5) iOS

| Bereich | Maßnahme |
|---------|----------|
| **DTO** | `SavedCompanyKybData` (Codable), Encoding nur im APIService |
| **Enum** | `CompanyKybStep` oder String-Konstanten passend zur Tabelle oben |
| **Routing** | `AuthenticationView`: Company + KYB offen → dedizierter **CompanyKybView** (Wizard) |
| **Welcome** | Bei `accountType == .company`: nur **Investor** (Trader ausblenden) |

---

## 6) Umsetzungsphasen

| Phase | Inhalt | Status |
|-------|--------|--------|
| **P0** | Schrittliste & ADR-003 | ✅ erledigt |
| **P1** | Parse-Felder, Cloud Functions + Joi, iOS-Modelle + API | ✅ erledigt |
| **P2** | SwiftUI-Wizard (8 Schritte), Resume, Routing | ✅ umgesetzt |
| **P3** | Admin/CSR, Vier-Augen, Last-/E2E-Tests | offen |

### P2-Implementierungsdetails (2026-03-21)

**Backend-Fixes (vor P2-iOS):**
- Step-Order-Enforcement: `submission` erfordert alle 7 vorherigen Steps als completed
- Status-Guard: Kein Re-Submit nach `pending_review` / `approved` / `rejected`
- Audit-Save transaktional (nicht fire-and-forget) – Audit **vor** User-Save
- `schemaVersion` + `fullData` im `CompanyKybAudit` für Compliance-Nachvollziehbarkeit
- `getCompanyKybProgress` mergt `savedData` über **alle** per-step `CompanyKybProgress`-Einträge
- Test-Coverage auf **53 Tests** (alle 8 Steps, complete + partial, Grenzwerte)

**iOS-Architektur (MVVM, Cursor-Rules-konform):**
- `CompanyKybStep` enum (`CaseIterable`, `Sendable`) – 8 feste Steps mit `backendKey`, `title`, `icon`
- `CompanyKybViewModel` (`@MainActor`, `final class`, Protocol-DI) – Navigation, API, Form-State
- `CompanyKybView` – `NavigationStack`-Container mit Progress, ScrollView, Nav-Buttons
- 8 Step Views (je ~80–150 Zeilen, `ResponsiveDesign`, `AppTheme`, `LabeledInputField`)
- Per-Step Form Data als `struct` mit `toSavedData()` → `SavedCompanyKybData`
- Routing: `SignUpCoordinator` → `showCompanyKyb` nach `phoneVerification` bei `accountType == .company`
- Resume: `AuthenticationView` prüft `companyKybCompleted` / `companyKybStep` → `CompanyKybView`
- `WelcomeStep`: Trader-Rolle bei `accountType == .company` deaktiviert

**Dateien:**
```
FIN1/Features/CompanyKyb/
├── Models/
│   ├── CompanyKybStep.swift
│   └── CompanyKybFormData.swift
├── ViewModels/
│   └── CompanyKybViewModel.swift
└── Views/
    ├── CompanyKybView.swift
    └── Steps/
        ├── CompanyKybStepHelpers.swift
        ├── CompanyKybLegalEntityStep.swift
        ├── CompanyKybAddressStep.swift
        ├── CompanyKybTaxStep.swift
        ├── CompanyKybOwnersStep.swift
        ├── CompanyKybRepresentativesStep.swift
        ├── CompanyKybDocumentsStep.swift
        ├── CompanyKybDeclarationsStep.swift
        └── CompanyKybSubmissionStep.swift
```

---

## 7) Verweise

- **Admin-/CSR-Web (Browser):** Übersicht und Bearbeitung eingereichter Firmen-KYB im Admin-Portal unter **KYB-Status** (`/kyb-review`); im CSR-Web-Panel zusätzlich **KYB-Status** (`/csr/kyb`) mit Leserechten für `customer_service` (Cloud Functions `getCompanyKybSubmissions`, `getCompanyKybSubmissionDetail`). Details: [`Documentation/FIN1_APP_DOCS/10_ADMIN_PORTAL_REQUIREMENTS.md`](FIN1_APP_DOCS/10_ADMIN_PORTAL_REQUIREMENTS.md).
- [`Documentation/ADR-002-Onboarding-Codable-DTO.md`](ADR-002-Onboarding-Codable-DTO.md)  
- [`Documentation/ADR-003-Company-KYB-Onboarding.md`](ADR-003-Company-KYB-Onboarding.md)  
- [`Documentation/FIN1_APP_DOCS/03_TECHNISCHE_SPEZIFIKATION.md`](FIN1_APP_DOCS/03_TECHNISCHE_SPEZIFIKATION.md) (nach API-Implementierung ergänzen)  
- [`backend/parse-server/cloud/functions/user/onboarding.js`](../backend/parse-server/cloud/functions/user/onboarding.js)
