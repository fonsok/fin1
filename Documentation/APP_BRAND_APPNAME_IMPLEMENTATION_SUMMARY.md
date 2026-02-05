# AppBrand.appName — Implementation Summary (Rebrand-Ready UI Copy)

This document summarizes the work done to replace hardcoded `"FIN1"` in **user-facing text** with a single, centralized app-name source of truth: `AppBrand.appName`.

---

## 1) Why this exists

Before going public, the app name may change. Hardcoding `"FIN1"` in:

- SwiftUI `Text(...)`
- alerts / dialogs / biometric prompts
- FAQs / help center content
- email/customer-support templates
- document headers / PDFs / invoices (local + backend-generated)
- accounting IDs / QR codes

creates a high-risk, high-effort rebrand (missed occurrences, inconsistent user experience, and review overhead).

The goal was: **one change updates all user-facing "app name" strings** — including **backend-generated PDFs**.

---

## 2) The source of truth: `AppBrand.appName`

### Definition

`AppBrand.appName` reads the app's name from the bundle:

1. `CFBundleDisplayName` (preferred — Home Screen display name)
2. `CFBundleName` (fallback)
3. final fallback `"FIN1"` (for tests, previews, or misconfigured bundles)

### Where implemented

- `app/FIN1/FIN1/Shared/Models/AppBrand.swift`

### How to rename the app

**In Xcode:**

1. Select project in Navigator (⌘1)
2. Select **FIN1** target under TARGETS
3. Go to **General** tab → **Identity** section
4. Change **Display Name** to your new name (e.g., "TESTname")
5. Clean Build Folder (⌘⇧K) and rebuild (⌘R)

**If Simulator still shows the old name after changing Display Name** (common caching issue):

- Delete the app from the Simulator (long-press app icon → Remove App), then rebuild/run
- Or delete Derived Data:
  - Xcode → **File → Settings → Locations** → click the arrow next to Derived Data
  - Delete the app's `DerivedData/` folder (or the `FIN1-...` folder), then rebuild/run
- As a last resort: Simulator → **Device → Erase All Content and Settings...**

**Result:** Any UI using `AppBrand.appName` updates automatically — including FAQs, document IDs, PDF metadata, etc.

---

## 3) Files updated to use `AppBrand.appName`

### Authentication & onboarding screens

- `FIN1/Features/Authentication/Views/LandingView.swift`
- `FIN1/Features/Authentication/Views/LoginView.swift`
- `FIN1/Features/Authentication/Views/DirectLoginView.swift`
- `FIN1/Features/Authentication/ViewModels/AuthenticationCoordinator.swift`
- `FIN1/Features/Authentication/Views/SignUp/Components/Navigation/WelcomePage.swift`

### FAQ/help content

- `FIN1/Shared/Data/LandingFAQProvider.swift` (changed to computed property)
- `FIN1/Shared/Data/FAQDataProvider.swift` (changed to computed property)
- `FIN1/Features/CustomerSupport/Services/FAQKnowledgeBaseService.swift`

### Customer support templates

- `FIN1/Features/CustomerSupport/Models/CannedResponseModels.swift`
- `FIN1/Features/CustomerSupport/Models/Templates/Level1Templates.swift`
- `FIN1/Features/CustomerSupport/Models/Templates/Level2Templates.swift`
- `FIN1/Features/CustomerSupport/Models/Templates/TechSupportTemplates.swift`
- `FIN1/Features/CustomerSupport/Models/Templates/TeamleadTemplates.swift`
- `FIN1/Features/CustomerSupport/Models/Templates/ComplianceTemplates.swift`
- `FIN1/Features/CustomerSupport/Models/Templates/CommonTemplates.swift`
- `FIN1/Features/CustomerSupport/Models/Templates/FraudTemplates.swift`

### Misc

- `FIN1/ContentView.swift`
- `FIN1/Features/Dashboard/Models/AccountStatementEntryDisplay.swift`

---

## 4) Unified approach: `AppBrand` + `LegalIdentity`

**All user-facing names now derive from `AppBrand.appName` (Display Name) by default.**

**Important clarification:** `FIN1` is the **project/technical name** (target/module names, backend service names).
The **user-facing app name** is controlled by **Xcode Display Name** and accessed via `AppBrand.appName`.

### How it works

