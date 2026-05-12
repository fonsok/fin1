# Cursor Rules Directory

This directory contains persistent rules that are automatically applied to all Cursor AI conversations in this project.

## Structure

### Core Rules
- **`architecture.md`** - Main project architecture, MVVM patterns, DI, backend integration, class vs struct best practices, and coding standards (always applied)
- **`compliance.md`** - Compliance and regulatory rules (MiFID II, pre-trade checks, audit logging, risk management) (always applied)
- **`dry-constants.md`** - DRY principles and constants management (always applied)
- **`swiftlint.md`** - SwiftLint configuration and code quality rules (auto-applied for `*.swift` files)
- **`ci-cd.md`** - CI/CD workflow requirements and best practices (auto-applied globally)
- **`responsive-design.md`** - Responsive design system compliance rules (auto-applied for `*.swift` files in `FIN1/Features/**/Views/**`)
- **`testing.md`** - Testing patterns, mocking standards, and repository testing (always applied)

### Backend (Parse Cloud)
- **`parse-cloud.md`** - Parse Cloud Code unter `backend/parse-server/cloud/**`: `configHelper/index.js`, Shadowing vermeiden, Guard-Skript, Deploy/Doku-Verweise (auto-applied per `filePatterns`)
- **`parse-cloud-naming.md`** - Parse Cloud Naming-Convention-Matrix: Datei-/Funktionsnamen, Verbpraefixe, Verbot von Temp-/Legacy-Namen (auto-applied per `filePatterns`)

### Admin Portal
- **`admin-portal.md`** - React/TypeScript Admin Web Portal: API layer, TanStack Query, Sortierung (`listSortOrder` / `applyQuerySort`), Parse-Datumswerte, Production-Deploy-Pfad, Freigaben-Filter (auto-applied for `admin-portal/**`)

### Legacy
- **`.cursorrules`** (repository root) - **DEPRECATED**: Kept for backward compatibility. All rules migrated to `.cursor/rules/`.

## How Rules Are Applied

Rules in this directory are automatically loaded by Cursor. You can configure:
- **`alwaysApply: true`** - Rule applies to all conversations
- **`filePatterns`** - Rule applies only when editing files matching glob patterns
- **`excludedPaths`** - Paths where rule should not apply

## Reference Config Files

These rules reference configuration files in the repository:
- `.swiftlint.yml` - SwiftLint rules configuration
- `.github/workflows/ci.yml` - Main CI pipeline
- `.github/workflows/responsive-design-compliance.yml` - Responsive design checks
- `.cursorrules` - **DEPRECATED**: Legacy file kept for backward compatibility. Use `.cursor/rules/` instead.

## Adding New Rules

To add a new rule file:
1. Create a `.md` file in this directory
2. Include metadata at the top (YAML frontmatter) specifying when to apply
3. Document the rules clearly with examples

Example rule file structure:
```markdown
---
alwaysApply: true
# or
filePatterns: ["*.swift", "**/Views/**"]
---

# Rule Title

Rule description and enforcement...
```


