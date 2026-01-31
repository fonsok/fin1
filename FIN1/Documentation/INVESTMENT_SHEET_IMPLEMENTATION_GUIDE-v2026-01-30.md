# Investment Sheet Feature - Complete Implementation Guide

## Overview

The Investment Sheet is a SwiftUI view that allows investors to create investments in traders. It provides a comprehensive interface for selecting investment amounts, choosing investment strategies (single or multiple pots), previewing pot allocations, and viewing investment summaries.

**Entry Point**: Investor Dashboard → Top Recent Trades table → Tap on a trader

**Key Features**:
- Investment amount input with currency formatting
- Investment strategy selection (Single Pot / Multiple Pots)
- Dynamic pot number selection (1-10 pots)
- Real-time pot allocation preview
- Investment summary with calculations
- Form validation and error handling
- Success/error alerts with automatic dismissal

---

## Table of Contents

1. [Layout Structure](#layout-structure)
2. [Styling System](#styling-system)
3. [Business Logic](#business-logic)
4. [Data Models](#data-models)
5. [State Management](#state-management)
6. [Validation Rules](#validation-rules)
7. [Error Handling](#error-handling)
8. [User Flow](#user-flow)
9. [Implementation Checklist](#implementation-checklist)

---

## Layout Structure

### Overall Container

```
NavigationView
└── ZStack
    ├── Color.fin1ScreenBackground (full screen background)
    └── ScrollView
        └── VStack (main content, spacing: 16)
            ├── Header Section
            ├── Investment Form Section
            ├── Pot Allocation Preview Section
            ├── Investment Summary Section
            └── Action Buttons Section
```

### 1. Header Section (`investmentHeaderView`)

**Structure**:
```
VStack (spacing: 12)
├── Circle (Avatar)
│   ├── Background: Color.fin1AccentLightBlue
│   ├── Size: 80x80
│   └── Overlay: First letter of trader username (white, bold)
├── Text: trader.username
│   ├── Font: .title2
│   ├── Weight: .semibold
│   └── Color: .fin1FontColor
└── Text: trader.specialization
    ├── Font: .subheadline
    ├── Color: .fin1FontColor.opacity(0.7)
    └── Alignment: .center
```

**Container Styling**:
- Background: `Color.fin1SectionBackground`
- Padding: Standard padding
- Corner Radius: 16

### 2. Investment Form Section (`investmentFormView`)

**Structure**:
```
VStack (spacing: 16)
├── Investment Amount Field
│   ├── Label: "Investment Amount" (.headline, .fin1FontColor)
│   └── HStack
│       ├── Currency Symbol: "€" (.title2, .fin1FontColor)
│       └── TextField
│           ├── Placeholder: "0.00"
│           ├── Keyboard Type: .decimalPad
│           ├── Font: .title2
│           ├── Text Color: .fin1InputText
│           ├── Background: .fin1InputFieldBackground
│           └── Corner Radius: 12
│
├── Investment Strategy Picker
│   ├── Label: "Investment Strategy" (.headline, .fin1FontColor)
│   └── Picker (SegmentedPickerStyle)
│       └── ForEach(PotSelectionStrategy.allCases)
│           └── VStack
│               ├── Strategy Display Name (.subheadline, .medium)
│               └── Strategy Description (.caption, .fin1FontColor.opacity(0.7))
│
└── Number of Pots Slider (conditional, only if .multiplePots)
    ├── Label: "Number of Pots" (.headline, .fin1FontColor)
    ├── HStack
    │   ├── Min Label: "1" (.subheadline, .fin1FontColor.opacity(0.7))
    │   ├── Slider
    │   │   ├── Range: 1...10
    │   │   ├── Step: 1
    │   │   └── Accent Color: .fin1AccentGreen
    │   └── Max Label: "10" (.subheadline, .fin1FontColor.opacity(0.7))
    └── Selected Value Display
        ├── Text: "{numberOfPots} pot(s)"
        ├── Font: .subheadline
        ├── Weight: .medium
        └── Color: .fin1AccentGreen
```

**Container Styling**:
- Background: `Color.fin1SectionBackground`
- Padding: Standard padding
- Corner Radius: 16

### 3. Pot Allocation Preview Section (`potSelectionView`)

**Structure**:
```
VStack (spacing: 12)
├── Title: "Pot Allocation Preview"
│   ├── Font: .headline
│   ├── Color: .fin1FontColor
│   └── Alignment: .leading
│
└── Conditional Content:
    ├── IF .singlePot:
    │   └── singlePotPreview
    │       └── HStack
    │           ├── Left Column (VStack)
    │           │   ├── "Next Available Pot" (.subheadline, .fin1FontColor)
    │           │   └── "Pot #1" (.caption, .fin1FontColor.opacity(0.7))
    │           ├── Spacer()
    │           └── Right Column (VStack)
    │               ├── Amount: "€{amountPerPot}" (.subheadline, .semibold, .fin1AccentGreen)
    │               └── Percentage: "100% of investment" (.caption, .fin1FontColor.opacity(0.7))
    │
    └── IF .multiplePots:
        └── multiplePotsPreview
            └── VStack (spacing: 8)
                ├── ForEach(1...min(numberOfPots, 3))
                │   └── Pot Card (HStack)
                │       ├── Left Column
                │       │   ├── "Pot #{potNumber}" (.subheadline, .fin1FontColor)
                │       │   └── "Next available" or "Future pot" (.caption, .fin1FontColor.opacity(0.7))
                │       ├── Spacer()
                │       └── Right Column
                │           ├── Amount: "€{amountPerPot}" (.subheadline, .semibold, .fin1AccentGreen)
                │           └── "€{amountPerPot} per pot" (.caption, .fin1FontColor.opacity(0.7))
                └── IF numberOfPots > 3:
                    └── Text: "+ {numberOfPots - 3} more pot(s)"
                        ├── Font: .caption
                        └── Color: .fin1FontColor.opacity(0.7)
```

**Pot Card Styling**:
- Background: `Color.fin1ScrollSectionBackground`
- Padding: Standard padding
- Corner Radius: 12
- Spacing: 4 (internal VStack spacing)

**Container Styling**:
- Background: `Color.fin1SectionBackground`
- Padding: Standard padding
- Corner Radius: 16

### 4. Investment Summary Section (`investmentSummaryView`)

**Structure**:
```
VStack (spacing: 12)
├── Title: "Investment Summary"
│   ├── Font: .headline
│   ├── Color: .fin1FontColor
│   └── Alignment: .leading
│
└── VStack (spacing: 8)
    ├── Row 1: Amount per Pot
    │   └── HStack
    │       ├── Label: "Amount per Pot:"
    │       ├── Spacer()
    │       └── Value: "€{amountPerPot}" (.medium weight)
    │
    ├── Row 2: Number of Pots
    │   └── HStack
    │       ├── Label: "Number of Pots:"
    │       ├── Spacer()
    │       └── Value: "{numberOfPots}" (.medium weight)
    │
    ├── Divider()
    │
    └── Row 3: Total Investment (highlighted)
        └── HStack
            ├── Label: "Total Investment:"
            │   ├── Font: .subheadline
            │   └── Weight: .semibold
            ├── Spacer()
            └── Value: "€{totalInvestmentAmount}"
                ├── Font: .subheadline
                ├── Weight: .bold
                └── Color: .fin1AccentGreen
```

**Container Styling**:
- Background: `Color.fin1SectionBackground`
- Padding: Standard padding
- Corner Radius: 16
- Font: `.subheadline` (for all rows)
- Text Color: `.fin1FontColor`

### 5. Action Buttons Section (`actionButtonsView`)

**Structure**:
```
VStack (spacing: 12)
├── Primary Button: "Create Investment"
│   └── Button Content:
│       ├── IF isLoading:
│       │   └── ProgressView (white, scale: 0.8)
│       └── ELSE:
│           └── Text: "Create Investment" (.semibold)
│       ├── Frame: maxWidth: .infinity
│       ├── Padding: Standard padding
│       ├── Background:
│       │   ├── IF canProceed: .fin1AccentGreen
│       │   └── ELSE: .fin1FontColor.opacity(0.3)
│       ├── Foreground: .white
│       ├── Corner Radius: 12
│       └── Disabled: !canProceed || isLoading
│
└── Secondary Button: "Cancel"
    ├── Action: dismiss()
    └── Foreground: .fin1FontColor.opacity(0.7)
```

### Navigation Bar

**Configuration**:
```
NavigationTitle: "Investment"
Display Mode: .inline
Toolbar:
└── Leading Item:
    └── Button("Cancel")
        └── Action: dismiss()
```

---

## Styling System

### Color System

All colors are defined in `Color+AppColors.swift` and referenced from Assets.xcassets:

| Color Name | Asset Name | HEX Value | Usage |
|------------|------------|-----------|-------|
| `fin1ScreenBackground` | `ScreenBackground` | `#193365` | Main screen background |
| `fin1SectionBackground` | `SectionBackground` | `#0d1933` | Section/card backgrounds |
| `fin1ScrollSectionBackground` | `ScrollSectionBackground` | Derived | Sub-section backgrounds |
| `fin1FontColor` | `FontColor` | `#f5f5f5` | Primary text color |
| `fin1AccentGreen` | `AccentGreen` | `#278e4c` | Success states, positive values |
| `fin1AccentLightBlue` | `AccentLightBlue` | `#007aff` | Primary accent, avatar background |
| `fin1InputFieldBackground` | `InputFieldBackground` | `#8ea0ad` | Text field backgrounds |
| `fin1InputText` | `InputText` | `#f5f5f5` | Input text color |

### Typography System

**Font Hierarchy**:
- **Title**: `.title` (via `ResponsiveDesign.titleFont()`)
- **Headline**: `.headline` (via `ResponsiveDesign.headlineFont()`)
- **Subheadline**: `.subheadline` (standard)
- **Body**: `.subheadline` (via `ResponsiveDesign.bodyFont()`)
- **Caption**: `.caption` (via `ResponsiveDesign.captionFont()`)

**Font Weights**:
- **Bold**: `.bold` (for emphasis)
- **Semibold**: `.semibold` (for headers)
- **Medium**: `.medium` (for labels)
- **Regular**: Default

### Responsive Design System

**Spacing**:
```swift
ResponsiveDesign.spacing(16)  // Base spacing value
ResponsiveDesign.spacing(12)   // Smaller spacing
ResponsiveDesign.spacing(8)    // Compact spacing
```

**Device Adaptation**:
- **Compact Devices**: 80% of base value
- **Standard Devices**: 100% of base value
- **Large Devices**: 120% of base value

**Usage Pattern**:
```swift
VStack(spacing: ResponsiveDesign.spacing(16))  // Main sections
VStack(spacing: ResponsiveDesign.spacing(12))  // Sub-sections
VStack(spacing: ResponsiveDesign.spacing(8))   // Compact spacing
```

### Corner Radius Standards

- **Large Sections**: 16 points
- **Input Fields**: 12 points
- **Pot Cards**: 12 points

### Padding Standards

- **Section Padding**: Standard padding (via `.padding()`)
- **Input Field Padding**: Standard padding inside fields
- **Card Padding**: Standard padding

---

## Business Logic

### State Properties

```swift
@State private var investmentAmount: String = ""
@State private var selectedPotSelection: PotSelectionStrategy = .singlePot
@State private var numberOfPots: Int = 1
@State private var showInvestmentError: Bool = false
@State private var investmentErrorMessage: String = ""
@State private var showSuccess: Bool = false
@State private var isLoading: Bool = false
```

### Computed Properties

#### `amountPerPot: Double`
**Formula**: `totalInvestmentAmount / numberOfPots`

**Logic**:
```swift
private var amountPerPot: Double {
    let totalAmount = Double(investmentAmount) ?? 0
    return totalAmount > 0 ? totalAmount / Double(numberOfPots) : 0
}
```

#### `totalInvestmentAmount: Double`
**Formula**: Direct conversion from `investmentAmount` string

**Logic**:
```swift
private var totalInvestmentAmount: Double {
    Double(investmentAmount) ?? 0
}
```

#### `canProceed: Bool`
**Validation Rules**:
1. `investmentAmount` is not empty
2. Converted amount > 0
3. `numberOfPots >= 1`
4. `numberOfPots <= 10`

**Logic**:
```swift
private var canProceed: Bool {
    !investmentAmount.isEmpty &&
    Double(investmentAmount) ?? 0 > 0 &&
    numberOfPots >= 1 &&
    numberOfPots <= 10
}
```

### Investment Strategy Logic

#### Single Pot Strategy
- **Display Name**: "Single Pot"
- **Description**: "Invest in the next available pot"
- **Behavior**:
  - `numberOfPots` is fixed at 1
  - Shows single pot preview
  - Entire investment goes to next available pot

#### Multiple Pots Strategy
- **Display Name**: "Multiple Pots"
- **Description**: "Invest across multiple future pots"
- **Behavior**:
  - `numberOfPots` is selectable (1-10 via slider)
  - Shows up to 3 pots in preview (with "+ X more" indicator)
  - Investment amount is divided equally across all pots

### Pot Allocation Preview Logic

#### Single Pot Preview
- Shows one pot card
- Displays "Next Available Pot" and "Pot #1"
- Shows full investment amount as "€{amountPerPot}"
- Shows "100% of investment"

#### Multiple Pots Preview
- Shows up to 3 pot cards
- First pot labeled "Next available", others labeled "Future pot"
- Each pot shows equal share: "€{amountPerPot} per pot"
- If more than 3 pots: shows "+ {count} more pot(s)" indicator

### Investment Summary Logic

**Calculations**:
1. **Amount per Pot**: `amountPerPot` (already calculated)
2. **Number of Pots**: Current `numberOfPots` value
3. **Total Investment**: `totalInvestmentAmount` (sum of all pots)

**Display Format**:
- Currency values: `String(format: "%.2f", value)`
- Pot count: Direct integer display

---

## Data Models

### Input Models

#### `MockTrader`
```swift
struct MockTrader: Identifiable {
    let id: UUID
    let name: String
    let username: String
    let specialization: String
    // ... other properties
}
```

**Required Properties for Investment Sheet**:
- `id: UUID` - Trader identifier
- `username: String` - Display name (used for avatar initial)
- `specialization: String` - Displayed in header

### Enums

#### `PotSelectionStrategy`
```swift
enum PotSelectionStrategy: String, CaseIterable, Codable {
    case singlePot = "singlePot"
    case multiplePots = "multiplePots"

    var displayName: String {
        switch self {
        case .singlePot: return "Single Pot"
        case .multiplePots: return "Multiple Pots"
        }
    }

    var description: String {
        switch self {
        case .singlePot: return "Invest in the next available pot"
        case .multiplePots: return "Invest across multiple future pots"
        }
    }
}
```

### Service Integration

#### `InvestmentService.createInvestment()`
**Signature**:
```swift
func createInvestment(
    investor: User,
    trader: MockTrader,
    amountPerPot: Double,
    numberOfPots: Int,
    specialization: String,
    potSelection: PotSelectionStrategy
) async throws
```

**Parameters**:
- `investor: User` - Current logged-in user
- `trader: MockTrader` - Selected trader to invest in
- `amountPerPot: Double` - Amount allocated per pot
- `numberOfPots: Int` - Number of pots (1-10)
- `specialization: String` - Trader's specialization
- `potSelection: PotSelectionStrategy` - Selected strategy

**Returns**: `async throws` (void on success)

---

## State Management

### Environment Dependencies

```swift
@Environment(\.dismiss) private var dismiss
@Environment(\.appServices) private var appServices
```

### User Access

```swift
private var currentUser: User? {
    appServices.userService.currentUser
}
```

### Initialization

```swift
init(trader: MockTrader, onInvestmentSuccess: (() -> Void)? = nil) {
    self.trader = trader
    self.onInvestmentSuccess = onInvestmentSuccess
}
```

**Parameters**:
- `trader: MockTrader` - Required, trader to invest in
- `onInvestmentSuccess: (() -> Void)?` - Optional callback after successful investment

---

## Validation Rules

### Pre-Investment Validation (`validateUserCanInvest()`)

**Called**: On view appearance (`.onAppear`)

**Rules**:
1. **User Must Be Logged In**:
   - `currentUser != nil`
   - Error: "Please log in to make investments"

2. **User Cannot Be Trader**:
   - `currentUser.role != .trader`
   - Error: "Traders cannot invest in other traders"

### Investment Creation Validation

**Called**: When "Create Investment" button is tapped

**Rules**:
1. **Form Validation** (`canProceed`):
   - Investment amount is not empty
   - Investment amount > 0
   - Number of pots >= 1
   - Number of pots <= 10

2. **User Validation**:
   - User must be logged in
   - User role must not be `.trader`

3. **Service-Level Validation** (handled by `InvestmentService`):
   - Minimum investment amount (100€ total)
   - Trader investment restriction
   - Other business rules

---

## Error Handling

### Error States

#### 1. Investment Error Alert
```swift
.alert("Investment Error", isPresented: $showInvestmentError) {
    Button("OK") { }
} message: {
    Text(investmentErrorMessage)
}
```

**Triggers**:
- Validation failures
- Service errors
- Network errors
- Permission errors

#### 2. Success Alert
```swift
.alert("Investment Created", isPresented: $showSuccess) {
    Button("OK") { }
} message: {
    Text("Your investment has been successfully created! Returning to dashboard...")
}
```

**Behavior**:
- Shows for 1.5 seconds
- Automatically dismisses sheet
- Calls `onInvestmentSuccess?()` callback

### Error Message Display

**Method**:
```swift
private func showInvestmentError(_ message: String) {
    investmentErrorMessage = message
    showInvestmentError = true
}
```

### Error Tracking

**Telemetry Integration**:
```swift
let context = ErrorContext(
    screen: "InvestmentSheet",
    action: "createInvestment",
    userId: currentUser.id,
    userRole: currentUser.role.displayName,
    additionalData: [
        "trader_id": trader.id.uuidString,
        "trader_name": trader.name,
        "investment_amount": amountPerPot,
        "number_of_pots": numberOfPots,
        "specialization": trader.specialization,
        "pot_selection": selectedPotSelection.rawValue
    ]
)
TelemetryService.shared.trackAppError(error, context: context)
```

---

## User Flow

### Complete Investment Flow

```
1. User Taps Trader in Dashboard
   ↓
2. InvestmentSheet Presented
   ↓
3. View Appears
   ├── validateUserCanInvest() called
   ├── Header shows trader info
   └── Form is empty (initial state)
   ↓
4. User Enters Investment Amount
   ├── TextField updates investmentAmount
   ├── Pot Allocation Preview updates
   └── Investment Summary updates
   ↓
5. User Selects Investment Strategy
   ├── IF .singlePot: numberOfPots = 1, slider hidden
   └── IF .multiplePots: slider appears, user adjusts
   ↓
6. User Reviews Preview & Summary
   ├── Pot Allocation Preview shows distribution
   └── Investment Summary shows totals
   ↓
7. User Taps "Create Investment"
   ├── canProceed validation
   ├── isLoading = true (button disabled, shows spinner)
   └── createInvestment() called
   ↓
8. Investment Creation
   ├── Service validates investment
   ├── Service creates investment record
   └── Service creates pot reservations
   ↓
9. Success Path
   ├── isLoading = false
   ├── showSuccess = true (alert appears)
   ├── After 1.5s: sheet dismisses
   └── onInvestmentSuccess?() callback
   ↓
10. Error Path
    ├── isLoading = false
    ├── showInvestmentError = true (alert appears)
    └── User can retry or cancel
```

### Validation Flow

```
validateUserCanInvest()
├── IF currentUser == nil
│   └── showInvestmentError("Please log in...")
│
└── IF currentUser.role == .trader
    └── showInvestmentError("Traders cannot invest...")
```

### Form Validation Flow

```
User Input Changes
├── Investment Amount Changed
│   ├── amountPerPot recalculated
│   ├── totalInvestmentAmount recalculated
│   ├── Pot Allocation Preview updated
│   └── Investment Summary updated
│
├── Strategy Changed
│   ├── IF .singlePot: numberOfPots = 1, slider hidden
│   └── IF .multiplePots: slider shown
│
└── Number of Pots Changed (slider)
    ├── amountPerPot recalculated
    ├── Pot Allocation Preview updated
    └── Investment Summary updated
```

---

## Implementation Checklist

### Step 1: Create Data Models
- [ ] Define `PotSelectionStrategy` enum with cases and display properties
- [ ] Ensure `MockTrader` model has required properties (id, username, specialization)
- [ ] Verify `User` model integration for current user access

### Step 2: Create View Structure
- [ ] Create `InvestmentSheet` struct conforming to `View`
- [ ] Set up `NavigationView` with title and toolbar
- [ ] Create `ZStack` with background color
- [ ] Add `ScrollView` container

### Step 3: Implement Header Section
- [ ] Create `investmentHeaderView` computed property
- [ ] Add circular avatar with trader initial
- [ ] Add trader username display
- [ ] Add trader specialization display
- [ ] Apply section styling (background, padding, corner radius)

### Step 4: Implement Investment Form
- [ ] Create `investmentFormView` computed property
- [ ] Add "Investment Amount" label and TextField
- [ ] Configure TextField (keyboard type, font, colors)
- [ ] Add "Investment Strategy" Picker with segmented style
- [ ] Populate Picker with `PotSelectionStrategy.allCases`
- [ ] Add conditional "Number of Pots" slider (for multiple pots)
- [ ] Configure slider (range 1-10, accent color)
- [ ] Add selected pot count display
- [ ] Apply section styling

### Step 5: Implement Pot Allocation Preview
- [ ] Create `potSelectionView` computed property
- [ ] Add section title
- [ ] Create `singlePotPreview` computed property
- [ ] Create `multiplePotsPreview` computed property
- [ ] Implement conditional rendering based on strategy
- [ ] Add pot cards with proper layout
- [ ] Implement "+ X more" indicator for >3 pots
- [ ] Apply card styling (background, padding, corner radius)

### Step 6: Implement Investment Summary
- [ ] Create `investmentSummaryView` computed property
- [ ] Add section title
- [ ] Add "Amount per Pot" row
- [ ] Add "Number of Pots" row
- [ ] Add `Divider`
- [ ] Add "Total Investment" row (highlighted)
- [ ] Format currency values to 2 decimal places
- [ ] Apply section styling

### Step 7: Implement Action Buttons
- [ ] Create `actionButtonsView` computed property
- [ ] Add "Create Investment" button
- [ ] Implement loading state with ProgressView
- [ ] Configure button styling (enabled/disabled states)
- [ ] Add "Cancel" button with dismiss action
- [ ] Apply proper spacing

### Step 8: Implement State Management
- [ ] Add `@State` properties (investmentAmount, selectedPotSelection, etc.)
- [ ] Add `@Environment` properties (dismiss, appServices)
- [ ] Create computed properties (amountPerPot, totalInvestmentAmount, canProceed)
- [ ] Add currentUser computed property

### Step 9: Implement Validation
- [ ] Create `validateUserCanInvest()` method
- [ ] Add user login validation
- [ ] Add trader role restriction validation
- [ ] Call validation in `.onAppear`
- [ ] Create `showInvestmentError()` helper method

### Step 10: Implement Investment Creation
- [ ] Create `createInvestment()` method
- [ ] Add guard clauses (canProceed, currentUser)
- [ ] Set isLoading state
- [ ] Create async Task for service call
- [ ] Call `investmentService.createInvestment()`
- [ ] Handle success case (show success alert, dismiss after delay)
- [ ] Handle error cases (AppError and generic errors)
- [ ] Add error tracking with context

### Step 11: Implement Alerts
- [ ] Add error alert modifier
- [ ] Add success alert modifier
- [ ] Configure alert messages and buttons

### Step 12: Apply Responsive Design
- [ ] Replace all fixed spacing with `ResponsiveDesign.spacing()`
- [ ] Replace all fixed fonts with responsive font system (if applicable)
- [ ] Verify layout on different device sizes

### Step 13: Apply Color System
- [ ] Replace hardcoded colors with `fin1` color system
- [ ] Verify all colors from Assets.xcassets
- [ ] Apply opacity modifiers where needed

### Step 14: Testing
- [ ] Test single pot investment flow
- [ ] Test multiple pots investment flow
- [ ] Test validation (empty amount, invalid amounts)
- [ ] Test trader role restriction
- [ ] Test error handling (network errors, service errors)
- [ ] Test success flow and automatic dismissal
- [ ] Test responsive design on different devices
- [ ] Test accessibility (VoiceOver, Dynamic Type)

---

## Key Implementation Notes

### Currency Formatting
Always format currency values with 2 decimal places:
```swift
String(format: "%.2f", amount)
```

### Pot Count Display
Use proper pluralization:
```swift
"\(numberOfPots) pot\(numberOfPots == 1 ? "" : "s")"
```

### Conditional Rendering
Use `if` statements for conditional sections:
```swift
if selectedPotSelection == .multiplePots {
    // Show slider
}
```

### Async/Await Pattern
Use `Task` for async operations:
```swift
Task {
    do {
        try await service.call()
        await MainActor.run { /* UI updates */ }
    } catch { /* Error handling */ }
}
```

### Loading State Management
Always reset `isLoading` on both success and error paths.

### Alert Management
Use separate boolean state variables for different alerts:
- `showInvestmentError` for error alerts
- `showSuccess` for success alerts

---

## Dependencies

### Required Services
- `AppServices` (via `@Environment(\.appServices)`)
  - `investmentService: InvestmentServiceProtocol`
  - `userService: UserServiceProtocol`

### Required Models
- `MockTrader` - Trader model
- `User` - User model (from Authentication)
- `PotSelectionStrategy` - Investment strategy enum
- `Investment` - Investment model (created by service)

### Required Extensions
- `Color+AppColors` - Color system
- `ResponsiveDesign` - Responsive spacing and sizing

---

## Summary

The Investment Sheet is a comprehensive SwiftUI view that provides:

1. **Clear Visual Hierarchy**: Header → Form → Preview → Summary → Actions
2. **Responsive Design**: Adapts to different device sizes
3. **Real-time Updates**: Form changes immediately reflect in preview and summary
4. **Robust Validation**: Multiple layers of validation (client and service)
5. **Error Handling**: Comprehensive error handling with user-friendly messages
6. **Success Feedback**: Clear success indication with automatic dismissal

This guide provides all necessary information to recreate this feature in a similar application, maintaining the same architecture, styling, and user experience patterns.



