# FIN1 – Server‑Driven Help & Instructions (FAQs, Help Center + Landing) — v2026-03-28

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

- `getFAQs(categorySlug?, isPublic?, userRole?, location?, context?)`
  - Standard (App / öffentlich): liefert veröffentlichte (`isPublished=true`) und nicht archivierte (`isArchived=false`) FAQs; optional `categorySlug`, `location` (`help_center` setzt u. a. `isUserVisible`), `isPublic`, `userRole` für Rollenfilter auf `targetRoles`.
  - **Admin-Portal / CSR:** Aufruf mit `context: 'admin'` und Session-User. Nutzer in der Parse-Rolle **`admin`** ( `_Role` mit `users`-Relation) sehen **alle** FAQs inkl. Entwurf und archivierte; andere Admin-Rollen mit Berechtigung `getFAQs` sehen nur veröffentlichte, nicht archivierte (wie bisher).
  - Hard-Limit der Abfrage: **500** Einträge, Sortierung `sortOrder` aufsteigend (siehe `backend/parse-server/cloud/functions/user/faq.js`).

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

> **Kanonischer Klassenname in Code und Cloud Code:** `FAQ` (`Parse.Query('FAQ')` in `faq.js` / `faqAdmin/`). Ältere interne Texte wiesen irrtümlich auf `FAQItem` hin; die Laufzeit- und Seed-Pfade verwenden **`FAQ`**.

Empfohlene Felder:
- `faqId` (String, stable ID aus App/Seed)
- `question` (String)
- `answer` (String)
- `categoryId` (String) – **Primär-Kategorie**, `objectId` von `FAQCategory` (als String gespeichert)
- `categoryIds` (Array\<String\>, optional) – **Mehrfach-Kategorien**, Liste von `FAQCategory.objectId`
- `sortOrder` (Number)
- `isPublished` (Boolean)
- `isArchived` (Boolean)
- `isPublic` (Boolean)
- `isUserVisible` (Boolean)
- `source` (String) – historisches Einzel-Feld für Kontext (z.B. `"help_center"`, `"landing"`)
- `contexts` (Array\<String\>, optional) – **Mehrfach-Kontexte**, z.B. `["help_center", "investor"]`

> **Kompatibilität:** `categoryId` und `source` bleiben als Single‑Felder bestehen und werden aus den Arrays (`categoryIds[0]`, `contexts[0]`) befüllt, damit bestehende Clients/Queries weiter funktionieren.

## App (Swift)

### Service + Caching

- `FIN1/Shared/Services/FAQContentService.swift`
  - holt Kategorien + FAQs über Parse Cloud Functions
  - cached Payload in `UserDefaults` (TTL default 24h)
  - **Wichtig**: "Leere Cache‑Antworten" werden nicht als gültig akzeptiert (sonst würden leere Ergebnisse die UI 24h blocken)
  - ersetzt Platzhalter wie `{{APP_NAME}}` / `{{LEGAL_PLATFORM_NAME}}`

### UI Integration

- Landing Page:
  - `FIN1/Features/Authentication/Views/Components/LandingFAQView.swift`
  - zeigt **Loading** / **Unavailable + Retry** / Content
  - bei Dev‑Simulator‑Setup mit `https://localhost:8443` zeigt die UI einen Debug‑Hinweis, wenn der SSH‑Tunnel zu fin1‑server fehlt

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
- Parse auf dem Server (Host) direkt: `http://127.0.0.1:1338/parse` (nur localhost); über Nginx HTTPS: `https://127.0.0.1/parse`

### Admin- und CSR-Portal: Manuelle Pflege & Erweiterung

- Das Admin-/CSR-Portal verwendet dedizierte Admin‑Cloud‑Functions (`createFAQ`, `updateFAQ`, `deleteFAQ`, `createFAQCategory`), um FAQs und Kategorien direkt über das Web-UI zu pflegen. In der Sidebar erscheint die FAQ-Verwaltung unter **„Hilfe & Anleitung“**.
- **Liste & Paging (Stand 2026-03):** Die Seite **Hilfe & Anleitung** lädt die FAQ-Liste über **`getFAQs(true)`** mit **`context: 'admin'`** (siehe `admin-portal/src/pages/FAQs/api.ts`) sowie **`getFAQCategories()`** ohne zusätzliche Filter (alle aktiven Kategorien für die Dropdowns). **Kontext-, Kategorie- und Textsuche** werden im **Browser** angewendet; die sichtbare Tabelle nutzt **`PaginationBar`** (25/50/100 pro Seite) auf dem gefilterten Array. Begründung: zuverlässiger Betrieb auch dann, wenn der Parse-Container **kein** Live-Mount des Host-Verzeichnisses `cloud/` hat (siehe Abschnitt *Parse Cloud Code: Deployment und „Invalid function“* unten). Solange die FAQ-Anzahl unter dem Server-Limit von 500 bleibt, ist das für die Admin-UI ausreichend.
- **Multi‑Kontext & Multi‑Kategorie:**
  - Ein FAQ kann mehreren Kategorien (`categoryIds`) und mehreren Kontexten (`contexts`) zugeordnet werden.
  - Das Panel hält zusätzlich `categoryId` und `source` als primäre Felder synchron, um Legacy‑Clients (inkl. Swift‑App) nicht zu brechen.
