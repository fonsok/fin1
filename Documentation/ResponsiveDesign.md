# ResponsiveDesign System Guide

## Overview

The ResponsiveDesign system ensures consistent, adaptive UI across all device sizes, orientations, and accessibility settings. **All UI code MUST use this system** - fixed values are forbidden.

## Swift 6 concurrency (`@MainActor`)

- **`ResponsiveDesign`** (in `FIN1/Shared/Components/ResponsiveDesign.swift`) is marked **`@MainActor`** because it reads **`UIScreen`** / **`UIApplication`**. Call it from **`View.body`**, other **`@MainActor`** types, or top-level helpers marked **`@MainActor`** (see e.g. `CompanyKybStepHelpers.swift`).
- **`ComponentFactory`** is **`@MainActor`** for the same reason.
- **Exception — `TextFieldStyle`:** `TextFieldStyle._body` is **not** MainActor-isolated. Styles such as **`SettingsTextFieldStyle`** / **`SettingsSecureFieldStyle`** in `SettingsToggleRow.swift` use **fixed point** padding and corner radius (aligned with the 1.0 scale of `ResponsiveDesign.spacing`) **with an inline comment** instead of calling `ResponsiveDesign.spacing` inside `_body`.

### Wrapping filter chips (`Layout` protocol)

`ChipFlowLayout` in **`FIN1/Shared/Components/Search/FilterChip.swift`** uses a private **`HorizontalChipFlowLayout: Layout`** so chips wrap horizontally within the proposed width. This replaces the older `GeometryReader` + `alignmentGuide` approach (which tripped Swift 6 concurrency checks) while keeping **`ResponsiveDesign.spacing`** for inter-chip spacing in the **`@MainActor`** view.

## Quick Reference

### Fonts
```swift
// ❌ FORBIDDEN
.font(.title)
.font(.headline)
.font(.subheadline)
.font(.body)
.font(.caption)

// ✅ REQUIRED
.font(ResponsiveDesign.titleFont())
.font(ResponsiveDesign.headlineFont())
.font(ResponsiveDesign.bodyFont())
.font(ResponsiveDesign.captionFont())
```

### Spacing Optimization (Critical)

#### Flat list layout (default for scrollable screens)

Most feature screens (dashboard, sign-up, profile, depot shell, account statement, investments, CSR dashboard) use **full-width zebra bands** instead of nested scroll cards. Padding lives **per section**, not on an outer wrapper.

**SSOT:** `FIN1/Shared/Components/StripedListSection.swift` — `StripedStepList`, `stripedListSection`, `PaddedFormSectionList`. Sign-up uses the alias `signUpListSection` (`SignUpSectionStyle.swift`).

```swift
ScrollView {
    StripedStepList {
        MyHeaderView()
            .stripedListSection(stripeIndex: 0)

        MyContentSection()
            .stripedListSection(stripeIndex: 1)
    }
    .padding(.bottom, ResponsiveDesign.spacing(16))
}
```

- Each `.stripedListSection` applies `ResponsiveDesign.mainHorizontalPadding()` and vertical band padding internally.
- Stack sections with `VStack(spacing: ResponsiveDesign.spacing(0))` inside `StripedStepList` (never raw `spacing: 0`).
- **Screen canvas:** status bar, window, and **even** zebra bands (`stripeIndex` 0, 2, …) = `ScreenBackground` via `StripedListStyle.canvasBackgroundColor` / `AppTheme.stripedCanvasBackground`. **Odd** bands add a 28% black overlay (see `FIN1/Documentation/COLOR_SETUP.md`).
- **Data tables:** title/metadata in `stripedListSection`; table rows in a separate shell (`InvestmentsTableStyle`, `solidBackground:` on rows). See `.cursor/rules/architecture.md` → *Flat list layout*.
- **Deprecated:** `scrollSection()` / `ScrollSectionModifier`, outer card wrapping inner section cards.

**Collapsible sections & pagination:** `FIN1/Shared/Components/ListSection/` (`CollapsibleListSectionHeader`, `ListPaginationBar`, `ClientSideListPagination`).

#### Main view spacing validation

`scripts/validate-main-view-spacing.sh` (pre-commit + CI) protects Dashboard, Securities Search, and Depot:

| Screen | Pattern |
|--------|---------|
| **Dashboard**, **Depot** | `StripedStepList` + `stripedListSection` (no outer `.padding(.horizontal, …)` required) |
| **Securities Search** | Legacy: outer `VStack` + `.padding(.horizontal, ResponsiveDesign.horizontalPadding())` + `.padding(.top, ResponsiveDesign.spacing(8))` until migrated |

```swift
// ✅ Securities Search (legacy — not yet on StripedStepList)
VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(6)) {
    // content
}
.padding(.horizontal, ResponsiveDesign.horizontalPadding())
.padding(.top, ResponsiveDesign.spacing(8))

// ❌ FORBIDDEN on main views
.responsivePadding() // excessive vertical padding on scroll roots
VStack(spacing: ResponsiveDesign.spacing(24)) { … } // excessive section gap
```

