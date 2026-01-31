# Risk Class Implementation Summary

## Overview
This document describes the complete implementation of the "Risikoklasse" (Risk Class) feature for the SignUp flow in the FIN1 app. The feature provides automatic risk class calculation based on user financial and investment experience, with manual override capabilities and conditional navigation flows.

## Key Features Implemented

### 1. Risk Class Calculation System
- **Automatic Calculation**: Based on user experience and risk tolerance from steps 12, 13, and 14
- **Risk Classes**: 1-7 scale following German/EU Synthetic Risk and Reward Indicator (SRI)
- **Special Handling**: Risk class 7 can only be selected manually by the user
- **Reactive Calculation**: Uses computed properties to automatically recalculate when user input changes
- **Safety Mechanism**: Automatically caps users at Risk Class 2 maximum if conservative investment patterns are detected

### 2. Risk Class Data Model
- **RiskClass Enum**: Defines all 7 risk classes with descriptions, examples, and colors
- **SignUpData Integration**: Added `userSelectedRiskClass` and `calculatedRiskClass` properties
- **Final Risk Class Logic**: Combines calculated and user-selected values with computed property

### 3. Conditional Navigation Flow
- **Risk Classes 1-6**: Users are rejected with "Back to Startpage" button
- **Risk Class 7**: Users can proceed to Summary page → Welcome page → Startpage
- **Custom Button Logic**: Navigation buttons are hidden when custom buttons are present

## Risk Class Definitions

### Risk Class 1 (Very Low Risk)
- **Description**: Focus on value preservation and security, low price fluctuations, capital loss unlikely
- **Examples**: Money market funds, savings accounts, fixed deposits, savings bonds
- **Color**: Green
- **Score Range**: 0-3 points

### Risk Class 2 (Low Risk)
- **Description**: Mostly investments in longer-term government bonds from industrialized countries
- **Examples**: Government bond funds with high credit ratings
- **Color**: Green
- **Score Range**: 4-7 points

### Risk Class 3 (Medium Risk)
- **Description**: Security still important, but risk increases slightly with possible partial capital loss
- **Examples**: Bonds with good credit ratings, mixed funds
- **Color**: Orange
- **Score Range**: 8-12 points

### Risk Class 4 (Medium-High Risk)
- **Description**: Balanced mix of security and return, more risk tolerance required
- **Examples**: Globally diversified stock funds, ETFs
- **Color**: Orange
- **Score Range**: 13-18 points

### Risk Class 5 (High Risk)
- **Description**: Growth-oriented investments with significantly higher risk and return opportunities
- **Examples**: Country stock funds, currency bonds with medium credit ratings, OTC stocks
- **Color**: Red
- **Score Range**: 19-25 points

### Risk Class 6 (Very High Risk)
- **Description**: Very speculative investments with large value fluctuations and possible total loss
- **Examples**: Warrants, dividend funds, CFDs, junk bonds, futures
- **Color**: Red
- **Score Range**: 26-35 points

### Risk Class 7 (Extremely Speculative)
- **Description**: Very high risk, total capital loss possible, only for experienced investors
- **Examples**: Hedge funds, sector funds, emerging market funds, cryptocurrencies, leveraged products
- **Color**: Red
- **Requires Manual Selection**: Yes
- **Special Warning**: High-risk confirmation dialog required

## Calculation Algorithm

The risk class is calculated based on a comprehensive scoring system from steps 12, 13, and 14, with an additional safety mechanism to protect users:

### Safety Mechanism
**Purpose**: Automatically caps users at Risk Class 2 maximum if conservative investment patterns are detected, regardless of scoring.

**Conservative Patterns (ANY of these trigger the safety cap)**:
- **Derivatives Transactions**: None, 1-10, or 10-50
- **Investment Amount**: 0€-1000€ or 1000€-10000€
- **Holding Period**: Months to years
- **Desired Return**: At least 10%

**Logic**: If ANY conservative pattern is detected AND the calculated risk class is > 2, the user is capped at Risk Class 2.

### Scoring System

