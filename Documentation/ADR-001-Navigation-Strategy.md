# ADR-001: Navigation Strategy

## Status
**ACCEPTED** - Effective immediately

## Context
The FIN1 app currently uses inconsistent navigation patterns that lead to:
- Navigation context loss (missing nav bars, tab bars)
- Silent navigation failures
- Inconsistent user experience
- Complex debugging and maintenance

## Decision
We will standardize on modern SwiftUI navigation patterns:

### 1. Navigation Container
- **Use `NavigationStack` (iOS 16+) for all navigation containers**
- **Deprecate `NavigationView` for new code**
- **Migrate existing `NavigationView` instances gradually**

### 2. Navigation Patterns
- **Use `NavigationLink(value:)` + `navigationDestination` for navigation**
- **Use `.sheet()` only for forms, modals, and temporary content**
- **Never use `.sheet()` for navigation that should maintain context**

### 3. Navigation Context Preservation
- **Always maintain navigation bar and tab bar visibility**
- **Ensure consistent navigation hierarchy**
- **Preserve user's navigation state**

## Rationale

### Why NavigationStack over NavigationView?
- `NavigationStack` supports modern navigation APIs (`navigationDestination`)
- Better performance and memory management
- Future-proof (NavigationView is deprecated)
- Consistent behavior across iOS versions

### Why NavigationLink + navigationDestination over .sheet()?
- Maintains navigation context (nav bar, tab bar)
- Consistent user experience
- Proper navigation hierarchy
- Better accessibility support

### Why .sheet() only for modals?
- Sheets break navigation context
- Should only be used for temporary content
- Forms, settings, and confirmations are appropriate use cases

## Implementation Guidelines

### ✅ Correct Patterns

```swift
// Navigation between screens
NavigationLink(value: item) {
    Text("Go to Detail")
}
.navigationDestination(for: Item.self) { item in
    DetailView(item: item)
}

// Modal for forms/settings
.sheet(isPresented: $showSettings) {
    SettingsView()
}
```

### ❌ Incorrect Patterns

```swift
// DON'T: Use NavigationView
NavigationView {
    // content
}

// DON'T: Use .sheet() for navigation
.sheet(item: $selectedItem) { item in
    DetailView(item: item) // This breaks navigation context
}

// DON'T: Mix navigation patterns
NavigationView {
    NavigationLink(value: item) { ... } // Won't work
}
```

## Migration Strategy

### Phase 1: Critical Views (Immediate)
- Authentication views (Login, SignUp)
- Core trader views (Depot, Trades)
- Core investor views (Discovery, Portfolio)
- Profile/Settings views

### Phase 2: Secondary Views (Next Sprint)
- Search views
- Filter views
- Detail views

### Phase 3: Remaining Views (Following Sprint)
- All remaining NavigationView instances
- Cleanup and testing

## Consequences

### Positive
- Consistent navigation behavior
- Reduced debugging complexity
- Better user experience
- Future-proof architecture
- Easier maintenance

### Negative
- Requires iOS 16+ (already supported)
- Migration effort for existing code
- Learning curve for developers

## Compliance

### Code Review Requirements
- All new navigation code must follow this ADR
- Existing code must be migrated when modified
- No new NavigationView instances allowed

### Testing Requirements
- Navigation flows must be tested
- Verify navigation context preservation
- Test on multiple device sizes

## Examples

### Before (Problematic)
```swift
NavigationView {
    List {
        ForEach(items) { item in
            Button("View Details") {
                selectedItem = item
            }
        }
    }
    .sheet(item: $selectedItem) { item in
        DetailView(item: item) // Breaks navigation context
    }
}
```

### After (Correct)
```swift
NavigationStack {
    List {
        ForEach(items) { item in
            NavigationLink(value: item) {
                Text("View Details")
            }
        }
    }
    .navigationDestination(for: Item.self) { item in
        DetailView(item: item) // Maintains navigation context
    }
}
```

## Review Date
This ADR will be reviewed in 3 months to assess migration progress and update guidelines as needed.

---
**Approved by:** Development Team
**Date:** December 2024
**Version:** 1.0
