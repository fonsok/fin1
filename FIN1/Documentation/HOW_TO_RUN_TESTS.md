# How to Run Tests

## Quick Start

### Option 1: Run All Tests (Easiest)
Press `⌘U` in Xcode, or select **Product → Test** from the menu.

### Option 2: Run Specific Test File
1. Open Test Navigator (`⌘6`)
2. Find `InvestmentTradingSimulationTests`
3. Click the ▶️ icon next to the test class name

### Option 3: Run Individual Test
1. Open Test Navigator (`⌘6`)
2. Find the specific test method (e.g., `testCreateInvestment_WithVariousAmounts_CreatesSuccessfully`)
3. Click the ▶️ icon next to the test method

---

## Command Line Options

### Run All Tests
```bash
cd /Users/ra/app/FIN1
xcodebuild test -scheme FIN1 -destination 'platform=iOS Simulator,name=iPhone 15'
```

### Run Specific Test Class
```bash
xcodebuild test \
  -scheme FIN1 \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:FIN1Tests/InvestmentTradingSimulationTests
```

### Run Specific Test Method
```bash
xcodebuild test \
  -scheme FIN1 \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:FIN1Tests/InvestmentTradingSimulationTests/testCreateInvestment_WithVariousAmounts_CreatesSuccessfully
```

### Run Test Suite (Custom Method)
```bash
xcodebuild test \
  -scheme FIN1 \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:FIN1Tests/InvestmentTradingSimulationTests/testInvestmentSimulationSuite
```

### List Available Simulators
```bash
xcrun simctl list devices available
```

### Use Specific Simulator
Replace `iPhone 15` with any available simulator:
```bash
xcodebuild test \
  -scheme FIN1 \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

---

## Xcode Test Navigator

### Access Test Navigator
- **Keyboard**: `⌘6`
- **Menu**: View → Navigators → Show Test Navigator

### Test Icons
- ▶️ **Run**: Click to run the test
- ✅ **Passed**: Test passed successfully
- ❌ **Failed**: Test failed (click to see details)
- ⏸️ **Skipped**: Test was skipped
- ⏱️ **Running**: Test is currently executing

### Right-Click Options
Right-click on any test to:
- **Run**: Execute the test
- **Run with Coverage**: Run and show code coverage
- **Jump to Definition**: Go to test code
- **Show in Project Navigator**: Locate file

---

## Running Tests for Investment & Trading Simulations

### Run All Investment Tests
```bash
xcodebuild test \
  -scheme FIN1 \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:FIN1Tests/InvestmentTradingSimulationTests/testInvestmentSimulationSuite
```

### Run All Trading Tests
```bash
xcodebuild test \
  -scheme FIN1 \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:FIN1Tests/InvestmentTradingSimulationTests/testTradingSimulationSuite
```

### Run Complete Simulation Suite
```bash
xcodebuild test \
  -scheme FIN1 \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:FIN1Tests/InvestmentTradingSimulationTests/testCompleteSimulationSuite
```

---

## Test Plan (Recommended)

If you have a test plan configured:

```bash
xcodebuild test \
  -scheme FIN1 \
  -testPlan FIN1 \
  -destination 'platform=iOS Simulator,name=iPhone 15'
```

---

## Troubleshooting

### Tests Don't Appear in Navigator
1. Make sure `FIN1Tests` target is selected in the scheme
2. Clean build folder: `⌘⇧K` or Product → Clean Build Folder
3. Rebuild: `⌘B` or Product → Build

### Simulator Not Found
```bash
# List available simulators
xcrun simctl list devices available

# Boot a simulator
xcrun simctl boot "iPhone 15"
```

### Build Errors
1. Clean build: `⌘⇧K`
2. Delete derived data: `rm -rf ~/Library/Developer/Xcode/DerivedData`
3. Rebuild: `⌘B`

### Test Timeout
Increase timeout in test code:
```swift
await fulfillment(of: [expectation], timeout: 5.0) // Increase from 1.0 to 5.0
```

---

## Quick Reference

| Action | Keyboard Shortcut |
|--------|------------------|
| Run Tests | `⌘U` |
| Test Navigator | `⌘6` |
| Build | `⌘B` |
| Clean Build | `⌘⇧K` |
| Stop Tests | `⌘.` |

---

## Example: Running Your First Test

1. **Open Xcode**:
   ```bash
   cd /Users/ra/app/FIN1
   open FIN1.xcodeproj
   ```

2. **Open Test Navigator**: Press `⌘6`

3. **Find Test**: Look for `FIN1Tests` → `InvestmentTradingSimulationTests`

4. **Run Test**: Click the ▶️ icon next to `testCreateInvestment_WithVariousAmounts_CreatesSuccessfully`

5. **View Results**: Results appear in the test navigator and the issue navigator (`⌘5`)

---

## Continuous Integration

For CI/CD pipelines, use:

```bash
xcodebuild test \
  -scheme FIN1 \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -resultBundlePath ./test-results \
  -enableCodeCoverage YES
```

This generates a test results bundle and enables code coverage reporting.

















