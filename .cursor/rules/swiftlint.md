---
filePatterns: ["*.swift"]
alwaysApply: true
---

# SwiftLint Configuration Rules

This rule file incorporates and references `.swiftlint.yml` configuration.

## SwiftLint Configuration Reference

The project uses SwiftLint with custom rules defined in `.swiftlint.yml`. Always enforce these rules when working with Swift code.

### Standard Rules

- **Disabled**: `trailing_whitespace`, `line_length`
- **Opt-in**: `force_unwrapping` (warning severity), `empty_count`
- **Included paths**: `FIN1/`, `FIN1Tests/`
- **Excluded paths**: `FIN1/Documentation`, `FIN1.xcodeproj`, `FIN1/Assets.xcassets`
- **Identifier naming**: Minimum 3 characters (exceptions: `id`, `x`, `y`)

### Custom ResponsiveDesign Rules

All UI measurements must use the `ResponsiveDesign` system. These are enforced as **errors**:

1. **No Fixed Fonts**: Use `ResponsiveDesign.titleFont()`, `ResponsiveDesign.headlineFont()`, etc. instead of `.font(.title)`
2. **No Fixed Spacing**: Use `ResponsiveDesign.spacing(N)` instead of `VStack(spacing: 16)`
3. **No Excessive VStack Spacing**: VStack spacing should be ≤ 16pt (`ResponsiveDesign.spacing(6)` recommended)
4. **No ResponsivePadding in Main Views**: Use `.padding(.horizontal, ResponsiveDesign.horizontalPadding()) + .padding(.top, ResponsiveDesign.spacing(8))` instead
5. **No Fixed Corner Radius**: Use `ResponsiveDesign.spacing(N)` for all corner radius values
6. **No Fixed Padding**: Use `ResponsiveDesign.spacing(N)` or `.responsivePadding()` (where allowed)

### MVVM Architecture Rules

These rules enforce proper MVVM and dependency injection patterns:

1. **No ViewModel Instantiation in View Body**: ViewModels must be created in `init()`, not in property declaration
   - ❌ `@StateObject private var viewModel = SomeViewModel()`
   - ✅ `@StateObject private var viewModel: SomeViewModel` with `init()`

2. **No Singleton Usage Outside Composition Root**: Use dependency injection instead
   - ❌ `SomeService.shared`
   - ✅ Inject via constructor: `init(service: SomeServiceProtocol)`
   - Excluded: `FIN1App.swift` and system singletons (`UIApplication.shared`, `NotificationCenter.default`, etc.)

3. **No Private Service Initializers**: Services must have public `init()` for proper DI
   - ❌ `private init()`
   - ✅ `init()`

4. **No Deprecated NavigationView**: Use `NavigationStack` instead
   - ❌ `NavigationView`
   - ✅ `NavigationStack`

5. **No ViewModel Properties in Services**: Services handle data/business logic only
   - ❌ `@Published var viewModel = SomeViewModel()`
   - ✅ Services contain data/models, not ViewModels

6. **No Direct Service Access in Views**: Use `@Environment(\.appServices)`
   - ❌ `AppServices.live.serviceName`
   - ✅ `@Environment(\.appServices)` then `appServices.serviceName`

7. **No Hardcoded Service Dependencies**: Inject via constructor
   - ❌ `private let service = SomeService.shared`
   - ✅ `private let service: SomeServiceProtocol` with constructor injection

## Enforcement

All these rules are enforced as **errors** in SwiftLint. Code that violates these rules will fail CI checks.

## Automated Detection Patterns

### SwiftLint Custom Rules

SwiftLint custom rules detect MVVM violations in real-time:
- `@StateObject.*=.*ViewModel\(` (direct instantiation)
- `\.shared` (singleton usage outside composition root)
- `private init\(\)` (private service initializers)
- `NavigationView` (deprecated navigation)
- `\.font\(\.title\)` (fixed font sizes)
- `VStack\(spacing: [0-9]+\)` (fixed spacing values)
- `private var.*: \[.*\] \{.*Dictionary\(grouping:` (data grouping in Views - FORBIDDEN)
- `private var.*: \[.*\] \{.*\.filter\(` (filtering in Views - FORBIDDEN)
- `private var.*: \[.*\] \{.*\.map\(` (mapping in Views - FORBIDDEN)
- `private var.*: \[.*\] \{.*calendar\.component` (calendar calculations in Views - FORBIDDEN)
- `private var.*: \[.*\] \{.*\.sorted\(` (sorting in Views - FORBIDDEN)
- `struct.*View.*\{.*private.*func.*process` (processing functions in Views - FORBIDDEN)
- `struct.*View.*\{.*private.*func.*calculate` (calculation functions in Views - FORBIDDEN)
- `struct.*View.*\{.*private.*func.*group` (grouping functions in Views - FORBIDDEN)
- `\.(formatted|formattedAs|formattedAsLocalized)` (data formatting in Views - FORBIDDEN)
- `\.formatted\(date:` (date formatting in Views - FORBIDDEN)
- Model property access without ViewModel (warning)
- `^class.*ViewModel.*\{` (non-final ViewModel - should be `final class`)
- `^class.*Service.*\{` (non-final Service - should be `final class`)
- `^class.*Coordinator.*\{` (non-final Coordinator - should be `final class`)
- `^class.*Repository.*\{` (non-final Repository - should be `final class`)
- `.*Manager` (use of "Manager" suffix - prefer Service, Repository, Store, Coordinator, Provider, Configurator, or Utility)

### MVVM Validation Script

Deep analysis script (`scripts/validate-mvvm-architecture.sh`) checks:
- Missing ViewModels for model-based Views
- Data/date formatting in Views
- Business logic in Views
- ViewModel instantiation patterns
- Direct service access
- ViewModel file existence verification

### Pre-commit Hooks

Run architecture validation before commits (automatically runs MVVM validation).

### CI Checks

Automated detection of architectural violations.

### Code Review

Mandatory review of architectural changes.

## Running SwiftLint

- Check: `swiftlint --strict`
- Fix auto-fixable issues: `swiftlint --fix`


