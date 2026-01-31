# FIN1 – Server‑Driven FAQs (Help Center + Landing)

## Ziele

- **Server‑driven** FAQ Inhalte (Fragen/Antworten) für:
  - Landing Page (Prospects)
  - Help Center (User)
- **Themen/Bereiche** sauber strukturiert über Kategorien
- **Ressourcenschonend**: Client cached Kategorien + FAQ Payload (TTL)
- **Fallback**: wenn Parse nicht erreichbar → App nutzt weiterhin die gebundelten `FAQDataProvider` / `LandingFAQProvider`

## Backend (Parse)

### Cloud Functions (bereits vorhanden)

- `getFAQCategories(location)`
  - `location`: `"landing" | "help_center" | "csr"`
  - Filtert `FAQCategory` anhand `showOnLanding / showInHelpCenter / showInCSR`

- `getFAQs(categorySlug?, isPublic?)`
  - liefert veröffentlichte (`isPublished=true`) und nicht archivierte (`isArchived=false`) FAQs
  - optional Filter über `categorySlug`

### Parse Klassen

#### `FAQCategory`

Empfohlene Felder:
- `slug` (String, unique)
- `title` (String) – **server-driven display title**
- `icon` (String, SF Symbol Name)
- `sortOrder` (Number)
- `isActive` (Boolean)
- `showOnLanding` (Boolean)
- `showInHelpCenter` (Boolean)
- `showInCSR` (Boolean)

Legacy / Übergang (optional):
- `displayName` (String) – wird weiter unterstützt, falls `title` fehlt
- `icon` (String, SF Symbol Name)
- `sortOrder` (Number)
- `isActive` (Boolean)
- `showOnLanding` (Boolean)
- `showInHelpCenter` (Boolean)
- `showInCSR` (Boolean)

#### `FAQ`

Empfohlene Felder:
- `faqId` (String, stable ID aus App/Seed)
- `question` (String)
- `answer` (String)
- `categoryId` (String) – **objectId** von `FAQCategory` (als String gespeichert; passt zur aktuellen Cloud Function)
- `sortOrder` (Number)
- `isPublished` (Boolean)
- `isArchived` (Boolean)
- `isPublic` (Boolean)
- `isUserVisible` (Boolean)

## App (Swift)

### Service + Caching

- `FIN1/Shared/Services/FAQContentService.swift`
  - holt Kategorien + FAQs über Parse Cloud Functions
  - cached Payload in `UserDefaults` (TTL default 24h)
  - ersetzt Platzhalter wie `{{APP_NAME}}` / `{{LEGAL_PLATFORM_NAME}}`

### UI Integration

- Landing Page:
  - `FIN1/Features/Authentication/Views/Components/LandingFAQView.swift`
  - nutzt server‑driven Daten, wenn verfügbar, sonst `LandingFAQProvider`

- Help Center:
  - `FIN1/Shared/ViewModels/HelpCenterViewModel.swift`
  - `FIN1/Shared/Components/Profile/Components/Modals/HelpCenterView.swift`
  - nutzt server‑driven Daten, wenn verfügbar, sonst `FAQDataProvider`

## Seeding / Content Sync

- Lokal exportieren:
  - `scripts/export_faqs_from_swift.py`
  - erzeugt `scripts/faq_export.json`

- Auf dem Server anwenden:
  - `scripts/apply_faqs_to_parse.py`
  - upserted `FAQCategory` + `FAQ` via Master Key (`/home/io/fin1-server/backend/.env`)

## “Themen/Bereiche” (Best Practice)

Aktuell ist das **komplett server‑driven** modelliert (`id/slug/title/icon`).
Neue Themen/Kategorien können jetzt **ohne App‑Update** im Parse Dashboard angelegt werden.

