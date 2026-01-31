---
alwaysApply: true
---

# Local Development & Code Quality Rules

This rule file incorporates local development requirements. The `.github/workflows/ci.yml` file is a reference configuration for when CI is available, but all checks must pass **locally** before committing.

**Note**: These rules apply regardless of GitHub connectivity. All validations are performed locally.

## Local Build and Test Requirements

All code changes must pass these local checks (matching what would run in CI if available):

1. **SwiftFormat Check**: `swiftformat . --lint`
   - Code must be properly formatted
   - Run `swiftformat .` locally before committing

2. **SwiftLint Check**: `swiftlint --strict`
   - All SwiftLint rules must pass (see `swiftlint.md` rule file)
   - No warnings or errors allowed

3. **Build Test**: Builds for iOS Simulator (iPhone 15 Pro)
   - Build command: `xcodebuild -project FIN1.xcodeproj -scheme FIN1 -sdk iphonesimulator -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 15 Pro' build`
   - **MANDATORY**: If build fails, repeat builds until all errors are fixed and "BUILD SUCCEEDED" is achieved
   - Never commit code that doesn't build successfully

4. **Unit Tests**: All tests must pass
   - Test command: `xcodebuild -project FIN1.xcodeproj -scheme FIN1 -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15 Pro' test`
   - Use test plan: `FIN1/FIN1.xctestplan`

5. **Danger (Optional)**: For projects with CI/CD, Danger can run automated code review checks
   - Dangerfile.swift contains review rules
   - **Not required for local development**

### Environment

- **Xcode**: `/Applications/Xcode.app`
- **Tools**: SwiftLint, SwiftFormat installed via Homebrew (or locally)
- **Note**: Danger is optional and only required if using CI/CD with GitHub

### Pre-Commit Requirements

Before committing, ensure:
1. ✅ `swiftformat . --lint` passes
2. ✅ `swiftlint --strict` passes
3. ✅ Build succeeds - must see "BUILD SUCCEEDED" (retry until all errors fixed)
4. ✅ Tests pass locally

### Responsive Design Compliance

Local validation (see also `responsive-design.md` rule file):
- Run `scripts/check-responsive-design.sh` to validate ResponsiveDesign usage
- SwiftLint automatically enforces ResponsiveDesign rules (see `.swiftlint.yml`)
- Verify build and tests pass with ResponsiveDesign-compliant code

**Note**: `.github/workflows/responsive-design-compliance.yml` is a reference for CI setup, but validation happens locally.

## Local Development Commands

Reference these commands from `.cursorrules`:

- **Lint format**: `swiftformat . --lint`
- **SwiftLint**: `swiftlint --strict`
- **Format code**: `swiftformat .`
- **Build (sim)**: `xcodebuild -project FIN1.xcodeproj -scheme FIN1 -sdk iphonesimulator -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 15 Pro' build`
- **Test (sim)**: `xcodebuild -project FIN1.xcodeproj -scheme FIN1 -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15 Pro' test`

## Code Quality Requirements

All code changes must:
1. Pass all local checks (formatting, linting, build, tests)
2. Have no SwiftLint warnings or errors
3. Follow MVVM architecture patterns (see `.cursorrules`)
4. Use ResponsiveDesign system (see `responsive-design.md`)
5. Pass all tests before committing

**Note**: If you have CI/CD set up later, these same checks will run automatically.

## Build Retry Policy

**CRITICAL**: When a build fails or before committing:
1. Analyze all build errors and warnings
2. Fix all compilation errors
3. Address all warnings (treat as errors)
4. Re-run the build: `xcodebuild -project FIN1.xcodeproj -scheme FIN1 -sdk iphonesimulator -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 15 Pro' build`
5. If build still fails, repeat steps 1-4 until you see **"BUILD SUCCEEDED"**
6. **Before committing**: Build must succeed - never commit code that doesn't build

**Rationale**: You can make iterative changes during development, but always verify the build succeeds:
- Before committing code
- When you intentionally run a build to check status
- Before moving to a different task/feature

**Never commit code that doesn't build successfully.**

## Failure Prevention

When making code changes:
- Make iterative changes as needed during development
- **Before committing**: Verify build succeeds - if it fails, fix all errors and rebuild until "BUILD SUCCEEDED"
- Run linting/formatting checks before committing
- Ensure tests pass before committing
- Check for any new SwiftLint violations
- Follow all architectural patterns defined in `.cursorrules`
- All validation happens **locally** - no external services required

