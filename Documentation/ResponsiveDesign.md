# ResponsiveDesign System Guide

## Overview

The ResponsiveDesign system ensures consistent, adaptive UI across all device sizes, orientations, and accessibility settings. **All UI code MUST use this system** - fixed values are forbidden.

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

### Main View Spacing Standards
The following main views have been optimized for better space utilization and must maintain these patterns:

#### Dashboard (`DashboardContainer.swift`)
```swift
// ✅ REQUIRED - Optimized spacing
VStack(spacing: ResponsiveDesign.spacing(6)) {
    // content
}
.padding(.horizontal, ResponsiveDesign.horizontalPadding())
.padding(.top, ResponsiveDesign.spacing(8))

// ❌ FORBIDDEN - Excessive spacing
VStack(spacing: ResponsiveDesign.spacing(24)) { // Too much!
    // content
}
.responsivePadding() // Adds excessive vertical padding
```

#### Securities Search (`SecuritiesSearchView.swift`)
```swift
// ✅ REQUIRED - Optimized spacing
VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(6)) {
    // content
}
.padding(.horizontal, ResponsiveDesign.horizontalPadding())
.padding(.top, ResponsiveDesign.spacing(8))

// ❌ FORBIDDEN - Excessive spacing
VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(16)) { // Too much!
    // content
}
.responsivePadding() // Adds excessive vertical padding
```

#### Depot (`TraderDepotView.swift`)
```swift
// ✅ REQUIRED - Optimized spacing
VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(6)) {
    // content
}
.padding(.horizontal, ResponsiveDesign.horizontalPadding())
.padding(.top, ResponsiveDesign.spacing(8))

// ❌ FORBIDDEN - Excessive spacing
VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(16)) { // Too much!
    // content
}
.responsivePadding() // Adds excessive vertical padding
```

### Regression Protection
These spacing optimizations are protected by:
- **SwiftLint Rules**: Automatic detection of excessive spacing
- **Pre-commit Hooks**: Validation before each commit
- **Regression Tests**: Automated tests in `UISpacingRegressionTests.swift`
- **CI/CD Checks**: GitHub Actions enforce compliance

**⚠️ CRITICAL**: Do not revert these spacing optimizations. They provide:
- 75% reduction in vertical spacing
- Better space utilization
- Improved user experience
- Modern UI feel

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

1. **Find patterns**: Search for `.font(\.`, `VStack(spacing:`, `.cornerRadius(`
2. **Replace systematically**: Use find/replace with regex
3. **Test thoroughly**: Verify on multiple devices
4. **Run checks**: Use automated tools to verify

## Support

For questions or issues:
1. Check this documentation
2. Run compliance checker: `./scripts/check-responsive-design.sh`
3. Review ResponsiveDesign.swift implementation
4. Ask team for guidance
