---
filePatterns:
  - "backend/parse-server/cloud/**/*.js"
---

# Parse Cloud Code (`backend/parse-server/cloud/`)

Gilt bei Arbeit an **Parse Cloud Functions**, **Triggers** und **`cloud/utils/**`. Ergänzt die globalen Regeln in **`ci-cd.md`** (Deploy, lokale Checks).

## Modulauflösung (Node) — kritisch

- **`require` für Konfig-Helfer:** immer **`…/configHelper/index.js`** (vollständiger Pfad bis `index.js`).
- **Nicht** `require('…/configHelper')` ohne `/index.js` — eine verwaiste Datei **`utils/configHelper.js`** auf dem Server würde das Paket **`utils/configHelper/`** überschatten (Symptome: z. B. `validateInvestmentAmountOrdering is not a function`, falsche FAQ-Platzhalter).
- **Nie** `cloud/utils/configHelper.js` ins Repo legen oder von Backups auf den Host zurückspielen.

## Vor Commit / Deploy

- `./scripts/check-parse-cloud-config-helper-shadow.sh` ausführen (scheitert, falls `cloud/utils/configHelper.js` existiert).

## Deploy & Doku

- Nach Änderungen: vgl. **`ci-cd.md`** → Abschnitt **FIN1-Server Deploy** (rsync `cloud/`, Parse-Restart, ggf. `rm` Legacy-Datei wie in `scripts/deploy-to-ubuntu.sh`).
- Betrieb: **`Documentation/FIN1_APP_DOCS/06A_BACKEND_UBUNTU_IOBOX_RUNBOOK.md`** **§ 8.2.1**.

## Stil im Cloud-Code

- Neue Logik in passende **`functions/`** / **`triggers/`** / **`utils/`**-Module auslagern; **`main.js`** nur registrieren (`require`), nicht als Sammelplatte für große Handler.
- Berechtigungen: **`utils/permissions`** — nicht Rollen-Strings hardcoden, wo zentral definiert.
