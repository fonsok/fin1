# FIN1 – Server‑Driven FAQs (Help Center + Landing) — v2026-01-31

## Ziele

- **Server‑driven** FAQ Inhalte (Fragen/Antworten) für:
  - Landing Page (Prospects)
  - Help Center (Users)
- **Themen/Bereiche** sauber strukturiert über Kategorien
- **Ressourcenschonend**: Client cached Kategorien + FAQ Payload (TTL)
- **User‑Flow clean**: **kein** UI‑Fallback mehr auf gebundelte Provider (Legacy ist aus dem User‑Flow entkoppelt)

## Backend (Parse)

### Cloud Functions

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
  - **Wichtig**: “Leere Cache‑Antworten” werden nicht als gültig akzeptiert (sonst würden leere Ergebnisse die UI 24h blocken)
  - ersetzt Platzhalter wie `{{APP_NAME}}` / `{{LEGAL_PLATFORM_NAME}}`

### UI Integration

- Landing Page:
  - `FIN1/Features/Authentication/Views/Components/LandingFAQView.swift`
  - zeigt **Loading** / **Unavailable + Retry** / Content
  - bei Dev‑Simulator‑Setup mit `localhost:1338` zeigt die UI einen Debug‑Hinweis (SSH‑Tunnel fehlt)

- Help Center:
  - `FIN1/Shared/ViewModels/HelpCenterViewModel.swift`
  - `FIN1/Shared/Components/Profile/Components/Modals/HelpCenterView.swift`
  - unterstützt Retry + Pull‑to‑Refresh (server‑driven)

## Seeding / Content Sync

- Lokal exportieren:
  - `scripts/export_faqs_from_swift.py`
  - erzeugt `scripts/faq_export.json`

- Auf dem Server anwenden (Upsert via Master Key):
  - Script: `scripts/apply_faqs_to_parse.py`
  - benötigt Server‑ENV: `/home/io/fin1-server/backend/.env`
  - Parse erreichbar über: `http://127.0.0.1:1338/parse`

## Troubleshooting (Landing‑FAQs fehlen)

1) **Simulator nutzt Dev‑Default `localhost:1338`**
- SSH‑Tunnel starten:

```bash
ssh -L 1338:127.0.0.1:1338 io@192.168.178.24
```

2) **Backend‑Daten prüfen**
- `FAQCategory`: `isActive=true` und `showOnLanding=true`
- `FAQ`: `isPublished=true`, `isArchived=false`, `isPublic=true`
- `FAQ.categoryId` muss die `objectId` der passenden Kategorie enthalten (String)