### Step 12: Financial Information (0-12 points)
- **Income Range** (0-5 points):
  - Under 25.000: 0 points
  - 25.000 - 50.000: 1 point
  - 50.000 - 100.000: 2 points
  - 100.000 - 200.000: 3 points
  - 200.000 - 500.000: 4 points
  - More than 500.000: 5 points

- **Cash and Liquid Assets** (0-5 points):
  - Less than 10.000: 0 points
  - 10.000 - 50.000: 1 point
  - 50.000 - 200.000: 2 points
  - 200.000 - 500.000: 3 points
  - 500.000 - 1.000.000: 4 points
  - More than 1.000.000: 5 points

- **Income Sources** (0-4 points):
  - Assets: 2 points
  - Inheritance: 1 point
  - Settlement: 1 point
  - Salary/Pension/Savings: 0 points

### Step 13: Investment Experience (0-25 points)
- **Transaction Counts**:
  - Stocks (0-3 points): None: 0, 1-10: 1, 10-50: 2, 50+: 3
  - ETFs (0-3 points): None: 0, 1-10: 1, 10-20: 2, 20+: 3
  - Derivatives (0-8 points): None: 0, 1-10: 3, 10-50: 6, 50+: 8

- **Investment Amounts** (Maximum of all types, 0-6 points):
  - Stocks/ETFs: 100€-10k: 0, 10k-100k: 1, 100k-1M: 2, 1M+: 4
  - Derivatives: 0€-1k: 0, 1k-10k: 2, 10k-100k: 4, 100k+: 6

- **Derivatives Holding Period** (1-4 points):
  - Months to years: 1 point
  - Days to weeks: 2 points
  - Minutes to hours: 4 points

- **Other Assets** (0-3 points):
  - Real estate: 2 points
  - Gold, silver: 1 point
  - None: 0 points

### Step 14: Desired Return (1-5 points)
- At least 10%: 1 point
- At least 50%: 3 points
- At least 100%: 5 points

### Score Mapping
- 0-3 points: Risk Class 1
- 4-7 points: Risk Class 2
- 8-12 points: Risk Class 3
- 13-18 points: Risk Class 4
- 19-25 points: Risk Class 5
- 26-35 points: Risk Class 6
- 36+ points: Risk Class 6 (capped unless user manually selects 7)

### Safety Mechanism Application
After calculating the risk class based on score, the safety mechanism is applied:
- If ANY conservative pattern is detected AND calculated risk class > 2
- User is automatically capped at **Risk Class 2 maximum**
- This overrides the normal score mapping to protect users

## User Interface Components

### 1. RiskClassSelectionView
- **Purpose**: Allows manual selection of any risk class
- **Features**:
  - Shows calculated risk class prominently
  - Manual selection with radio buttons
  - Special warning for risk class 7
  - Info button to view detailed risk class information
  - "Use automatic calculation" option
  - Callback for Risk Class 7 confirmation

### 2. RiskClassInfoView
- **Purpose**: Comprehensive overview of all risk classes
- **Features**:
  - Color-coded risk levels (green, orange, red)
  - Detailed descriptions and examples
  - Based on EU SRI standard

### 3. RiskClassSummaryRow
- **Purpose**: Displays in summary step
- **Features**:
  - Interactive info button (ⓘ)
  - Shows final risk class value
  - Pencil icon for editing/manual selection

### 4. RiskClassificationNoteStep
- **Purpose**: Shows risk classification result and next steps
- **Features**:
  - Conditional content based on risk class
  - Risk Class 1-6: Rejection message with "Back to Startpage" (dismisses signup flow)
  - Risk Class 7: Success message with "Complete Registration"
  - Risk class indicator with visual dots
  - Option to change risk class for classes 4-6

### 5. WelcomePage
- **Purpose**: Success page after registration completion
- **Features**:
  - "Herzlich willkommen und viel Erfolg!" message
  - "Zur Startseite" button to return to landing page

## Navigation Flow

### Risk Classes 1-6 (Rejected Users)
```
Risk Classification Note → "Back to Startpage" → Startpage (landing page with "Get Started" and "Sign In")
```

### Risk Class 7 (Approved Users)
```
Risk Classification Note → Risk Class Selection → Summary Page → Welcome Page → Startpage
```

