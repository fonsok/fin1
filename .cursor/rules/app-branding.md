---
alwaysApply: true
---

# App Branding (App Name Must Be Configurable)

## Core Rule

- **Never hardcode the app name** (e.g., `"FIN1"`) in **user-facing** copy:
  - SwiftUI `Text(...)`, alerts, dialogs, onboarding, FAQs, help center, error messages shown to the user
  - Terms/Privacy content providers shown in the app UI
  - Email templates intended for customers

## Required Pattern

- Use `AppBrand.appName` for user-facing “app name” references.
- `AppBrand.appName` must read the app name from the bundle (`CFBundleDisplayName` → `CFBundleName` fallback) and only then fall back to a placeholder.

## Xcode “Display Name” Guardrail (Prevent Regressions)

- The **single source of truth** for the app name is: **Target → General → Identity → Display Name**.
- **Never commit** temporary/test values (e.g. `TTTT`, `test*`) to `FIN1.xcodeproj/project.pbxproj` via `INFOPLIST_KEY_CFBundleDisplayName`.
- If you temporarily change the Display Name for local testing, revert it immediately after.
- Keep the Display Name consistent across build configurations/schemes (Dev/Prod/Staging) unless you have an explicit, documented reason to differ.
- When diagnosing “wrong app name shown”, first run the guard and verify the effective setting:

```bash
./scripts/check-xcode-display-name-v2026-01-31.sh
xcodebuild -showBuildSettings -project FIN1.xcodeproj -scheme FIN1-Dev -configuration Debug | grep INFOPLIST_KEY_CFBundleDisplayName
```

## Git Hook Enforcement (Recommended)

- Ensure the pre-commit hook is installed so the Display Name guard runs automatically:

```bash
./scripts/install-githooks-v2026-01-31.sh
```

## Allowed Exceptions

- **Technical identifiers** that are not user-facing branding:
  - Target/product names, scheme names, module import names, bundle identifiers
  - File/folder names and internal color/style identifiers
- **Legal entity names** and accounting-relevant company identifiers must stay explicit and centralized (e.g., `CompanyContactInfo.companyName`), not replaced with `AppBrand.appName`.

## Examples

```swift
// ✅ Good
Text(AppBrand.appName)
Text("Sign in to \(AppBrand.appName)")

// ❌ Bad
Text("FIN1")
Text("Sign in to FIN1")
```

