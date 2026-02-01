# FIN1 – Projekt-Status (Kurzüberblick für neue Chats)

**Stand:** 2026-01-31
**Ziel dieses Dokuments:** In einem neuen Chat in < 5 Minuten Kontext liefern (ohne Repo-Deep-Dive).

---

## 1) TL;DR (die 10 wichtigsten Fakten)

- **Server-IP (LAN)**: `192.168.178.24` (Ubuntu, „iobox“)
- **Öffentliche App-API (empfohlen)**: `http://192.168.178.24/parse` (über Nginx :80)
- **LiveQuery (empfohlen)**: `ws://192.168.178.24/parse`
- **Parse App ID**: `fin1-app-id`
- **Dashboard (sicher)**: **nur per SSH-Tunnel** (Browser nutzt „serverURL“ direkt)
- **iOS Konfiguration**: **`.xcconfig` + `Info.plist` Platzhalter** (keine manuelle Plist-Editiererei)
- **Xcode Build Configs/Schemes**: `Dev`, `Staging`, `Prod` + Schemes `FIN1-Dev`, `FIN1-Staging`, `FIN1-Prod`
- **Dev-Default (Expert)**: Simulator → Tunnel/`localhost:1338`, Device → LAN/`192.168.178.24`
- **PDF-Service**: `http://192.168.178.24:8086` (Base-URL; App nutzt `/api/pdf/...`)
- **Test-/Seed-Passwort-Policy**: Parse Password Policy verlangt u.a. Groß-/Kleinbuchstaben, Zahl, Sonderzeichen (Beispiel in App: `Password123!`)

**Neu seit 2026-01-31 (Compliance/UX/Hardening):**
- **Git Repository** initialisiert mit Pre-Commit Hooks für Code-Qualität
- **Redis Caching aktiviert** für Parse Server (Performance-Boost)
- **MiFID II Audit Logging** in Trading Services integriert (Buy/Sell Orders, Cancellations)
- **Transaction Limits** mit UI-Feedback (Warnung + Button-Deaktivierung bei Überschreitung)
- **Delete-Protection** für Audit-kritische Klassen (TermsContent, LegalConsent, ComplianceEvent)
- **Production Verification Script** (`scripts/verify-production-data.sh`)
- **Server-driven Legal Docs (Terms/Privacy/Imprint)** inkl. **Audit Trail** (Delivery + Consent) via Parse Cloud Functions/Triggers.
- **FAQ vollständig server-driven** (Categories/Items) inkl. Caching + Retry/Refresh UI. Landing zeigt bei fehlendem SSH‑Tunnel einen klaren Hinweis.
- **Consent-Flow** loggt die **tatsächlich angezeigte** server/cached Version + `documentHash` (nicht nur lokale Constants).
- **Branding Fix**: UI-Appname kommt aus `CFBundleDisplayName` via `AppBrand.appName`. Regression-Guard vorhanden (siehe Hooks unten).
- **Accounting Hardening**: Legal/Accounting Identity ist **vom Display Name entkoppelt** (stabile Defaults + Info.plist Overrides passend zu Backend `FIN1_LEGAL_*`).
- **AGB PDF-Export**: Client-seitige PDF-Generierung für Terms/Privacy mit Share-Sheet (`LegalDocumentPDFGenerator`).
- **AGB Änderungs-Overlay**: "Was hat sich geändert?" UI bei neuen Dokumentversionen (`LegalDocumentChangesOverlay`).
- **FAQ Klassennamen-Fix**: Cloud Function nutzt jetzt `FAQItem` (war fälschlich `FAQ`). Daten migriert.

---

## 2) Feature-Status (High-Level)

### App (iOS, SwiftUI)
- **Kernrollen**: Investor & Trader (role-based UI)
- **Auth**: Login/SignUp-Flows inkl. KYC-ähnlicher Multi-Step-Registrierung (UI/Logik vorhanden)
- **Investor**: Trader Discovery, Portfolio/Investments, Watchlist
- **Trader**: Depot, Trades-Übersichten, Order-Flows, KPIs
- **Dokumente/PDF**: PDF-Backend-Service angebunden (API-Calls vorbereitet)
- **Customer Support (CSR)**: Ticket-System, FAQ-Knowledgebase, Audit Logging, SLA Monitoring, Surveys (UI/Service Layer)
- **Admin**: Reports, Rounding-Differences, Konfigurationsverwaltung (appseitig)