### Detailed Flow for Risk Class 7:
1. **Risk Classification Note**: Shows calculated risk class (e.g., 6)
2. **User clicks "Sie können Ihre Risikoklasse hier ändern"**
3. **RiskClassSelectionView opens**: User selects Risk Class 7
4. **High-risk warning dialog**: User confirms understanding
5. **User taps "Bestätigen"**: Automatically navigates to Summary page
6. **Summary Page**: Shows all data with Risk Class 7 and "Complete Registration" button
7. **User taps "Complete Registration"**: Opens Welcome page
8. **Welcome Page**: Shows success message and "Zur Startseite" button
9. **User taps "Zur Startseite"**: Returns to landing page

### Detailed Flow for Risk Classes 1-6:
1. **Risk Classification Note**: Shows calculated risk class (e.g., 6)
2. **User sees rejection message**: "Deshalb dürfen Sie auf unserer Platform nicht handeln"
3. **User taps "Back to Startpage"**: Dismisses entire signup flow
4. **User returns to Startpage**: Landing page with "Get Started" and "Sign In" buttons

## Technical Implementation

### Key Files Modified/Created:

#### 1. Models/User.swift
- Added `RiskClass` enum with 7 cases
- Added properties: `displayName`, `shortName`, `description`, `examples`, `color`, `isHighRisk`, `requiresManualSelection`
- Updated `InvestmentAmount` and `DerivativesInvestmentAmount` enums with `riskScore` properties

#### 2. Views/Authentication/SignUp/Components/Models/SignUpData.swift
- Added `@Published var userSelectedRiskClass: RiskClass?`
- Added computed property `var calculatedRiskClass: RiskClass`
- Added computed property `var finalRiskClass: RiskClass`
- Implemented comprehensive `calculateRiskClass()` function
- Added safety mechanism `hasConservativeInvestmentPattern()` function
- Fixed enum case names for `CashAndLiquidAssets`

#### 3. Views/Authentication/SignUp/Components/Steps/RiskClassificationNoteStep.swift
- Conditional UI based on risk class
- Custom buttons for different risk classes
- Integration with coordinator for navigation

#### 4. Views/Authentication/SignUp/Components/Steps/SummaryStep.swift
- Added Risk Assessment section with `RiskClassSummaryRow`
- Conditional "Complete Registration" button for Risk Class 7
- Integration with coordinator

#### 5. Views/Authentication/SignUp/Components/RiskClass/RiskClassSelectionView.swift
- Manual risk class selection interface
- High-risk warning for Risk Class 7
- Callback mechanism for navigation

#### 6. Views/Authentication/SignUp/Components/RiskClass/RiskClassSummaryRow.swift
- Interactive risk class display
- Info and edit functionality

#### 7. Views/Authentication/SignUp/Components/RiskClass/RiskClassInfoView.swift
- Comprehensive risk class information

#### 8. Views/Authentication/SignUp/Components/Navigation/WelcomePage.swift
- Success page after registration

#### 9. Views/Authentication/SignUp/Components/Steps/StepConfiguration.swift
- Added `.riskClassificationNote = 19` step
- Updated step progression logic

#### 10. Views/Authentication/SignUp/SignUpCoordinator.swift
- Added `weak var signUpData: SignUpData?` reference
- Added `resetToFirstStep()` method

#### 11. Views/Authentication/SignUp/SignUpView.swift
- Updated to pass coordinator to steps
- Set coordinator's signUpData reference

#### 12. Views/Authentication/SignUp/Components/Navigation/SignUpNavigationButtons.swift
- Hide navigation buttons for custom button scenarios
- Conditional logic for Risk Class 7 Summary page

## Testing Components

### 1. RiskClass/RiskClassTest.swift
- Comprehensive test interface for risk class calculation
- Test scenarios for different risk profiles
- Calculation breakdown display

### 2. RiskClass/SimpleRiskTest.swift
- Simple test interface for reactive calculation
- Real-time risk class updates based on user input

### 3. RiskClass/RiskClassCalculationOverview.swift
- Complete overview of all calculation factors and point values
- Example calculations for different user profiles

## Key Technical Solutions

