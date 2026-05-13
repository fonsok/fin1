# Contributing to FIN1

## Git workflow

- **Default branch:** `main`
- **Remote:** `origin` (nach `git clone` bzw. `git remote add origin …`)
- **Policy C:** Größere Arbeit in **kleine PRs** splitten (z. B. nur Parse Cloud, nur iOS-Admin, nur CI) — siehe `Documentation/ENGINEERING_GUIDE.md` → PR Guardrails.

## Vor dem PR (lokal)

- **SwiftFormat** (gleiche Pfade wie CI):

  ```bash
  swiftformat FIN1 FIN1Tests FIN1UITests FIN1InvestorTests FIN1CoreRegressionTests --lint
  ```

  Bei Abweichungen:

  ```bash
  swiftformat FIN1 FIN1Tests FIN1UITests FIN1InvestorTests FIN1CoreRegressionTests
  ```

- **SwiftLint:** `swiftlint` (Projektroot)
- **Build/Test:** Xcode oder `scripts/run-ios-tests.sh` (siehe `.github/workflows/ci.yml`)

## CI auf GitHub

Nach Push/PR die Runs unter **Actions** prüfen. Variable **`IOS_EXTENDED_RUN_UI_TESTS`** nur setzen, wenn die optionalen UI-Tests im Workflow **iOS extended tests** mitlaufen sollen.
