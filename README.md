# FIN1

**Stand:** 2026-02-01
**Ziel:** Dritter soll in 1–20 Minuten den aktuellen Stand finden.

## ⭐ Start here

- `START_HERE.md`
- `FIN1_PROJECT_STATUS.md`
- Kuratierte Gesamtdoku: `Documentation/FIN1_APP_DOCS/00_INDEX.md`
- Snapshots/Tags Index: `Documentation/SNAPSHOTS_INDEX.md`

## Hinweis zur Dokument-Logik

Wenn es zu einem Thema eine Datei `*-vYYYY-MM-DD.md` gibt, ist diese Datei die **aktuelle Referenz**. Die nicht-versionierte Datei ist dann nur ein **Pointer**.

## Setup

- iOS App: `FIN1.xcodeproj` in Xcode öffnen
- Backend: `backend/README.md` (Docker Compose Quickstart)

## GitHub & CI

- Remote: `origin` → Hauptbranch **`main`** (nach dem ersten Push: `git push -u origin main`).
- CI: [`.github/workflows/ci.yml`](.github/workflows/ci.yml) (Parse-Smoke, Parse-Jest, Admin-Portal, macOS Build/Test/Lint).
- Erweiterte iOS-Tests (wöchentlich / manuell): [`.github/workflows/ios-extended-tests.yml`](.github/workflows/ios-extended-tests.yml). UI-Tests nur mit Repo-Variable `IOS_EXTENDED_RUN_UI_TESTS=true`.
- Beiträge: kurz [`CONTRIBUTING.md`](CONTRIBUTING.md).