### 1. Safety Mechanism for User Protection
**Problem**: Users with conservative investment patterns could be assigned high risk classes
**Solution**: Implemented safety mechanism that caps users at Risk Class 2 if conservative patterns are detected

```swift
private func hasConservativeInvestmentPattern() -> Bool {
    // Check for conservative derivatives experience
    let hasConservativeDerivatives = derivativesTransactionsCount == .none || 
                                    derivativesTransactionsCount == .oneToTen || 
                                    derivativesTransactionsCount == .tenToFifty
    
    // Check for conservative investment amounts
    let hasConservativeAmounts = derivativesInvestmentAmount == .zeroToThousand || 
                                derivativesInvestmentAmount == .thousandToTenThousand
    
    // Check for conservative holding period
    let hasConservativeHolding = derivativesHoldingPeriod == .monthsToYears
    
    // Check for conservative desired return
    let hasConservativeReturn = desiredReturn == .atLeastTenPercent
    
    // If ANY of these conservative patterns are detected, cap at Risk Class 2
    return hasConservativeDerivatives || hasConservativeAmounts || hasConservativeHolding || hasConservativeReturn
}
```

### 2. Reactive Risk Class Calculation
**Problem**: Risk class was only calculated once with default values
**Solution**: Made `calculatedRiskClass` a computed property that recalculates automatically

```swift
// Before (stored property - only calculated once)
@Published var calculatedRiskClass: RiskClass?

// After (computed property - recalculates automatically)
var calculatedRiskClass: RiskClass {
    return calculateRiskClass()
}
```

### 2. Conditional Navigation Flow
**Problem**: Different risk classes need different navigation paths
**Solution**: Conditional UI and custom button logic

```swift
if signUpData.finalRiskClass == .riskClass7 {
    // Risk Class 7 - Complete Registration button
    Button("Complete Registration") {
        coordinator.goToStep(.summary)
    }
} else {
    // Risk Classes 1-6 - Back to Startpage button
    Button("Back to Startpage") {
        dismiss() // Dismiss entire signup flow and return to Startpage
    }
}
```

### 3. Automatic Navigation After Risk Class 7 Selection
**Problem**: User had to manually navigate after selecting Risk Class 7
**Solution**: Added callback mechanism to automatically navigate to Summary page

```swift
RiskClassSelectionView(
    selectedRiskClass: binding,
    calculatedRiskClass: calculatedRiskClass,
    onRiskClass7Confirmed: {
        coordinator.goToStep(.summary)
    }
)
```

### 4. Clean UI for Risk Class 7 Summary
**Problem**: Summary page showed too many buttons for Risk Class 7 users
**Solution**: Hide standard navigation buttons when custom buttons are present

```swift
if coordinator.currentStep == .riskClassificationNote || 
   (coordinator.currentStep == .summary && coordinator.signUpData?.finalRiskClass == .riskClass7) {
    EmptyView()
} else {
    // Show standard navigation buttons
}
```

### 5. Reactive Risk Classification Note Step
**Problem**: Risk Classification Note step might not update properly when user manually changes risk class
**Solution**: Added computed property to ensure view reactivity to finalRiskClass changes

```swift
// Ensure the view is reactive to finalRiskClass changes
private var currentRiskClass: RiskClass {
    return signUpData.finalRiskClass
}

// Use currentRiskClass instead of signUpData.finalRiskClass throughout the view
if currentRiskClass == .riskClass7 {
    // Show Complete Registration button
} else {
    // Show Back to Startpage button
}
```

### 6. Centralized Button Handling for Final Steps
**Problem**: Duplicate buttons and circular navigation patterns in final signup steps
**Solution**: Implemented centralized button handling strategy

#### Key Changes:
1. **Fixed "Back to Startpage" dismissal**: Added proper dismissal listener in SignUpView
2. **Eliminated duplicate "Complete Registration" buttons**: Centralized navigation button logic
3. **Proper welcome page navigation**: Added coordinator method for welcome page handling

### 7. Risk Class 7 Confirmation Workflow
**Problem**: Risk Class 7 users were going back to Summary page instead of having a dedicated confirmation
**Solution**: Created dedicated Risk Class 7 confirmation step