- **Neue Kategorien:** Über das Panel können neue `FAQCategory`‑Einträge mit `slug`, `title`, `displayName`, `icon`, `sortOrder`, `showOnLanding`, `showInHelpCenter`, `showInCSR` angelegt werden. Die Cloud‑Function erzwingt einen eindeutigen `slug`.

### Parse Cloud Code: Deployment und „Invalid function“

Neue oder geänderte **`Parse.Cloud.define(...)`**-Funktionen sind erst erreichbar, wenn der **laufende** Parse-Server-Prozess die aktuelle **`cloud/main.js`‑Kette** lädt.

- **Lokal (Repo-`docker-compose.yml`):** Typischerweise ist `./backend/parse-server/cloud` als **`/app/cloud`** in den Container **gemountet**. Änderungen an `*.js` unter `cloud/` wirken nach **Container-Neustart** von `parse-server` (oder Prozess-Neustart), ohne Image-Rebuild.
- **Ubuntu-Server / Produktion:** Wenn der Container **kein** Volume für `cloud/` mountet, sondern Cloud Code **im Image** liegt, reicht **`rsync` auf den Host-Pfad** `~/fin1-server/backend/parse-server/cloud/` **nicht**: der Container sieht die Dateien nicht → Aufrufe unbekannter Function-Namen liefern **`Invalid function`** (HTTP/Parse-Fehler). Abhilfe: **Compose anpassen** (wie lokal: Host-`cloud` nach `/app/cloud` mounten) **oder** Image **neu bauen** und Container aktualisieren, **oder** nur etablierte Functions nutzen (wie `getFAQs` / `getFAQCategories`), die im Image bereits registriert sind.

**Referenz:** `backend/parse-server/index.js` (`cloud: … PARSE_SERVER_CLOUD_CODE_MAIN`), Root-`docker-compose.yml` (Service `parse-server`, Volume `./backend/parse-server/cloud:/app/cloud`).

## Troubleshooting (Landing‑FAQs fehlen)

1) **Simulator nutzt Dev‑Default `https://localhost:8443/parse` (Nginx auf fin1‑server)**
- SSH‑Tunnel vom Mac auf HTTPS des Servers (443 → lokal 8443):

```bash
ssh -L 8443:127.0.0.1:443 io@192.168.178.20
```

- Alternativ (direkt Parse-Port, ohne Nginx): `ssh -L 1338:127.0.0.1:1338 io@192.168.178.20` und in Xcode **`FIN1_PARSE_SERVER_URL`** für Simulator auf `http://localhost:1338/parse` setzen (nicht die Standard‑FIN1‑Dev‑xcconfig).

2) **Backend‑Daten prüfen**
- `FAQCategory`: `isActive=true` und `showOnLanding=true` (Landing-Kategorien z. B. `app_overview`, `getting_started`)
- `FAQ`: `isPublished=true`, `isArchived=false`, `isPublic=true` (für öffentliche Landing-Inhalte)
- `FAQ.categoryId` bzw. `categoryIds` müssen auf gültige `FAQCategory.objectId`-Werte zeigen

3) **Admin-Portal: „Invalid function“ oder leere Liste trotz Daten**
- Prüfen, ob der Aufruf eine **auf dem Server registrierte** Cloud Function trifft (Browser-Netzwerk-Tab: `POST …/parse/functions/<name>`).
- Wenn nur **neue** Function-Namen fehlschlagen: Cloud Code im Container **nicht** vom Host gemountet → Abschnitt *Parse Cloud Code: Deployment und „Invalid function“* oben.
- Wenn **`getFAQs`** mit `context: 'admin'` leer bleibt: eingeloggter User ist ggf. **nicht** in der Parse-Rolle `admin` und sieht nur **veröffentlichte, nicht archivierte** Einträge; Entwürfe erscheinen dann nicht.

4) **Klassennamen-Mismatch (historisch, selten)**
- Die Cloud Function `getFAQs` fragt die Klasse **`FAQ`** ab. Liegen Inhalte in einer **anderen** Klasse, Migration bzw. Datenbereinigung mit Ops-Skripten prüfen (z. B. `scripts/fix-faq-class-mismatch.sh`, falls im Repo vorhanden).
