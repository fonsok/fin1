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
- `./scripts/check-parse-cloud-naming-conventions.sh` ausführen (Datei-/Endpoint-Naming, Temp-/Legacy-Namen).

## Deploy & Doku

- Nach Änderungen: vgl. **`ci-cd.md`** → Abschnitt **FIN1-Server Deploy** (rsync `cloud/`, Parse-Restart, ggf. `rm` Legacy-Datei wie in `scripts/deploy-to-ubuntu.sh`).
- Betrieb: **`Documentation/FIN1_APP_DOCS/06A_BACKEND_UBUNTU_IOBOX_RUNBOOK.md`** **§ 8.2.1**.

## Stil im Cloud-Code

- Neue Logik in passende **`functions/`** / **`triggers/`** / **`utils/`**-Module auslagern; **`main.js`** nur registrieren (`require`), nicht als Sammelplatte für große Handler.
- Berechtigungen: **`utils/permissions`** — nicht Rollen-Strings hardcoden, wo zentral definiert.
- Naming-Matrix für Parse Cloud: `Documentation/PARSE_CLOUD_NAMING_CONVENTIONS.md`.

## Modularisierung & Refactor-Policy (Risiko)

Ziel ist **weniger Fehlerfläche** und bessere Reviews — nicht nur kürzere Dateien.

### Wann splitten?

- Datei deutlich über **~250 Zeilen** *oder*
- **mehrere fachliche Verantwortlichkeiten** in einem Modul (z. B. Validierung + Posting + Persistenz vermischt) *oder*
- **ökonomisch/regulatorisch heikle** Pfade (Buchungen, Gebühren, Settlement, Reconciliation, Idempotenz).

**Reine Zeilenzahl** allein ist kein ausreichender Treiber — entscheidend ist **klare Verantwortung** und **sichere fachliche Invarianten** (Double-Entry, Rundung, Storno/Correction, Replay).

### Vor / während Umbau (kritische Domänen)

- Für **Geld-, Ledger-, Invoice-, Trade-/Investment-Settlement-Pfade**: vor oder im **selben PR** wie strukturelle Änderungen **Abdeckung sichern** — bestehende Integration/Contract-Tests erweitern oder neue **Characterization-/Referenzfälle** ergänzen („Golden“-Outputs oder feste Fixture-Erwartungen), statt nur Code zu verschieben.
- **Keine** bewusste Verhaltensänderung ohne explizite Produkt-/Finance-Freigabe und Test-Delta.

### Schnittlinien (Domäne vor Technik)

- Bevorzugt trennen nach: **Eingabe/Validierung**, **Domänenregeln**, **Posting-/Journal-Aufbau**, **Parse-Persistenz**, **Reconciliation/Audit** — nicht nur „eine Cloud Function = eine Datei“, wenn dadurch Domänen auseinanderfallen oder dupliziert werden.
- **Trigger** bleiben **dünn** (registrieren, Kontext, Delegation); schwere Logik in benachbarten Modulen (`*Trigger*.js`, `*Posting*.js`, `utils/…`), damit Retries und Tests die Logik ohne Trigger-Rahmen anfassen können.

### Idempotenz & Konsistenz

- Bestehende **Duplicate-Guards**, **batchId/referenceId**-Strategien und **unique** Annahmen nicht „refactorbedingt“ lockern.
- Neue schreibende Flows: **Idempotenz** explizit benennen (welcher Schlüssel verhindert Doppelbuch? was passiert bei Retry?).

### Abnahme (Minimum pro PR)

- `node --check` auf geänderte Dateien; **`npx jest`** im Ordner `backend/parse-server/cloud` (oder gezielte Suites für berührte Domänen).
- Wo möglich: **kein Diff** in numerischen Referenzoutputs für definierte Fixtures ohne Absprache.

### Was diese Policy absichtlich nicht ersetzt

- Architektur-Entscheide zu **Transaktionsgrenzen**, **eventual consistency** und **Kompensation** bleiben **ADR-/Runbook-Doku** — bei neuen Grenzen dort nachziehen, nicht nur Code splitten.

Kurzfassung für Leser im Repo: [`Documentation/ENGINEERING_GUIDE.md`](../Documentation/ENGINEERING_GUIDE.md) → Abschnitt *Parse Cloud: Modularisierung und Refactor-Policy*.