#### New Workflow:
1. **User manually selects Risk Class 7** → Shows warning and confirmation
2. **User confirms Risk Class 7** → Navigates to Risk Class 7 Confirmation step
3. **Risk Class 7 Confirmation step** → Shows high-risk warning and "Complete Registration" button
4. **Complete Registration** → Shows Welcome page

#### Key Changes:
- Added `RiskClass7ConfirmationStep` with high-risk warning
- Updated navigation flow to go to confirmation instead of Summary
- Centralized welcome page handling in confirmation step

```swift
// SignUpView: Handle dismissal and welcome page
.onChange(of: coordinator.shouldDismiss) { _, newValue in
    if newValue {
        dismiss()
        coordinator.shouldDismiss = false
    }
}
.fullScreenCover(isPresented: $coordinator.showWelcomePage) {
    WelcomePage()
}

// SignUpNavigationButtons: Hide custom buttons when needed
if coordinator.currentStep == .riskClassificationNote || 
   (coordinator.currentStep == .summary && signUpData.finalRiskClass == .riskClass7) {
    EmptyView()
} else {
    // Show standard navigation buttons
}

// SignUpNavigationButtons: Handle Risk Class 7 completion
Button(action: {
    if signUpData.finalRiskClass == .riskClass7 {
        coordinator.showWelcomePage()
    } else {
        onComplete()
    }
}) {
    Text("Complete Registration")
}
```

## Example Calculations

### Beginner (Conservative) - Risk Class 1
- Income: Middle (2 points)
- Assets: Less than 10k (0 points)
- No investment experience (0 points)
- Desired return: 10% (1 point)
- **Total: 3 points → Risk Class 1**

### Conservative Pattern Example - Risk Class 2 (Safety Cap)
- Income: Very high (5 points)
- Assets: More than 1M (5 points)
- Derivatives: 1-10 transactions (3 points)
- Derivatives: 1000€-10000€ (2 points)
- Derivatives holding: Months to years (1 point)
- Desired return: 10% (1 point)
- **Calculated Score: 17 points → Risk Class 4**
- **Safety Mechanism**: Conservative patterns detected (derivatives 1-10, amount 1000€-10000€, holding months to years, return 10%)
- **Final Result: Risk Class 2** (capped by safety mechanism)

### 50+ Derivatives Experience - Risk Class 3
- Income: Middle (2 points)
- Assets: Less than 10k (0 points)
- Derivatives: 50+ transactions (8 points)
- Derivatives holding: Months to years (1 point)
- Desired return: 10% (1 point)
- **Total: 12 points → Risk Class 3**

### High-Risk Profile - Risk Class 6
- Income: Very high (5 points)
- Assets: More than 1M (5 points)
- Derivatives: 50+ transactions (8 points)
- Derivatives: More than 100k (6 points)
- Derivatives holding: Minutes to hours (4 points)
- Desired return: 100% (5 points)
- Real estate: Yes (2 points)
- **Total: 35 points → Risk Class 6**

## Future Enhancements

### 1. Risk Class Validation
- Add validation rules for risk class selection
- Prevent users from selecting inappropriate risk classes

### 2. Risk Class History
- Track risk class changes over time
- Show risk class evolution

### 3. Risk Class Recommendations
- Provide personalized recommendations
- Suggest risk class adjustments based on market conditions

### 4. Risk Class Analytics
- Track user behavior by risk class
- Analyze risk class distribution

### 5. Enhanced Safety Mechanisms
- Add more sophisticated conservative pattern detection
- Implement machine learning for pattern recognition
- Add user education about risk class implications

## Conclusion

The Risk Class implementation provides a comprehensive, user-friendly system for determining user risk profiles. The automatic calculation ensures accuracy while the manual override option gives users control. The conditional navigation flow ensures appropriate user experience based on risk tolerance, with clear rejection for low-risk users and guided completion for high-risk users.

The **safety mechanism** is a critical feature that protects users from being assigned inappropriate high risk classes when they exhibit conservative investment patterns. This user protection feature ensures that even users with high income or other factors that might normally result in higher risk classes are appropriately capped at Risk Class 2 if they show conservative investment behavior.

The implementation is fully reactive, maintainable, and follows SwiftUI best practices. The modular design allows for easy testing and future enhancements.
