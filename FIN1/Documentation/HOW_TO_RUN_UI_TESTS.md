# How to Run UI Tests (See Tests in Simulator)

## Overview

UI tests launch the app in the simulator and interact with it visually. You can **watch the simulator** to see:
- Navigation between screens
- Forms being filled
- Buttons being tapped
- Data being entered
- Results appearing

---

## Quick Start: Run UI Tests

### Method 1: Xcode UI (Recommended - You Can Watch!)

1. **Open Xcode**:
   ```bash
   cd /Users/ra/app/FIN1
   open FIN1.xcodeproj
   ```

2. **Select UI Test Target**:
   - In the scheme selector (top toolbar), choose **FIN1UITests**
   - Or: Product → Scheme → FIN1UITests

3. **Open Simulator** (if not already open):
   - Xcode → Open Developer Tool → Simulator
   - Or press `⌘⇧2` and select a simulator

4. **Run UI Test**:
   - Press `⌘U` to run all tests
   - Or open Test Navigator (`⌘6`)
   - Find `FIN1UITests` → `InvestmentTradingUITests`
   - Click the ▶️ icon next to a test

5. **Watch the Simulator**:
   - The app will launch automatically
   - You'll see it navigate, tap buttons, fill forms
   - Each step happens with pauses so you can watch

---

## What You'll See in the Simulator

### Investment Creation Test
When you run `testCreateInvestment_StepByStep_ShowsInSimulator()`:

1. ✅ App launches
2. ✅ Navigates to "Investments" tab
3. ✅ Taps "+" button
4. ✅ Investment sheet slides up
5. ✅ Types "1000" in amount field
6. ✅ Adjusts investment count slider
7. ✅ Taps "Create Investment"
8. ✅ Sees confirmation/success

### Trading Test
When you run `testPlaceBuyOrder_StepByStep_ShowsInSimulator()`:

1. ✅ App launches
2. ✅ Navigates to Dashboard
3. ✅ Taps "Handeln" button
4. ✅ Securities search view appears
5. ✅ Types "DAX" in search field
6. ✅ Search results appear
7. ✅ Taps on a security
8. ✅ Buy order form appears
9. ✅ Enters quantity: "100"
10. ✅ Enters price: "10.50"
11. ✅ Taps "Place Order"
12. ✅ Order confirmation appears

---

## Command Line (For CI/CD)

### Run All UI Tests
```bash
cd /Users/ra/app/FIN1
xcodebuild test \
  -scheme FIN1 \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:FIN1UITests/InvestmentTradingUITests
```

### Run Specific UI Test
```bash
xcodebuild test \
  -scheme FIN1 \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:FIN1UITests/InvestmentTradingUITests/testCreateInvestment_StepByStep_ShowsInSimulator
```

### Run with Video Recording
```bash
# Record video of test execution
xcrun simctl boot "iPhone 15"
xcodebuild test \
  -scheme FIN1 \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:FIN1UITests/InvestmentTradingUITests \
  -resultBundlePath ./ui-test-results
```

---

## Test Execution Speed

UI tests run slower than unit tests because they:
- Launch the app
- Wait for UI elements to appear
- Interact with real UI components
- Include pauses so you can watch

### Adjusting Speed

To make tests faster (less visible):
```swift
// Remove or reduce sleep() calls
sleep(1) // Remove this to speed up
```

To make tests slower (more visible):
```swift
sleep(3) // Increase to 5 or 10 seconds
```

---

## Debugging UI Tests

### 1. Use Breakpoints
- Set breakpoints in test code
- Test will pause at breakpoint
- You can inspect app state

### 2. Take Screenshots
```swift
let screenshot = app.screenshot()
let attachment = XCTAttachment(screenshot: screenshot)
attachment.name = "Investment Form"
add(attachment)
```

### 3. Print Debug Info
```swift
print("Current screen: \(app.debugDescription)")
print("Available buttons: \(app.buttons.allElementsBoundByIndex)")
```

### 4. Use Accessibility Inspector
- Xcode → Open Developer Tool → Accessibility Inspector
- Helps find element identifiers

---

## Finding UI Elements

### Common Patterns

```swift
// By label
app.buttons["Handeln"]

// By accessibility identifier
app.buttons["handelnButton"]

// By type
app.textFields.firstMatch
app.cells.firstMatch

// By index
app.buttons.element(boundBy: 0)
```

### Debug: Print All Elements
```swift
print("All buttons: \(app.buttons.allElementsBoundByIndex)")
print("All text fields: \(app.textFields.allElementsBoundByIndex)")
print("All cells: \(app.cells.allElementsBoundByIndex)")
```

---

## Test Organization

### Run Investment Tests Only
```swift
testInvestmentUISuite()
```

### Run Trading Tests Only
```swift
testTradingUISuite()
```

### Run Everything
```swift
testCompleteUISuite()
```

---

## Troubleshooting

### App Doesn't Launch
- Check scheme is set to FIN1UITests
- Clean build: `⌘⇧K`
- Rebuild: `⌘B`

### Elements Not Found
- Check accessibility identifiers are set
- Use `app.debugDescription` to see available elements
- Increase wait times: `sleep(3)`

### Tests Too Fast/Slow
- Adjust `sleep()` durations
- Use `waitForElement()` helper for dynamic waits

### Simulator Issues
```bash
# Reset simulator
xcrun simctl erase "iPhone 15"

# List available simulators
xcrun simctl list devices available

# Boot simulator manually
xcrun simctl boot "iPhone 15"
```

---

## Best Practices

1. **Use Descriptive Test Names**: `testCreateInvestment_StepByStep_ShowsInSimulator()`
2. **Add Sleeps for Visibility**: `sleep(1)` so you can watch
3. **Print Progress**: `print("✅ Step completed")`
4. **Take Screenshots**: For debugging and documentation
5. **Wait for Elements**: Use `waitForElement()` instead of immediate checks

---

## Example: Watching a Complete Flow

1. **Start Test**: Click ▶️ next to `testCompleteTradeCycle_BuyThenSell_ShowsInSimulator`

2. **Watch Simulator**:
   - App launches
   - Navigates to Dashboard
   - Taps "Handeln"
   - Searches for security
   - Fills buy order form
   - Places buy order
   - Navigates to Depot
   - Finds trade
   - Places sell order
   - Sees trade completion

3. **Check Results**: Test passes ✅ and you saw everything happen!

---

## Quick Reference

| Action | Shortcut |
|--------|----------|
| Run Tests | `⌘U` |
| Test Navigator | `⌘6` |
| Simulator | `⌘⇧2` |
| Stop Tests | `⌘.` |
| Clean Build | `⌘⇧K` |

---

## Next Steps

1. Run `testCreateInvestment_StepByStep_ShowsInSimulator()` to see investment creation
2. Run `testPlaceBuyOrder_StepByStep_ShowsInSimulator()` to see trading
3. Run `testCompleteTradeCycle_BuyThenSell_ShowsInSimulator()` to see full flow
4. Customize tests by adjusting sleep times and adding more steps

**Enjoy watching your tests run! 🎬**

















