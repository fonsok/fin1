---
description: Proaktive Doku-Checkpoints während Cursor-Chats
alwaysApply: true
---

# Dokumentation: Proaktive Checkpoints im Chat

## Ziel
- Nach größeren/wichtigen Änderungen soll der Agent **automatisch** einen **Doku-Checkpoint** einfordern (und am Ende einen **Final-Doku-Run**).
- Dokumentiert wird **nur** in kanonischen Dateien (keine `-vYYYY-MM-DD` / `-YYYY-MM-DD` Dateinamen).
- **Nummerierte Doku (01–10)**: Kanonische App-Doku liegt unter `Documentation/FIN1_APP_DOCS/` mit Dateien `00_INDEX.md`, `01_...`, `02_...`, `03_...` usw. Neue oder thematische Inhalte dort in die passende nummerierte Datei integrieren; **keine zusätzlichen Implementierungs-Dateien** (z. B. kein separates `BELEGNUMMERN_IMPLEMENTATION.md` mit vollem Inhalt – stattdessen Abschnitt in `03_TECHNISCHE_SPEZIFIKATION.md` o. ä.).

## Wann der Agent einen Doku-Checkpoint anfordern muss (Trigger)
- Änderungen an **Build/Config/Infra**: `Info.plist`, `Config/*.xcconfig`, `*.xcscheme`, `docker-compose*.yml`, `backend/env*.example`, `backend/nginx/*.conf`, `backend/parse-server/index.js`
- Änderungen an **Policy/Guardrails**: `.cursor/rules/**`, `.githooks/**`, `scripts/**`
- Änderungen an **Compliance/Security/Legal** (egal wie klein)
- **Refactor/Rename/Delete** von Dateien oder Ordnern
- “Viele Änderungen”: \(\ge 15\) geänderte Dateien **oder** \(\ge 300\) geänderte Zeilen (grobe Heuristik)

## Checkpoint Output (kurz, 3–7 Bullet Points)
- **Was** wurde geändert (1 Satz)
- **Warum** (1 Satz)
- **Source of Truth**: welche Datei(n) sind jetzt kanonisch
- **Invarianten** (was darf niemand brechen)
- **Risiken** + **Mini-Testplan** (2–5 Checks)

## Prompt-Vorlagen (vom Agent proaktiv anbieten)

### Doku-Checkpoint (mitten im Chat)
> “Erstelle einen Doku-Checkpoint zu den bisherigen Änderungen: nenne die betroffenen Dateien, die neuen Invarianten/Regeln, und aktualisiere die passenden kanonischen Doku-Dateien. Gib außerdem einen Mini-Testplan.”

### Final-Dokumentation (am Ende)
> “Analysiere den Repo-Diff, gruppiere Änderungen nach Themen (Docs/Config/Backend/iOS/Scripts), aktualisiere die kanonische Doku, und liefere eine kurze Summary + Testplan. Keine `-vYYYY-MM-DD` Dateinamen; History erfolgt über Git.”

