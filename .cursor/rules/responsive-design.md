---
filePatterns: ["*.swift", "**/Features/**/Views/**", "**/Shared/Components/**"]
alwaysApply: true
---

# Responsive Design System Rules

This rule file enforces the ResponsiveDesign system compliance requirements referenced in `.github/workflows/responsive-design-compliance.yml` and `.swiftlint.yml`.

## Mandatory ResponsiveDesign Usage

**ALL UI measurements must use the `ResponsiveDesign` system. Fixed values are FORBIDDEN.**

### Font Sizes

❌ **FORBIDDEN**:
```swift
.font(.title)
.font(.headline)
.font(.body)
.font(.caption)
```

✅ **REQUIRED**:
```swift
.font(ResponsiveDesign.titleFont())
.font(ResponsiveDesign.headlineFont())
.font(ResponsiveDesign.bodyFont())
.font(ResponsiveDesign.captionFont())
.font(ResponsiveDesign.footnoteFont())
```

For **custom point sizes** (icons, template editors), use Dynamic Type scaling — **not** raw `.font(.system(size: …))`:

```swift
.font(ResponsiveDesign.scaledSystemFont(size: 16, weight: .medium))
.font(ResponsiveDesign.monospacedFont(size: 17, weight: .regular))
```

### Spacing Values

❌ **FORBIDDEN**:
```swift
VStack(spacing: 16)
HStack(spacing: 8)
.padding(12)
```

✅ **REQUIRED**:
```swift
VStack(spacing: ResponsiveDesign.spacing(6))
HStack(spacing: ResponsiveDesign.spacing(4))
.padding(.horizontal, ResponsiveDesign.horizontalPadding())
```

### VStack Spacing Limits

- **Maximum**: `ResponsiveDesign.spacing(6)` for main containers
- **Recommended**: `ResponsiveDesign.spacing(4)` for most use cases
- **Error**: Spacing values ≥ 24pt will fail CI

### Corner Radius

❌ **FORBIDDEN**:
```swift
.cornerRadius(12)
RoundedRectangle(cornerRadius: 8)
```

✅ **REQUIRED**:
```swift
.cornerRadius(ResponsiveDesign.spacing(3))
RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(2))
```

### Icon Sizes

Use `ResponsiveDesign.iconSize()` with multipliers and `scaledSystemFont` so sizes respect Dynamic Type:
```swift
Image(systemName: "star")
    .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize()))
```

### Padding

❌ **FORBIDDEN in Main Views**:
```swift
.responsivePadding()  // Not allowed in main views
```

✅ **REQUIRED for Main Views**:
```swift
.padding(.horizontal, ResponsiveDesign.horizontalPadding())
.padding(.top, ResponsiveDesign.spacing(8))
```

**Exceptions** (where `.responsivePadding()` is allowed):
- `FIN1/Features/Dashboard/Views/Components/DashboardContainer.swift`
- `FIN1/Features/Trader/Views/SecuritiesSearchView.swift`
- `FIN1/Features/Trader/Views/TraderDepotView.swift`
- `FIN1Tests/UISpacingRegressionTests.swift`

### Swift 6: `ResponsiveDesign` is `@MainActor`

- **Use** `ResponsiveDesign.*` from **`View` bodies**, **`@MainActor`** view helpers, or types marked **`@MainActor`** (e.g. layout enums that only run from SwiftUI).
- **`ComponentFactory`** is **`@MainActor`** — same rule.
- **Documented exception — `TextFieldStyle`:** `TextFieldStyle._body` is not MainActor-isolated. **`SettingsToggleRow.swift`** (`SettingsTextFieldStyle`, `SettingsSecureFieldStyle`) uses **fixed** `.padding` / `.cornerRadius` with a **comment** explaining the Swift 6 constraint (values match the usual 1.0 `ResponsiveDesign.spacing` scale). Do **not** copy that pattern into arbitrary views; only where protocol isolation forbids `ResponsiveDesign` calls.

## Automated Enforcement

### SwiftLint Rules

The following custom SwiftLint rules (from `.swiftlint.yml`) enforce compliance:
- `no_fixed_fonts` - Detects fixed font sizes
- `no_fixed_spacing` - Detects fixed spacing in VStack/HStack
- `no_excessive_vstack_spacing` - Enforces spacing limits
- `no_responsive_padding_in_main_views` - Enforces padding pattern
- `no_fixed_corner_radius` - Detects fixed corner radius
- `no_fixed_rounded_rectangle` - Detects fixed RoundedRectangle radius
- `no_fixed_padding` - Detects fixed padding values

All violations are treated as **errors** and will fail CI.

### CI Workflow

The `.github/workflows/responsive-design-compliance.yml` workflow:
1. Runs `scripts/check-responsive-design.sh`
2. Runs SwiftLint with strict mode
3. Verifies build and tests pass

## Accessibility

The ResponsiveDesign system automatically adapts to:
- Device sizes (iPhone SE to iPad Pro)
- Accessibility font size settings
- Orientation changes
- Dynamic Type settings

## Testing

When making UI changes:
1. Test on multiple device sizes
2. Test with accessibility font sizes enabled
3. Test in both portrait and landscape
4. Verify no fixed values are used
5. Run `swiftlint` (or `swiftlint --strict` to treat warnings as failures) to catch violations

## Examples

### ❌ WRONG - Fixed Values
```swift
struct BadView: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("Title")
                .font(.title)
                .padding(12)

            RoundedRectangle(cornerRadius: 8)
                .frame(height: 50)
        }
    }
}
```

### ✅ CORRECT - ResponsiveDesign
```swift
struct GoodView: View {
    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(4)) {
            Text("Title")
                .font(ResponsiveDesign.titleFont())
                .padding(.horizontal, ResponsiveDesign.horizontalPadding())

            RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(2))
                .frame(height: ResponsiveDesign.spacing(12))
        }
    }
}
```

## Reference

- Main documentation: `Documentation/ResponsiveDesign.md`
- README: `README-ResponsiveDesign.md`
- Validation script: `scripts/check-responsive-design.sh`