- `AppBrand.appName` reads from `CFBundleDisplayName`
- `LegalIdentity` values now **default to** values derived from `AppBrand.appName`:
  - `platformName` → `AppBrand.appName`
  - `documentPrefix` → **sanitized** (alphanumeric, uppercased) value derived from `AppBrand.appName`
  - `companyLegalName` → `"<AppName> Investing GmbH"`
  - `bankName` → `"<AppName> Bank AG"`
  - `logoAssetName` → `"<DocumentPrefix>Logo"`

### What changes when you update Display Name

| Area | Example (Display Name = "MyApp") |
|------|----------------------------------|
| FAQs | "What is MyApp?" |
| Login screens | "Sign in to MyApp" |
| Document IDs | MyApp-INV-20260129-00001 |
| PDF Metadata / Issuer | MyApp Investing GmbH |
| QR Codes | MyApp_INVOICE |
| Bank Name (in docs) | MyApp Bank AG |
| **Backend PDFs** | MyApp Investing GmbH (sent from iOS) |

### All configurable values in Info.plist

All company and legal identity values can be configured directly in **Info.plist** (or via Xcode Target → Info):

| Key | Default | Example |
|-----|---------|---------|
| `CFBundleDisplayName` | FIN1 | TTTT |
| `LegalCompanyName` | `<Display Name> Investing GmbH` | TTTT Investing GmbH |
| `LegalCompanyAddress` | Hauptstraße 100 | Mönckebergstraße 7 |
| `LegalCompanyCity` | 60311 Frankfurt am Main | 20095 Hamburg |
| `LegalCompanyEmail` | *(derived from Display Name)* | info@tttt-investing.com |
| `LegalCompanyPhone` | +49 (0) 69 12345678 | +49 (0) 40 12345678 |
| `LegalCompanyWebsite` | *(derived from Display Name)* | www.tttt-investing.com |
| `LegalPrivacyEmail` | *(derived from Display Name)* | privacy@tttt-investing.com |
| `LegalDPOEmail` | *(derived from Display Name)* | dpo@tttt-investing.com |
| `LegalCompanyBusinessHours` | Mo-Fr: 9:00-18:00 Uhr | Mo-Fr: 8:00-17:00 Uhr |
| `LegalCompanyRegisterNumber` | HRB 123456 | HRB 654321 |
| `LegalCompanyVatId` | DE123456789 | DE987654321 |
| `LegalCompanyManagement` | Max Mustermann | Hans Schmidt |
| `LegalBankName` | `<Display Name> Bank AG` | Deutsche Bank |
| `LegalBankIBAN` | DE89 3704 0044 0532 0130 00 | DE12 3456 7890 1234 5678 90 |
| `LegalBankBIC` | COBADEFFXXX | DEUTDEDB |

**Note:** Leave `LegalCompanyName` and `LegalBankName` empty to use dynamic defaults derived from `AppBrand.appName` (Display Name).

### Where implemented

- `FIN1/Shared/Models/AppBrand.swift` — reads Display Name from bundle
- `FIN1/Shared/Models/LegalIdentity.swift` — defaults to AppBrand, with optional Info.plist overrides
- `FIN1/Shared/Models/CompanyContactInfo.swift` — delegates `companyName` to LegalIdentity

---

## 5) Key technical fixes

### Static initialization timing issue

FAQ providers originally used `static let` with string interpolation:

```swift
// PROBLEM: Evaluated once at static init (before bundle is ready)
static let landingFAQs: [FAQItem] = [
    FAQItem(question: "What is \(AppBrand.appName)?", ...)
]
```

**Fix:** Changed to computed properties:

```swift
// SOLUTION: Evaluated each time accessed
static var landingFAQs: [FAQItem] { [
    FAQItem(question: "What is \(AppBrand.appName)?", ...)
] }
```

### Info.plist configuration

Added `CFBundleDisplayName` to Info.plist:

```xml
<key>CFBundleDisplayName</key>
<string>$(INFOPLIST_KEY_CFBundleDisplayName)</string>
```

This links to the build setting Xcode sets when you change "Display Name" in Target settings.

### QR Code backward compatibility

QR scanner accepts both new prefix and legacy `FIN1_INVOICE` for existing QR codes:

```swift
type == "\(LegalIdentity.documentPrefix)_INVOICE" || type == "FIN1_INVOICE"
```

---

## 6) Cursor rules

Cursor rule added to prevent regressions:

- `app/FIN1/.cursor/rules/app-branding.md`
  - Rule: **no hardcoded app name** in user-facing copy; use `AppBrand.appName`

---

## 7) Remaining "FIN1" occurrences (intentional)