#### Regression protection

- **`./scripts/check-responsive-design.sh`** — no fixed fonts/spacing/padding literals
- **`./scripts/validate-main-view-spacing.sh`** — Dashboard / Depot / Securities Search (StripedStepList-aware)
- **Pre-commit hooks** and **CI** (`responsive-design-compliance.yml`, `ci.yml`)
- **`UISpacingRegressionTests.swift`** where applicable

Do not reintroduce nested scroll cards or `.responsivePadding()` on main scroll roots.

### Corner Radius
```swift
// ❌ FORBIDDEN
.cornerRadius(12)
RoundedRectangle(cornerRadius: 8)

// ✅ REQUIRED
.cornerRadius(ResponsiveDesign.spacing(12))
RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(8))
```

### Icon Sizes
```swift
// ❌ FORBIDDEN
.font(.title3)
.font(.system(size: 24))

// ✅ REQUIRED
.font(.system(size: ResponsiveDesign.iconSize()))
.font(.system(size: ResponsiveDesign.iconSize() * 1.5))
```

## Available Methods

### Font Methods
- `ResponsiveDesign.titleFont()` - For main titles
- `ResponsiveDesign.headlineFont()` - For section headers
- `ResponsiveDesign.bodyFont()` - For body text
- `ResponsiveDesign.captionFont()` - For small text

### Spacing Methods
- `ResponsiveDesign.spacing(N)` - For any spacing value
- `.responsivePadding()` - For standard padding

### Icon Methods
- `ResponsiveDesign.iconSize()` - Base icon size
- `ResponsiveDesign.iconSize() * multiplier` - Scaled icons

## Enforcement

### Automated Checks
- **SwiftLint**: Custom rules catch violations during development
- **Pre-commit Hook**: Prevents commits with violations
- **CI/CD**: GitHub Actions enforce compliance on PRs
- **Manual Script**: `./scripts/check-responsive-design.sh`

### Manual Verification
```bash
# Check compliance
./scripts/check-responsive-design.sh

# Run SwiftLint
swiftlint --strict

# Format code
swiftformat .
```

## Best Practices

1. **Always use ResponsiveDesign methods** - Never hardcode values
2. **Test on multiple devices** - iPhone SE to iPad Pro
3. **Test accessibility** - Dynamic Type, VoiceOver
4. **Test orientations** - Portrait and landscape
5. **Use semantic values** - Choose appropriate font/spacing methods

## Common Patterns

### Card Components
```swift
VStack(spacing: ResponsiveDesign.spacing(12)) {
    Text("Title")
        .font(ResponsiveDesign.headlineFont())

    Text("Content")
        .font(ResponsiveDesign.bodyFont())
}
.padding(ResponsiveDesign.spacing(16))
.background(Color.fin1SectionBackground)
.cornerRadius(ResponsiveDesign.spacing(12))
```

### Button Components
```swift
Button("Action") {
    // action
}
.font(ResponsiveDesign.headlineFont())
.padding(ResponsiveDesign.spacing(12))
.background(Color.fin1AccentGreen)
.cornerRadius(ResponsiveDesign.spacing(8))
```

### Icon with Text
```swift
HStack(spacing: ResponsiveDesign.spacing(8)) {
    Image(systemName: "star")
        .font(.system(size: ResponsiveDesign.iconSize()))

    Text("Label")
        .font(ResponsiveDesign.bodyFont())
}
```

## Troubleshooting

### Build Errors
If you see errors about missing ResponsiveDesign methods:
1. Ensure `import SwiftUI` is present
2. Check that ResponsiveDesign.swift is included in target
3. Verify method names match exactly

### Linting Errors
If SwiftLint reports violations:
1. Replace fixed values with ResponsiveDesign methods
2. Use `.responsivePadding()` instead of `.padding(ResponsiveDesign.spacing())`
3. Run `swiftformat .` to fix formatting

### Performance
The ResponsiveDesign system is optimized for performance:
- Methods are computed once per view update
- No runtime overhead for static values
- Efficient caching of computed values

## Migration Guide

When updating existing code:

1. **Scrollable feature screens:** migrate `scrollSection()` / nested cards → `ScrollView` + `StripedStepList` + `stripedListSection` (see *Flat list layout* above).
2. **Find fixed literals:** search for `.font(\.`, `VStack(spacing:`, `.cornerRadius(`
3. **Replace systematically:** use ResponsiveDesign methods; `spacing: 0` → `ResponsiveDesign.spacing(0)`.
4. **Run checks:** `./scripts/check-responsive-design.sh`, `./scripts/validate-main-view-spacing.sh`

## Support

For questions or issues:
1. Check this documentation
2. Run compliance checker: `./scripts/check-responsive-design.sh`
3. Review ResponsiveDesign.swift implementation
4. Ask team for guidance