### Backend (Docker / Ubuntu)
- **Parse Server** (Node.js) + Cloud Code (Hooks/Functions) als zentrale Backend-API
- **MongoDB** als Primary DB (Parse)
- **Redis** ✅ **AKTIV** (Cache für Parse Server Schema/Queries)
- **Postgres** (Analytics/Reporting Schema vorhanden, init-SQL im Repo)
- **Nginx** als Reverse Proxy (Port 80/443)
- Zusätzliche Services (je nach Compose): Market Data, Notification, Analytics, PDF Service, MinIO (S3)

### Parse Server Klassen (Compliance)
- `ComplianceEvent` - MiFID II Audit Logging (Master Key only write)
- `LegalConsent` / `LegalDocumentDeliveryLog` - Legal Audit Trail (Master Key only)
- `TransactionLimit` / `TransactionHistory` - Limit Tracking
- `TermsContent` - Legal Documents (immutable, delete-protected)

> Hinweis: Im Repo gibt es historisch unterschiedliche Doku-/Compose-Stände. Dieses Dokument beschreibt die **robuste Ziel-Topologie** plus die wichtigsten Verifikationsschritte.

---

## 3) Architektur & Ordner (wo was liegt)

### Backend (Repo)
- **Parse Server**: `backend/parse-server/`
  - Entry/Config: `backend/parse-server/index.js`
  - Cloud Code: `backend/parse-server/cloud/` (Functions/Triggers/Utils)
- **Nginx**: `backend/nginx/nginx.conf`
- **Mongo init**: `backend/mongodb/init/`
- **Postgres init (Schemas + Seeds)**: `backend/postgres/init/`
- **Prod Env Template**: `backend/env.production.example` (keine Secrets!)

### iOS App (Repo)
- **App**: `FIN1/FIN1App.swift`
- **Config/Bootstrap**: `FIN1/Shared/Services/ConfigurationService.swift`
- **App Branding**: `FIN1/Shared/Models/AppBrand.swift` (liest `CFBundleDisplayName`)
- **Legal Identity**: `FIN1/Shared/Models/LegalIdentity.swift` (stabil + Info.plist overrides)
- **PDF Client**: `FIN1/Shared/Services/PDFBackendService.swift`
- **Build-Konfig**:
  - `.xcconfig`: `Config/FIN1-*.xcconfig`
  - Schemes: `FIN1.xcodeproj/xcshareddata/xcschemes/*.xcscheme`
  - `Info.plist`: nutzt `$(...)` Platzhalter (siehe unten)

---

## 4) Netzwerk / Ports / URLs (Produktiv-LAN)

### Extern/LAN (vom Mac/iPhone erreichbar)
- **Nginx**: `http://192.168.178.24/` (Port 80)
- **Health**: `http://192.168.178.24/health`
- **Parse API**: `http://192.168.178.24/parse`
- **LiveQuery**: `ws://192.168.178.24/parse`
- **PDF (wenn separat exposed)**: `http://192.168.178.24:8086` (Base URL)

### Intern (Docker-Netz)
- Parse Server intern: `http://parse-server:1337/parse`
- Nginx upstream zeigt auf Container-Namen (siehe `backend/nginx/nginx.conf`)

### Typische Host-Ports (je nach Compose)
- Parse: Host `1338` → Container `1337` (**idealerweise hostseitig nur localhost**, wenn Dashboard nur per Tunnel)
- Mongo: Host `27018` → Container `27017`
- Redis: Host `6380` (localhost) → Container `6379`
- Postgres: Host `5433` (localhost) → Container `5432`
- MinIO: `9002/9003`

---

## 5) Parse Dashboard (robust & sicher)

