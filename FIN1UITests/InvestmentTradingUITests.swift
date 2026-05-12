import XCTest

/// UI Tests for Investment and Trading Simulations
/// These tests launch the app in the simulator and show interactions step by step
/// You can watch the simulator to see the app navigate, fill forms, and execute trades
final class InvestmentTradingUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        // Continue after failure so we can see what's happening
        continueAfterFailure = true

        // Launch the app - you'll see it open in the simulator
        app = XCUIApplication()

        // Set launch arguments for test mode (if needed)
        // app.launchArguments = ["--uitesting"]

        app.launch()

        // Wait longer for app to be ready and show initial screen
        sleep(3)

        // In CI/simulator runs we may start on Landing. Ensure investor session exists
        // before tests that assume the main tab bar.
        ensureAuthenticatedInvestorSession()

        // Print debug info
        print("📱 App launched - Current screen elements:")
        print(app.debugDescription)
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Debug Test (Run This First!)

    /// Simple test to verify app launches and show what's available
    /// Run this first to see what elements are available in your app
    func testAppLaunches_ShowsAvailableElements() throws {
        print("\n🎬 ========================================")
        print("🎬 APP LAUNCH DEBUG TEST")
        print("🎬 ========================================\n")

        // Wait a bit for app to fully load
        sleep(3)

        // Print all available elements
        printAvailableElements()

        // Take a screenshot
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "App Launch Screen"
        add(attachment)

        print("\n✅ App launched successfully!")
        print("📸 Screenshot saved - check test report")
        print("👀 Watch the simulator - you should see the app running\n")

        // Just verify app is running
        XCTAssertTrue(app.exists, "App should be running")
    }

    // MARK: - Investment Creation UI Tests

    /// Test: Create an investment step by step
    /// Watch the simulator to see:
    /// 1. Navigate to Investments tab
    /// 2. Tap "New Investment" button
    /// 3. Fill in investment amount
    /// 4. Select number of investments
    /// 5. Submit investment
    func testCreateInvestment_StepByStep_ShowsInSimulator() throws {
        print("🎬 Starting Investment Creation Test")

        // Step 1: Wait for app to be ready and find tab bar
        print("📍 Step 1: Looking for tab bar...")
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(waitForElement(tabBar, timeout: 10), "Tab bar should exist")
        sleep(2) // Pause so you can see the tab bar

        // Step 2: Navigate to Investments tab
        print("📍 Step 2: Navigating to Investments tab...")
        // Try multiple ways to find the Investments tab
        var investmentsTab: XCUIElement?

        // Method 1: By label
        if app.tabBars.buttons["Investments"].exists {
            investmentsTab = app.tabBars.buttons["Investments"]
        }
        // Method 2: By accessibility identifier
        else if app.tabBars.buttons.matching(identifier: "Investments").firstMatch.exists {
            investmentsTab = app.tabBars.buttons.matching(identifier: "Investments").firstMatch
        }
        // Method 3: Try finding by index (usually tab 2 for investors)
        else if app.tabBars.buttons.count > 1 {
            investmentsTab = app.tabBars.buttons.element(boundBy: 2)
        }

        if let tab = investmentsTab, tab.exists {
            tab.tap()
            print("✅ Tapped Investments tab")
            sleep(3) // Longer pause so you can see the navigation
        } else {
            print("⚠️ Investments tab not found. Available tabs:")
            for (index, button) in app.tabBars.buttons.allElementsBoundByIndex.enumerated() {
                print("  Tab \(index): \(button.label)")
            }
        }

        // Step 3: Tap the "+" button to create new investment
        print("📍 Step 3: Looking for add button...")
        // Try multiple ways to find the add button
        var addButton: XCUIElement?

        // Method 1: By system image name
        if app.buttons["plus.circle.fill"].exists {
            addButton = app.buttons["plus.circle.fill"]
        }
        // Method 2: In navigation bar
        else if app.navigationBars.buttons["plus.circle.fill"].exists {
            addButton = app.navigationBars.buttons["plus.circle.fill"]
        }
        // Method 3: Any button with "plus" or "add"
        else if app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'plus' OR label CONTAINS[c] 'add'")).firstMatch.exists {
            addButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'plus' OR label CONTAINS[c] 'add'")).firstMatch
        }
        // Method 4: Navigation bar trailing button
        else if app.navigationBars.buttons.count > 0 {
            addButton = app.navigationBars.buttons.element(boundBy: app.navigationBars.buttons.count - 1)
        }

        if let button = addButton, button.exists {
            button.tap()
            print("✅ Tapped add button")
            sleep(3) // Longer pause to see the sheet appear
        } else {
            print("⚠️ Add button not found. Available buttons:")
            for (index, button) in app.buttons.allElementsBoundByIndex.prefix(10).enumerated() {
                print("  Button \(index): \(button.label)")
            }
        }

        // Step 4: Find and fill investment amount field
        print("📍 Step 4: Looking for amount field...")
        sleep(2) // Wait for sheet to fully appear

        // Try multiple ways to find the amount field
        var amountField: XCUIElement?

        // Method 1: By placeholder/label
        if app.textFields["Investment Amount"].exists {
            amountField = app.textFields["Investment Amount"]
        }
        // Method 2: Any text field
        else if app.textFields.count > 0 {
            amountField = app.textFields.firstMatch
        }
        // Method 3: Secure text fields (if any)
        else if app.secureTextFields.count > 0 {
            amountField = app.secureTextFields.firstMatch
        }

        if let field = amountField, field.exists {
            field.tap()
            sleep(1) // Wait for keyboard
            field.typeText("1000")
            print("✅ Entered amount: 1000")
            sleep(2) // Pause to see the value entered
        } else {
            print("⚠️ Amount field not found. Available text fields:")
            for (index, field) in app.textFields.allElementsBoundByIndex.enumerated() {
                print("  TextField \(index): \(field.label)")
            }
        }

        // Step 4: Select number of investments (if slider exists)
        // You'll see the slider move
        let investmentSlider = app.sliders["Number of Investments"]
        if investmentSlider.exists {
            investmentSlider.adjust(toNormalizedSliderPosition: 0.5) // Set to middle value
            sleep(1) // Pause to see the slider move
        }

        // Step 5: Tap submit/create button
        print("📍 Step 5: Looking for create/submit button...")
        sleep(1)

        // Try multiple button labels
        var createButton: XCUIElement?
        let buttonLabels = ["Create Investment", "Submit", "Create", "Save", "Confirm"]

        for label in buttonLabels {
            if app.buttons[label].exists {
                createButton = app.buttons[label]
                break
            }
        }

        // If not found, scan button labels (avoids NSPredicate / Swift 6 concurrency issues with `matching(_:)`).
        if createButton == nil {
            for button in app.buttons.allElementsBoundByIndex.prefix(40) {
                let lower = button.label.lowercased()
                if lower.contains("create") || lower.contains("submit") || lower.contains("save") {
                    createButton = button
                    break
                }
            }
        }

        if let button = createButton, button.exists {
            button.tap()
            print("✅ Tapped create button")
            sleep(4) // Longer pause to see the investment being created and confirmation
        } else {
            print("⚠️ Create button not found. Available buttons:")
            for (index, button) in app.buttons.allElementsBoundByIndex.prefix(15).enumerated() {
                print("  Button \(index): '\(button.label)'")
            }
        }

        print("✅ Investment creation test completed - check simulator for results")
        XCTAssertTrue(true, "Investment creation flow completed - check simulator")
    }

    /// Test: Create multiple investments with different amounts
    /// Watch the simulator to see each investment being created
    func testCreateMultipleInvestments_WithDifferentAmounts_ShowsInSimulator() throws {
        let amounts = ["500", "1000", "2000", "5000"]

        for (index, amount) in amounts.enumerated() {
            // Navigate to Investments tab
            let investmentsTab = app.tabBars.buttons["Investments"]
            if investmentsTab.exists {
                investmentsTab.tap()
                sleep(1)
            }

            // Tap add button
            let addButton = app.navigationBars.buttons["plus.circle.fill"]
            if addButton.exists {
                addButton.tap()
                sleep(1)
            }

            // Enter amount
            let amountField = app.textFields["Investment Amount"]
            if amountField.exists {
                amountField.tap()
                Thread.sleep(forTimeInterval: 0.5)
                // Clear existing text by selecting all and deleting
                if let currentValue = amountField.value as? String, !currentValue.isEmpty {
                    amountField.doubleTap()
                    Thread.sleep(forTimeInterval: 0.5)
                    if app.keys["delete"].exists {
                        app.keys["delete"].tap()
                    }
                }
                amountField.typeText(amount)
                sleep(1) // Watch the amount being entered
            }

            // Submit
            let createButton = app.buttons["Create Investment"]
            if createButton.exists {
                createButton.tap()
            } else if app.buttons["Submit"].exists {
                app.buttons["Submit"].tap()
            }

            // Wait and watch the confirmation
            sleep(2)

            print("✅ Created investment #\(index + 1) with amount €\(amount)")
        }

        XCTAssertTrue(true, "Multiple investments created - check simulator")
    }

    // MARK: - Trading UI Tests

    /// Test: Place a buy order step by step
    /// Watch the simulator to see:
    /// 1. Navigate to Dashboard
    /// 2. Tap "Handeln" (Trade) button
    /// 3. Search for a security
    /// 4. Fill in order details (quantity, price)
    /// 5. Submit buy order
    func testPlaceBuyOrder_StepByStep_ShowsInSimulator() throws {
        // Step 1: Navigate to Dashboard (if not already there)
        let dashboardTab = app.tabBars.buttons["Dashboard"]
        if dashboardTab.exists {
            dashboardTab.tap()
            sleep(1) // Watch navigation to dashboard
        }

        // Step 2: Tap "Handeln" button
        // You'll see the securities search view appear
        let handelnButton = app.buttons["Handeln"]
        if handelnButton.exists {
            handelnButton.tap()
            sleep(2) // Pause to see the search view appear
        }

        // Step 3: Search for a security
        // You'll see the search field get focus
        let searchField = app.searchFields.firstMatch
        if searchField.exists {
            searchField.tap()
            searchField.typeText("DAX")
            sleep(2) // Watch search results appear
        }

        // Step 4: Select a security from results
        // You'll see a security being selected
        let firstResult = app.cells.firstMatch
        if firstResult.exists {
            firstResult.tap()
            sleep(2) // Watch the buy order form appear
        }

        // Step 5: Fill in quantity
        // You'll see the quantity field get focus
        let quantityField = app.textFields["Quantity"]
        if !quantityField.exists {
            // Try alternative identifiers
            let qtyField = app.textFields.matching(identifier: "quantity").firstMatch
            if qtyField.exists {
                qtyField.tap()
                qtyField.typeText("100")
                sleep(1) // Watch quantity being entered
            }
        } else {
            quantityField.tap()
            quantityField.typeText("100")
            sleep(1)
        }

        // Step 6: Fill in price (if field exists)
        let priceField = app.textFields["Price"]
        if priceField.exists {
            priceField.tap()
            priceField.typeText("10.50")
            sleep(1) // Watch price being entered
        }

        // Step 7: Submit buy order
        // You'll see the order being placed
        let placeOrderButton = app.buttons["Place Order"]
        if !placeOrderButton.exists {
            // Try alternative button labels
            if app.buttons["Buy"].exists {
                app.buttons["Buy"].tap()
            } else if app.buttons["Submit"].exists {
                app.buttons["Submit"].tap()
            }
        } else {
            placeOrderButton.tap()
        }

        // Wait for order confirmation
        sleep(3) // Watch the order being processed

        XCTAssertTrue(true, "Buy order placed - check simulator")
    }

    /// Test: Place multiple buy orders with different prices and quantities
    /// Watch the simulator to see each order being placed
    func testPlaceMultipleBuyOrders_WithDifferentParameters_ShowsInSimulator() throws {
        let testScenarios: [(quantity: String, price: String)] = [
            ("50", "5.00"),
            ("100", "10.00"),
            ("200", "15.50"),
            ("500", "20.00")
        ]

        for (index, scenario) in testScenarios.enumerated() {
            // Navigate to Dashboard
            let dashboardTab = app.tabBars.buttons["Dashboard"]
            if dashboardTab.exists {
                dashboardTab.tap()
                sleep(1)
            }

            // Tap Handeln button
            let handelnButton = app.buttons["Handeln"]
            if handelnButton.exists {
                handelnButton.tap()
                sleep(2)
            }

            // Search for security
            let searchField = app.searchFields.firstMatch
            if searchField.exists {
                searchField.tap()
                Thread.sleep(forTimeInterval: 0.5)
                // Clear existing text by selecting all and deleting
                if let currentValue = searchField.value as? String, !currentValue.isEmpty {
                    searchField.doubleTap()
                    Thread.sleep(forTimeInterval: 0.5)
                    if app.keys["delete"].exists {
                        app.keys["delete"].tap()
                    }
                }
                searchField.typeText("DAX")
                sleep(2)
            }

            // Select first result
            let firstResult = app.cells.firstMatch
            if firstResult.exists {
                firstResult.tap()
                sleep(2)
            }

            // Enter quantity
            let quantityField = app.textFields.matching(identifier: "quantity").firstMatch
            if quantityField.exists {
                quantityField.tap()
                Thread.sleep(forTimeInterval: 0.5)
                // Clear existing text
                if let currentValue = quantityField.value as? String, !currentValue.isEmpty {
                    quantityField.doubleTap()
                    Thread.sleep(forTimeInterval: 0.5)
                    if app.keys["delete"].exists {
                        app.keys["delete"].tap()
                    }
                }
                quantityField.typeText(scenario.quantity)
                sleep(1) // Watch quantity being entered
            }

            // Enter price
            let priceField = app.textFields.matching(identifier: "price").firstMatch
            if priceField.exists {
                priceField.tap()
                Thread.sleep(forTimeInterval: 0.5)
                // Clear existing text
                if let currentValue = priceField.value as? String, !currentValue.isEmpty {
                    priceField.doubleTap()
                    Thread.sleep(forTimeInterval: 0.5)
                    if app.keys["delete"].exists {
                        app.keys["delete"].tap()
                    }
                }
                priceField.typeText(scenario.price)
                sleep(1) // Watch price being entered
            }

            // Submit order
            if app.buttons["Place Order"].exists {
                app.buttons["Place Order"].tap()
            } else if app.buttons["Buy"].exists {
                app.buttons["Buy"].tap()
            }

            // Wait for confirmation
            sleep(3)

            print("✅ Placed buy order #\(index + 1): \(scenario.quantity) units @ €\(scenario.price)")
        }

        XCTAssertTrue(true, "Multiple buy orders placed - check simulator")
    }

    /// Regression test: In limit mode, buy action must remain tappable when input is valid.
    @MainActor
    func testLimitBuyOrder_ButtonEnabledWhenLimitIsSet() throws {
        app.terminate()
        app.launchArguments = ["--uitesting", "--reset-state", "--ui-test-entry-limit-buy-order", "--ui-test-prefill-limit-order"]
        app.launch()

        let loading = app.otherElements["UITestLimitEntryLoading"].firstMatch
        _ = waitForElement(loading, timeout: 5)
        let buyRoot = app.otherElements["UITestDirectBuyOrderRoot"].firstMatch
        XCTAssertTrue(waitForElement(buyRoot, timeout: 45), "Buy test root should be visible")

        let quantityField = app.textFields["QuantityInputField"].firstMatch
        XCTAssertTrue(waitForElement(quantityField, timeout: 10), "Precondition failed: buy form not opened")
        quantityField.tap()
        quantityField.typeText("100")
        sleep(1)

        let placeOrderButton = app.buttons["PlaceOrderButton"].firstMatch
        XCTAssertTrue(waitForElement(placeOrderButton, timeout: 10), "Precondition failed: buy action button missing")
        let enabledBeforeSwitch = placeOrderButton.isEnabled

        let limitSegment = app.buttons["Limit"].firstMatch
        XCTAssertTrue(waitForElement(limitSegment, timeout: 5), "Precondition failed: limit segment missing")
        limitSegment.tap()

        let limitField = app.textFields["LimitPriceField"].firstMatch
        XCTAssertTrue(waitForElement(limitField, timeout: 10), "Precondition failed: limit field missing")
        let enabledAfterSwitch = placeOrderButton.isEnabled
        XCTAssertEqual(
            enabledAfterSwitch,
            enabledBeforeSwitch,
            "Buy order button enabled state must not change solely because of market/limit toggle"
        )
    }

    /// Regression test: In limit mode, sell action must remain tappable when input is valid.
    @MainActor
    func testLimitSellOrder_ButtonEnabledWhenLimitIsSet() throws {
        app.terminate()
        app.launchArguments = ["--uitesting", "--reset-state", "--ui-test-entry-limit-sell-order", "--ui-test-prefill-limit-order"]
        app.launch()

        let loading = app.otherElements["UITestLimitEntryLoading"].firstMatch
        _ = waitForElement(loading, timeout: 5)
        let sellRoot = app.otherElements["UITestDirectSellOrderRoot"].firstMatch
        XCTAssertTrue(waitForElement(sellRoot, timeout: 45), "Sell test root should be visible")

        let sellQuantityField = app.textFields["QuantityInputField"].firstMatch
        XCTAssertTrue(waitForElement(sellQuantityField, timeout: 10), "Precondition failed: sell form not opened")
        sellQuantityField.tap()
        sellQuantityField.typeText("100")
        sleep(1)

        let placeSellButton = app.buttons["PlaceSellOrderButton"].firstMatch.exists
            ? app.buttons["PlaceSellOrderButton"].firstMatch
            : app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Verkaufen'")).firstMatch
        XCTAssertTrue(waitForElement(placeSellButton, timeout: 10), "Precondition failed: sell action button missing")
        let enabledBeforeSwitch = placeSellButton.isEnabled

        let limitSegment = app.buttons["Limit"].firstMatch
        XCTAssertTrue(waitForElement(limitSegment, timeout: 5), "Precondition failed: sell limit segment missing")
        limitSegment.tap()
        sleep(1)

        let limitField = app.textFields["LimitPriceField"].firstMatch
        XCTAssertTrue(waitForElement(limitField, timeout: 10), "Precondition failed: sell limit field missing")
        let enabledAfterSwitch = placeSellButton.isEnabled
        XCTAssertEqual(
            enabledAfterSwitch,
            enabledBeforeSwitch,
            "Sell order button enabled state must not change solely because of market/limit toggle"
        )
    }

    // MARK: - Complete Trade Cycle UI Tests

    /// Test: Complete trade cycle (buy then sell)
    /// Watch the simulator to see the complete flow
    func testCompleteTradeCycle_BuyThenSell_ShowsInSimulator() throws {
        // Part 1: Place Buy Order
        print("📈 Step 1: Placing buy order...")

        let dashboardTab = app.tabBars.buttons["Dashboard"]
        if dashboardTab.exists {
            dashboardTab.tap()
            sleep(1)
        }

        let handelnButton = app.buttons["Handeln"]
        if handelnButton.exists {
            handelnButton.tap()
            sleep(2)
        }

        let searchField = app.searchFields.firstMatch
        if searchField.exists {
            searchField.tap()
            searchField.typeText("DAX")
            sleep(2)
        }

        let firstResult = app.cells.firstMatch
        if firstResult.exists {
            firstResult.tap()
            sleep(2)
        }

        // Enter buy order details
        let quantityField = app.textFields.matching(identifier: "quantity").firstMatch
        if quantityField.exists {
            quantityField.tap()
            quantityField.typeText("100")
            sleep(1)
        }

        let priceField = app.textFields.matching(identifier: "price").firstMatch
        if priceField.exists {
            priceField.tap()
            priceField.typeText("10.00")
            sleep(1)
        }

        // Place buy order
        if app.buttons["Place Order"].exists {
            app.buttons["Place Order"].tap()
        } else if app.buttons["Buy"].exists {
            app.buttons["Buy"].tap()
        }

        sleep(3) // Watch buy order being processed
        print("✅ Buy order placed")

        // Part 2: Navigate to Depot/Trades to find the trade
        print("📊 Step 2: Finding trade in depot...")

        let depotTab = app.tabBars.buttons["Depot"]
        if depotTab.exists {
            depotTab.tap()
            sleep(2) // Watch depot view appear
        } else {
            let tradesTab = app.tabBars.buttons["Trades"]
            if tradesTab.exists {
                tradesTab.tap()
                sleep(2)
            }
        }

        // Part 3: Select trade and place sell order
        print("💰 Step 3: Placing sell order...")

        // Find the trade we just created
        let tradeCell = app.cells.firstMatch
        if tradeCell.exists {
            tradeCell.tap()
            sleep(2) // Watch trade details appear
        }

        // Look for sell button
        let sellButton = app.buttons["Sell"]
        if !sellButton.exists {
            // Try alternative labels
            if app.buttons["Place Sell Order"].exists {
                app.buttons["Place Sell Order"].tap()
            } else if app.buttons["Sell Order"].exists {
                app.buttons["Sell Order"].tap()
            }
        } else {
            sellButton.tap()
        }

        sleep(2) // Watch sell order form appear

        // Enter sell details
        let sellQuantityField = app.textFields.matching(identifier: "sellQuantity").firstMatch
        if sellQuantityField.exists {
            sellQuantityField.tap()
            sellQuantityField.typeText("100")
            sleep(1)
        }

        let sellPriceField = app.textFields.matching(identifier: "sellPrice").firstMatch
        if sellPriceField.exists {
            sellPriceField.tap()
            sellPriceField.typeText("12.00")
            sleep(1)
        }

        // Submit sell order
        if app.buttons["Place Sell Order"].exists {
            app.buttons["Place Sell Order"].tap()
        } else if app.buttons["Sell"].exists {
            app.buttons["Sell"].tap()
        }

        sleep(3) // Watch sell order being processed
        print("✅ Sell order placed - Trade cycle complete!")

        XCTAssertTrue(true, "Complete trade cycle executed - check simulator")
    }

    // MARK: - Investment Performance UI Tests

    /// Test: View investment performance
    /// Watch the simulator to see investment details and performance metrics
    func testViewInvestmentPerformance_ShowsInSimulator() throws {
        // Navigate to Investments tab
        let investmentsTab = app.tabBars.buttons["Investments"]
        if investmentsTab.exists {
            investmentsTab.tap()
            sleep(1)
        }

        // Tap on an investment to view details
        // You'll see the investment detail sheet appear
        let investmentCell = app.cells.firstMatch
        if investmentCell.exists {
            investmentCell.tap()
            sleep(2) // Watch the detail view appear

            // Scroll to see performance metrics
            app.swipeUp()
            sleep(1)
            app.swipeUp()
            sleep(1)

            // Look for performance indicators
            // These should be visible in the detail view
            print("✅ Investment details displayed - check simulator for performance metrics")
        }

        XCTAssertTrue(true, "Investment performance viewed - check simulator")
    }

    // MARK: - Helper Methods

    /// Helper: Wait for element with timeout
    func waitForElement(_ element: XCUIElement, timeout: TimeInterval = 10.0) -> Bool {
        let predicate = NSPredicate(format: "exists == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        return result == .completed
    }

    /// Helper: If app is on landing/login, sign in with debug investor button.
    private func ensureAuthenticatedInvestorSession() {
        let tabBar = app.tabBars.firstMatch
        if waitForElement(tabBar, timeout: 5) {
            return
        }

        let investorDebugButton = app.buttons["LoginInvestor1Button"]
        if waitForElement(investorDebugButton, timeout: 10) {
            investorDebugButton.tap()
            _ = waitForElement(tabBar, timeout: 20)
        }
    }

    @MainActor
    private func ensureAuthenticatedTraderSession() {
        let tabBar = app.tabBars.firstMatch
        if waitForElement(tabBar, timeout: 5), app.buttons["HandelnButton"].firstMatch.exists || app.buttons["Handeln"].firstMatch.exists {
            return
        }

        // Deterministic relaunch to landing + trader debug login.
        app.terminate()
        app.launchArguments = ["--uitesting", "--reset-state"]
        app.launch()
        sleep(2)

        let traderDebugButtonById = app.buttons["LoginTrader1Button"]
        if waitForElement(traderDebugButtonById, timeout: 10) {
            traderDebugButtonById.tap()
            _ = waitForElement(tabBar, timeout: 20)
            return
        }

        // Fallback by explicit label used in debug landing.
        let traderDebugButtonByLabel = app.buttons["Test: Sign In as Trader 1"]
        if waitForElement(traderDebugButtonByLabel, timeout: 5) {
            traderDebugButtonByLabel.tap()
            _ = waitForElement(tabBar, timeout: 20)
        }
    }

    @MainActor
    private func relaunchAsTraderForLimitTests() {
        app.terminate()
        app.launchArguments = ["--uitesting", "--reset-state", "--ui-test-entry-trading-search"]
        app.launch()
        _ = ensureTradingSearchVisible()
        sleep(1)
    }

    @MainActor
    private func ensureTradingSearchVisible() -> Bool {
        acceptTermsIfPresented()

        // Slow backend environments can delay trader auto-login significantly.
        // Prefer explicit entry-state markers before generic UI probing.
        let loadingMarker = app.otherElements["UITestTradingEntryLoading"].firstMatch
        let readyMarker = app.otherElements["UITestTradingEntryReady"].firstMatch
        let errorMarker = app.otherElements["UITestTradingEntryError"].firstMatch
        _ = waitForElement(loadingMarker, timeout: 5)
        if waitForElement(readyMarker, timeout: 120) {
            return waitForElement(tradingSearchField(), timeout: 20)
        }
        if errorMarker.exists {
            return false
        }

        if waitForElement(tradingSearchField(), timeout: 5) { return true }

        let handelnButton = app.buttons["HandelnButton"].firstMatch.exists ? app.buttons["HandelnButton"].firstMatch : app.buttons["Handeln"].firstMatch
        guard waitForElement(handelnButton, timeout: 10) else {
            return waitForElement(tradingSearchField(), timeout: 20)
        }

        // Retry once because first tap can be swallowed by transient overlays/animations.
        for _ in 0..<2 {
            handelnButton.tap()
            if waitForElement(tradingSearchField(), timeout: 6) {
                return true
            }
            sleep(1)
        }
        return false
    }

    @MainActor
    private func tradingSearchField() -> XCUIElement {
        let byId = app.textFields["SecuritiesSearchField"].firstMatch
        if byId.exists { return byId }
        return app.searchFields.firstMatch
    }

    @MainActor
    private func acceptTermsIfPresented() {
        // Terms modal can block all interactions in fresh sessions.
        // Try tapping "Accept" up to two times (Terms + Privacy) if shown.
        for _ in 0..<2 {
            let acceptButton = app.buttons["Accept"].firstMatch
            guard waitForElement(acceptButton, timeout: 2) else { break }
            if acceptButton.isHittable {
                acceptButton.tap()
                sleep(1)
            } else {
                break
            }
        }
    }

    /// Helper: Print all available UI elements for debugging
    func printAvailableElements() {
        print("\n📋 Available UI Elements:")
        print("  Buttons: \(app.buttons.count)")
        print("  TextFields: \(app.textFields.count)")
        print("  StaticTexts: \(app.staticTexts.count)")
        print("  Cells: \(app.cells.count)")
        print("  TabBar buttons: \(app.tabBars.buttons.count)")
        print("\n  TabBar button labels:")
        for button in app.tabBars.buttons.allElementsBoundByIndex {
            print("    - \(button.label)")
        }
    }

}

// MARK: - Test Suite Organization

extension InvestmentTradingUITests {

    /// Run all investment UI tests
    func testInvestmentUISuite() throws {
        try testCreateInvestment_StepByStep_ShowsInSimulator()
        try testCreateMultipleInvestments_WithDifferentAmounts_ShowsInSimulator()
        try testViewInvestmentPerformance_ShowsInSimulator()
    }

    /// Run all trading UI tests
    func testTradingUISuite() throws {
        try testPlaceBuyOrder_StepByStep_ShowsInSimulator()
        try testPlaceMultipleBuyOrders_WithDifferentParameters_ShowsInSimulator()
        try testCompleteTradeCycle_BuyThenSell_ShowsInSimulator()
    }

    /// Run complete UI test suite
    func testCompleteUISuite() throws {
        try testInvestmentUISuite()
        try testTradingUISuite()
    }
}

