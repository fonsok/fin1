# FIN1 – Projekt-Status (Kurzüberblick für neue Chats)

**Stand:** 2026-01-30
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
- **Redis** (Cache/Queues)
- **Postgres** (Analytics/Reporting Schema vorhanden, init-SQL im Repo)
- **Nginx** als Reverse Proxy (Port 80/443)
- Zusätzliche Services (je nach Compose): Market Data, Notification, Analytics, PDF Service, MinIO (S3)

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

---

## 10) “Copy/Paste Context” für neuen Chat

```text
FIN1 Status (2026-01-30):
- Server (LAN): 192.168.178.24, Nginx :80, Parse API via http://192.168.178.24/parse, LiveQuery ws://192.168.178.24/parse
- Parse App ID: fin1-app-id
- Dashboard: nur per SSH-Tunnel (ssh -L 1338:127.0.0.1:1338 io@192.168.178.24) → http://localhost:1338/dashboard
- iOS Config: Info.plist nutzt $(FIN1_PARSE_SERVER_URL)/$(FIN1_PARSE_APPLICATION_ID)/$(FIN1_PDF_SERVICE_BASE_URL), Werte kommen aus Config/*.xcconfig
- Xcode: Build Configs Dev/Staging/Prod + Schemes FIN1-Dev/FIN1-Staging/FIN1-Prod
- Dev default: Simulator → localhost:1338/parse (Tunnel), Device → 192.168.178.24/parse
```