**Warum:** Dashboard embeded `serverURL` in der Browser-App – „localhost“ bezieht sich immer auf den Client, nicht auf den Server.

### Empfehlung
- Dashboard **nicht** im LAN öffentlich bereitstellen.
- Zugriff nur per SSH-Tunnel, so bleibt Master-Key-Nutzung auf localhost/Docker-Netz eingeschränkt.

### SSH Tunnel (Mac → Ubuntu)

```bash
ssh -L 1338:127.0.0.1:1338 io@192.168.178.24
```

Dann im Browser (Mac):
- Dashboard: `http://localhost:1338/dashboard`

Wichtig:
- `PARSE_DASHBOARD_SERVER_URL` (Server-ENV) sollte für das Dashboard-Frontend passend gesetzt sein, z.B. `http://localhost:1338/parse` (siehe Template `backend/env.production.example`).

---

## 6) iOS/Xcode Konfiguration (keine Plist-Handarbeit mehr)

### Grundprinzip
- `Info.plist` enthält nur Keys mit `$(...)` Platzhaltern.
- Werte kommen aus `.xcconfig` → pro Environment steuerbar.

### Relevante Keys in `Info.plist`
- `FIN1ParseServerURL` → `$(FIN1_PARSE_SERVER_URL)`
- `FIN1ParseApplicationId` → `$(FIN1_PARSE_APPLICATION_ID)`
- `FIN1PDFServiceBaseURL` → `$(FIN1_PDF_SERVICE_BASE_URL)`
- `CFBundleDisplayName` → `$(INFOPLIST_KEY_CFBundleDisplayName)` (App Name / Home Screen)

### Wichtig: Display Name / App Name (Xcode)
- **Single Source of Truth**: Target → General → Identity → **Display Name**
- Wenn der App-Name “komisch” erscheint, zuerst prüfen:

```bash
./scripts/check-xcode-display-name-v2026-01-31.sh
xcodebuild -showBuildSettings -project FIN1.xcodeproj -scheme FIN1-Dev -configuration Debug | grep INFOPLIST_KEY_CFBundleDisplayName
```

### `.xcconfig` – wichtiges Detail
In `.xcconfig` startet `//` einen Kommentar. Deshalb werden URLs so gebaut:
- `FIN1_URL_SLASH = /`
- `http:$(FIN1_URL_SLASH)$(FIN1_URL_SLASH)host/path`

### Dev-Default (Expert)
- Simulator: `http://localhost:1338/parse` (per SSH-Tunnel)
- Device: `http://192.168.178.24/parse` (direkt im LAN)

Das ist bereits in `Config/FIN1-Dev.xcconfig` so hinterlegt.

---

## 7) Quick Verify (wenn jemand „läuft alles?“ fragt)

### Vom Mac (LAN)

```bash
curl -sS http://192.168.178.24/health
curl -sS http://192.168.178.24/parse/health
```

### Auf dem Server

```bash
docker compose -f docker-compose.production.yml ps
docker compose -f docker-compose.production.yml logs --tail=200 parse-server
docker compose -f docker-compose.production.yml logs --tail=200 nginx
```

---

## 8) Legal Docs / Audit Trail (Kurzüberblick)

### Ziel
Wenn Legal Texte (Terms/Privacy/Imprint) server-driven sind, muss intern nachvollziehbar sein, **welche App-Version wann welche Text-Version** gesehen hat und **welche Version akzeptiert** wurde.

### Backend (Parse)
- **Immutable Content**: `TermsContent` wird serverseitig gehasht (`documentHash`) **nach Placeholder-Resolution**.
- **Audit Logs**:
  - Delivery: `LegalDocumentDeliveryLog` (wird beim Anzeigen geloggt)
  - Consent: `LegalConsent` (wird bei Akzeptanz geloggt)
- **ENV für Placeholder-Resolution**: siehe `backend/env.production.example` (`FIN1_LEGAL_*`).