These are **not** user-visible and should remain for backward compatibility:

- UserDefaults keys (`FIN1_SecuritySettings`, `FIN1_TradeNumber_`, etc.)
- QR code backward compatibility (`FIN1_INVOICE`)
- Code comments, module names, type names
- Fallback in `AppBrand.appName` for edge cases

---

## 8) Backend PDF Generation

### Overview

PDFs can be generated either **locally** (iOS) or via **backend** (Ubuntu server with WeasyPrint). Both methods automatically use the app's Display Name from `AppBrand.appName`.

### Data Flow

```
┌─────────────────────────────────────────────────────────────────┐
│  Xcode: Display Name = "TTTT"                                   │
│         (Info.plist → CFBundleDisplayName)                      │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  iOS App                                                        │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ AppBrand.appName = "TTTT"                                │   │
│  │ LegalIdentity.companyLegalName = "TTTT Investing GmbH"   │   │
│  │ CompanyContactInfo.email = "info@fin1-investing.com"      │   │
│  └──────────────────────────────────────────────────────────┘   │
│                              ↓                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ PDFBackendService sends CompanyInfoDTO + qr_data:        │   │
│  │   {                                                      │   │
│  │     "name": "TTTT Investing GmbH",                       │   │
│  │     "address": "Hauptstraße 100",                        │   │
│  │     "email": "info@fin1-investing.com",                   │   │
│  │     ...                                                  │   │
│  │     "qr_data": "{...}"                                   │   │
│  │   }                                                      │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                              ↓
                      HTTP POST Request
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  Backend (Ubuntu Server: fin1-server:8083)                      │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ PDF-Service uses company_info in HTML templates:         │   │
│  │   {{ company.name }} → "TTTT Investing GmbH"             │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                              ↓
                      PDF with correct company name
```

### Backend Service Location

- **Service**: `backend/pdf-service/` (Python + FastAPI + WeasyPrint)
- **Port**: 8083
- **Templates**: `backend/pdf-service/templates/` (HTML/CSS, DIN A4/DIN 5008 compliant)

### iOS Service Files

| File | Description |
|------|-------------|
| `FIN1/Shared/Services/PDFBackendService.swift` | HTTP client for backend PDF generation |
| `FIN1/Features/Trader/Utils/PDFGenerator.swift` | Facade with local/backend mode switch |

### Key Implementation: `CompanyInfoDTO.fromLegalIdentity()`

The iOS app sends company data to the backend using values from `LegalIdentity`:

```swift
static func fromLegalIdentity() -> CompanyInfoDTO {
    return CompanyInfoDTO(
        name: LegalIdentity.companyLegalName,      // "TTTT Investing GmbH"
        address: ...,
        email: CompanyContactInfo.email,
        phone: CompanyContactInfo.phone,
        registerNumber: LegalIdentity.companyRegisterNumber,
        vatId: LegalIdentity.companyVatId,
        ...
    )
}
```

### QR Code DRY fix (local vs backend)

- iOS has a single QR payload generator (`QRCodeGenerator`).
- The backend PDF service **does not invent its own QR payload format** anymore:
  - iOS sends `qr_data` in the request
  - the backend only renders the QR code image from that payload

### PDF Generation Modes

```swift
// Backend mode (recommended for production)
PDFGenerator.generationMode = .backend

// Professional local mode (DIN 5008 layout, offline capable)
PDFGenerator.generationMode = .professionalLocal

// Legacy local mode
PDFGenerator.generationMode = .local
```

### Starting the Backend

```bash
cd /Users/ra/app/FIN1
docker-compose up -d pdf-service
```

### API Endpoints

| Endpoint | Document Type |
|----------|---------------|
| `POST /api/pdf/invoice` | Rechnung/Wertpapierabrechnung |
| `POST /api/pdf/trade-statement` | Sammelabrechnung |
| `POST /api/pdf/credit-note` | Gutschrift |
| `POST /api/pdf/account-statement` | Kontoauszug |

---

## 9) Quick verification

After changing Display Name:

1. Clean Build Folder (⌘⇧K)
2. Build and Run (⌘R)
3. Check:
   - Landing page FAQ: "What is [NewName]?"
   - Document notifications: "[NewName]-INV-..."
   - PDF metadata: "[NewName] Investing GmbH"
   - **Backend PDFs**: Company name shows "[NewName] Investing GmbH"
4. If any screen still shows the previous name, follow the "Simulator still shows the old name" cache-clearing steps above.