### iOS
- **Hybrid Fetch**: Server → Cache → Bundled Fallback (mit Completeness Guard für Terms/Privacy).
- **Consent-Flow** übernimmt die **tatsächlich geladene** Version + Hash (Cache/Server) und loggt diese.
- **PDF-Export**: `LegalDocumentPDFGenerator` erzeugt A4-PDFs client-seitig (Terms/Privacy). Download-Button in Views + Acceptance Modal.
- **Änderungs-Overlay**: `LegalDocumentChangesOverlay` zeigt Diff zwischen alter/neuer Version (hinzugefügt/geändert/entfernt).
- **Change Tracking**: `LegalDocumentChangesService` speichert akzeptierte Versionen lokal für späteren Vergleich.

---

## 8) Secrets / Credentials (bewusst NICHT hier im Klartext)

**Nicht in Git/Docs hardcoden:**
- Master Key, DB Passwörter, Dashboard Passwort

**Wo stattdessen:**
- Server: `backend/.env` (auf dem Ubuntu-Host, nicht im Repo)
- Template/Variablen-Namen: `backend/env.production.example`

---

## 9) Häufige Stolpersteine (1‑Zeiler)

- **Dashboard „Server not reachable“**: `serverURL` zeigt auf falschen Host (Browser-„localhost“-Problem) → Tunnel + `PARSE_DASHBOARD_SERVER_URL`.
- **MasterKey „unauthorized“**: Parse Server 6.x nutzt `masterKeyIps` → erlaubte IP-Ranges prüfen (Template: `PARSE_SERVER_MASTER_KEY_IPS`).
- **iPhone + localhost**: funktioniert nicht (localhost = iPhone) → Device muss LAN-IP nutzen.
- **`.xcconfig` URLs**: `//` ist Kommentar → URL-Slash-Workaround nutzen (ist bereits umgesetzt).
- **Display Name “springt zurück”**: häufig durch versehentlich committen eines Test-Werts in `INFOPLIST_KEY_CFBundleDisplayName` → Guard-Script/Hook nutzen (siehe oben).
- **Landing FAQs “nicht verfügbar”**: häufig fehlt der SSH‑Tunnel (Dev‑Simulator nutzt `localhost:1338`). Details: `Documentation/FAQS_SERVER_DRIVEN.md`

---

## 10) Git Hooks (Regression Guards)

Wenn das Projekt als Git-Repo genutzt wird, Hooks installieren:

```bash
./scripts/install-githooks-v2026-01-31.sh
```

Details: `Documentation/GIT_HOOKS.md`

---

## 11) “Copy/Paste Context” für neuen Chat

```text
FIN1 Status (2026-01-31):
- Server (LAN): 192.168.178.24, Nginx :80, Parse API via http://192.168.178.24/parse, LiveQuery ws://192.168.178.24/parse
- Parse App ID: fin1-app-id
- Dashboard: nur per SSH-Tunnel (ssh -L 1338:127.0.0.1:1338 io@192.168.178.24) → http://localhost:1338/dashboard
- iOS Config: Info.plist nutzt $(FIN1_PARSE_SERVER_URL)/$(FIN1_PARSE_APPLICATION_ID)/$(FIN1_PDF_SERVICE_BASE_URL), Werte kommen aus Config/*.xcconfig
- Xcode: Build Configs Dev/Staging/Prod + Schemes FIN1-Dev/FIN1-Staging/FIN1-Prod
- Dev default: Simulator → localhost:1338/parse (Tunnel), Device → 192.168.178.24/parse
- Legal Docs: server-driven Terms/Privacy/Imprint (TermsContent + documentHash), Audit Logs: LegalDocumentDeliveryLog + LegalConsent, FIN1_LEGAL_* ENV server-side placeholder resolution
- Legal PDF-Export: LegalDocumentPDFGenerator (client-side A4 PDF), Änderungs-Overlay: LegalDocumentChangesOverlay
- FAQs: server-driven (FAQCategory + FAQItem), Cloud Functions: getFAQCategories/getFAQs
- Display Name Guard: ./scripts/check-xcode-display-name-v2026-01-31.sh (Hook via ./scripts/install-githooks-v2026-01-31.sh)
```

