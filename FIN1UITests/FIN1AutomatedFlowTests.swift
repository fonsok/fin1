//
//  FIN1AutomatedFlowTests.swift
//  FIN1UITests
//
//  UI Tests for automated flow demonstration
//  Testing Investment Creation, Trading, and Account Statements
//

import XCTest

/// Automated UI test suite demonstrating key app flows in the simulator
/// Tests investment creation, trading, and result verification
final class FIN1AutomatedFlowTests: XCTestCase {

    var app: XCUIApplication!

    // MARK: - Test Configuration

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()

        // Configure app for UI testing - reset state for each test
        app.launchArguments = ["--uitesting", "--reset-state"]

        // Terminate any existing instance
        app.terminate()
    }

    override func tearDownWithError() throws {
        // Take final screenshot on failure
        if let failureCount = testRun?.failureCount, failureCount > 0 {
            let screenshot = app.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = "FailureScreenshot"
            attachment.lifetime = .keepAlways
            add(attachment)
        }

        app.terminate()
        app = nil
    }

    // MARK: - Test Helpers

    /// Wait for element to exist with timeout
    private func waitForElement(_ element: XCUIElement, timeout: TimeInterval = 10) -> Bool {
        let exists = element.waitForExistence(timeout: timeout)
        print("  ⏳ Waiting for element: \(element.debugDescription) - \(exists ? "✅ Found" : "❌ Not found")")
        return exists
    }

    /// Tap element with logging
    private func tapElement(_ element: XCUIElement, description: String = "") {
        let desc = description.isEmpty ? element.debugDescription : description
        print("  👆 Tapping: \(desc)")
        element.tap()
        sleep(1) // Give UI time to respond
    }

    /// Log step with emoji
    private func logStep(_ step: Int, _ description: String) {
        print("\n📍 Step \(step): \(description)")
    }

    /// Log test section
    private func logSection(_ title: String) {
        print("\n" + String(repeating: "=", count: 50))
        print("🧪 \(title)")
        print(String(repeating: "=", count: 50))
    }

    /// Debug helper - print all visible tabs
    private func debugPrintTabs() {
        print("  📋 Available tabs:")
        let tabButtons = app.tabBars.buttons.allElementsBoundByIndex
        for (index, tab) in tabButtons.enumerated() {
            print("    [\(index)] \(tab.label)")
        }
    }

    /// Debug helper - print button info
    private func debugPrintButtons(prefix: String = "") {
        let allButtons = app.buttons.allElementsBoundByIndex.prefix(15)
        print("  📋 \(prefix)First 15 buttons:")
        for (index, button) in allButtons.enumerated() {
            print("    [\(index)] '\(button.label)' id=\(button.identifier)")
        }
    }

    // MARK: - Login Helpers

    /// Login as Investor using debug buttons
    private func loginAsInvestor(number: Int = 1) -> Bool {
        print("\n🔐 Logging in as Investor \(number)...")

        // Check if already logged in
        let tabBar = app.tabBars.firstMatch
        if tabBar.exists {
            print("  ✅ Already logged in - tab bar visible")
            return true
        }

        // Wait for landing page to be visible
        sleep(2)

        // The exact button label from the app
        let exactLabel = "Test: Sign In as Investor \(number)"
        print("  🔍 Looking for button: '\(exactLabel)'")

        // Try finding by exact label first (most reliable)
        let buttonByLabel = app.buttons[exactLabel]

        if buttonByLabel.waitForExistence(timeout: 3) {
            print("  ✅ Found button by exact label!")
            print("  📍 Button frame: \(buttonByLabel.frame)")
            print("  📍 Is hittable: \(buttonByLabel.isHittable)")

            // Force tap using coordinate if not hittable
            if buttonByLabel.isHittable {
                buttonByLabel.tap()
                print("  👆 Tapped button directly")
            } else {
                let coordinate = buttonByLabel.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                coordinate.tap()
                print("  👆 Tapped button via coordinate")
            }
        } else {
            // Try by accessibility identifier
            let buttonById = app.buttons["LoginInvestor\(number)Button"]
            if buttonById.waitForExistence(timeout: 2) {
                print("  ✅ Found by identifier")
                buttonById.tap()
            } else {
                // Last resort: find by partial match
                print("  🔍 Trying partial match...")
                let buttons = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Investor \(number)'"))
                print("  📊 Found \(buttons.count) matching buttons")

                if buttons.count > 0 {
                    buttons.element(boundBy: 0).tap()
                    print("  👆 Tapped first matching button")
                } else {
                    print("  ❌ Could not find login button for Investor \(number)")
                    return false
                }
            }
        }

        // Wait for login to complete and tab bar to appear
        print("  ⏳ Waiting for login to complete...")
        sleep(3)

        if tabBar.waitForExistence(timeout: 15) {
            print("  ✅ Login successful - Main tab bar appeared")
            return true
        } else {
            print("  ❌ Login failed - Tab bar did not appear")
            // Take screenshot to see what's on screen
            let screenshot = app.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = "LoginFailed_Investor\(number)"
            attachment.lifetime = .keepAlways
            add(attachment)
            return false
        }
    }

    /// Login as Trader using debug buttons
    private func loginAsTrader(number: Int = 1) -> Bool {
        print("\n🔐 Logging in as Trader \(number)...")

        // Check if already logged in
        let tabBar = app.tabBars.firstMatch
        if tabBar.exists {
            print("  ✅ Already logged in - tab bar visible")
            return true
        }

        // Wait for landing page to be visible
        sleep(2)

        // The exact button label from the app
        let exactLabel = "Test: Sign In as Trader \(number)"
        print("  🔍 Looking for button: '\(exactLabel)'")

        // Try finding by exact label first (most reliable)
        let buttonByLabel = app.buttons[exactLabel]

        if buttonByLabel.waitForExistence(timeout: 3) {
            print("  ✅ Found button by exact label!")
            print("  📍 Button frame: \(buttonByLabel.frame)")
            print("  📍 Is hittable: \(buttonByLabel.isHittable)")

            // Force tap using coordinate if not hittable
            if buttonByLabel.isHittable {
                buttonByLabel.tap()
                print("  👆 Tapped button directly")
            } else {
                let coordinate = buttonByLabel.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                coordinate.tap()
                print("  👆 Tapped button via coordinate")
            }
        } else {
            // Try by accessibility identifier
            let buttonById = app.buttons["LoginTrader\(number)Button"]
            if buttonById.waitForExistence(timeout: 2) {
                print("  ✅ Found by identifier")
                buttonById.tap()
            } else {
                // Last resort: find by partial match
                print("  🔍 Trying partial match...")
                let buttons = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Trader \(number)'"))
                print("  📊 Found \(buttons.count) matching buttons")

                if buttons.count > 0 {
                    buttons.element(boundBy: 0).tap()
                    print("  👆 Tapped first matching button")
                } else {
                    print("  ❌ Could not find login button for Trader \(number)")
                    return false
                }
            }
        }

        // Wait for login to complete and tab bar to appear
        print("  ⏳ Waiting for login to complete...")
        sleep(3)

        if tabBar.waitForExistence(timeout: 15) {
            print("  ✅ Login successful - Main tab bar appeared")
            return true
        } else {
            print("  ❌ Login failed - Tab bar did not appear")
            // Take screenshot to see what's on screen
            let screenshot = app.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = "LoginFailed_Trader\(number)"
            attachment.lifetime = .keepAlways
            add(attachment)
            return false
        }
    }

    // MARK: - Test 1: Investment Creation Flow (Multi-Investors)

    /// Tests the complete investment creation flow for investors
    @MainActor
    func testInvestmentCreationFlowMultiInvestors() throws {
        logSection("Investment Creation Flow (Multi-Investors)")

        // Launch the app
        logStep(0, "Launching app")
        app.launch()
        sleep(3)

        // Print initial state
        print("  📱 App launched")
        print("  📱 Current elements: \(app.buttons.count) buttons, \(app.tabBars.count) tab bars")
        debugPrintButtons(prefix: "After launch - ")

        // Login as Investor
        logStep(1, "Logging in as Investor")
        let loginSuccess = loginAsInvestor(number: 1)

        if !loginSuccess {
            let screenshot = app.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = "InvestorLoginFailed"
            attachment.lifetime = .keepAlways
            add(attachment)
            XCTFail("Could not login as Investor - check screenshot")
            return
        }

        // Debug: Show available tabs
        debugPrintTabs()

        // Navigate to Investments tab (for Investor it's "Discover" then find a trader)
        logStep(2, "Navigating to find a trader to invest with")

        // For investors, we need to go to Discover tab to find traders
        let discoverTab = app.tabBars.buttons["Discover"]
        if waitForElement(discoverTab, timeout: 5) {
            tapElement(discoverTab, description: "Discover Tab")
        }

        sleep(2)

        // Look for any trader card/row to tap
        logStep(3, "Looking for a trader to select")

        // Try finding "Invest with" buttons or trader rows
        let investButtons = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'InvestWithTraderButton' OR label CONTAINS[c] 'Invest with'"))

        if investButtons.count > 0 {
            logStep(4, "Tapping on a trader to invest")
            tapElement(investButtons.element(boundBy: 0), description: "Invest with Trader button")
        } else {
            // Try finding any clickable trader cell
            let traderCells = app.cells.allElementsBoundByIndex
            if traderCells.count > 0 {
                tapElement(traderCells[0], description: "First trader cell")
            } else {
                // Try tapping on static text that might be a trader name
                let results = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'trader' OR label CONTAINS[c] 'Results'"))
                print("  📊 Found \(results.count) potential trader elements")

                // Take a screenshot for debugging
                let screenshot = app.screenshot()
                let attachment = XCTAttachment(screenshot: screenshot)
                attachment.name = "InvestorDiscovery"
                add(attachment)
            }
        }

        sleep(2)

        // Look for Investment Sheet elements
        logStep(5, "Looking for Investment form elements")

        let amountField = app.textFields["InvestmentAmountField"]
        let slider = app.sliders["InvestmentCountSlider"]
        let createButton = app.buttons["CreateInvestmentButton"]

        if waitForElement(amountField, timeout: 5) {
            logStep(6, "Entering investment amount: 1000")
            amountField.tap()
            amountField.typeText("1000")

            if waitForElement(slider, timeout: 3) {
                logStep(7, "Adjusting slider for multiple investments")
                slider.adjust(toNormalizedSliderPosition: 0.3)
            }

            // Take a screenshot
            let screenshot = app.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = "InvestmentFormFilled"
            add(attachment)

            if waitForElement(createButton, timeout: 3) && createButton.isEnabled {
                logStep(8, "Tapping Create Investment button")
                tapElement(createButton, description: "Create Investment")

                sleep(2)

                // Check for success
                let alerts = app.alerts
                if alerts.count > 0 {
                    print("  ✅ Success alert appeared!")
                    alerts.firstMatch.buttons.firstMatch.tap()
                }
            } else {
                print("  ⚠️ Create button not enabled or not found")
            }
        } else {
            print("  ⚠️ Investment form not displayed - may need to select a trader first")

            // Take screenshot for debugging
            let screenshot = app.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = "NoInvestmentForm"
            add(attachment)
        }

        print("\n✅ Investment Creation Flow Test Completed")
    }

    // MARK: - Test 2: Trading Flow (Securities Search)

    /// Tests the complete trading flow for traders
    @MainActor
    func testTradingFlowWithSecuritiesSearch() throws {
        logSection("Trading Flow with Securities Search")

        // Launch the app
        logStep(0, "Launching app")
        app.launch()
        sleep(2)

        // Login as Trader
        logStep(1, "Logging in as Trader")
        let loginSuccess = loginAsTrader(number: 1)
        XCTAssertTrue(loginSuccess, "Should be able to login as Trader")

        // Navigate to Dashboard
        logStep(2, "Navigating to Dashboard")
        let dashboardTab = app.tabBars.buttons["Dashboard"]
        if waitForElement(dashboardTab, timeout: 5) {
            tapElement(dashboardTab, description: "Dashboard Tab")
        }

        sleep(1)

        // Tap "Handeln" button
        logStep(3, "Looking for Handeln button")
        let handelnButton = app.buttons["HandelnButton"]

        if waitForElement(handelnButton, timeout: 5) {
            tapElement(handelnButton, description: "Handeln Button")
        } else {
            // Try finding by label
            let buttons = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Handeln'"))
            if buttons.count > 0 {
                tapElement(buttons.element(boundBy: 0), description: "Handeln (by label)")
            } else {
                // Take screenshot
                let screenshot = app.screenshot()
                let attachment = XCTAttachment(screenshot: screenshot)
                attachment.name = "NoHandelnButton"
                add(attachment)

                XCTFail("Handeln button not found on Dashboard")
            }
        }

        sleep(2)

        // Securities search should appear
        logStep(4, "Searching for securities")
        let searchField = app.textFields["SecuritiesSearchField"]

        if waitForElement(searchField, timeout: 5) {
            tapElement(searchField, description: "Search Field")
            searchField.typeText("DAX")
            print("  ⌨️ Typed 'DAX' in search field")
        } else {
            // Try any text field
            let textFields = app.textFields
            if textFields.count > 0 {
                let field = textFields.element(boundBy: 0)
                tapElement(field, description: "First text field")
                field.typeText("DAX")
            } else {
                print("  ⚠️ No search field found")
            }
        }

        sleep(2)

        // Look for search results
        logStep(5, "Looking for KAUFEN buttons in results")
        let kaufenButtons = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'KAUFEN'"))
        print("  📊 Found \(kaufenButtons.count) KAUFEN buttons")

        if kaufenButtons.count > 0 {
            logStep(6, "Tapping first KAUFEN button")
            tapElement(kaufenButtons.element(boundBy: 0), description: "KAUFEN button")

            sleep(2)

            // Enter quantity
            logStep(7, "Entering quantity")
            let quantityField = app.textFields["QuantityInputField"]
            if waitForElement(quantityField, timeout: 5) {
                tapElement(quantityField, description: "Quantity field")
                quantityField.typeText("10")
            } else {
                // Try any text field in the order form
                let textFields = app.textFields
                if textFields.count > 0 {
                    tapElement(textFields.element(boundBy: 0), description: "First text field")
                    textFields.element(boundBy: 0).typeText("10")
                }
            }

            // Take screenshot before placing order
            let screenshot = app.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = "OrderFormFilled"
            add(attachment)

            // Place order
            logStep(8, "Looking for Place Order button")
            let placeOrderButton = app.buttons["PlaceOrderButton"]
            let orderButtons = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Kaufen' AND NOT label CONTAINS[c] 'KAUFEN'"))

            if waitForElement(placeOrderButton, timeout: 3) && placeOrderButton.isEnabled {
                tapElement(placeOrderButton, description: "Place Order")
            } else if orderButtons.count > 0 {
                let btn = orderButtons.element(boundBy: 0)
                if btn.isEnabled {
                    tapElement(btn, description: "Buy Order button")
                }
            }

            sleep(3)

            // Check for success overlay
            logStep(9, "Checking for confirmation")
            let successOverlay = app.otherElements["OrderSuccessOverlay"]
            let dismissButton = app.buttons["OrderSuccessDismissButton"]

            if successOverlay.exists || dismissButton.exists {
                print("  ✅ Order success overlay appeared!")
                if dismissButton.exists {
                    tapElement(dismissButton, description: "Dismiss success")
                }
            } else {
                // Take screenshot
                let screenshot2 = app.screenshot()
                let attachment2 = XCTAttachment(screenshot: screenshot2)
                attachment2.name = "AfterPlaceOrder"
                add(attachment2)
            }
        } else {
            // Take screenshot
            let screenshot = app.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = "NoSearchResults"
            add(attachment)

            print("  ⚠️ No KAUFEN buttons found - search may have no results")
        }

        print("\n✅ Trading Flow Test Completed")
    }

    // MARK: - Test 3: Results & Statements Verification

    /// Tests showing results at investor and trader relevant state
    @MainActor
    func testResultsAndAccountStatements() throws {
        logSection("Results & Account Statements Verification")

        // Launch the app
        logStep(0, "Launching app")
        app.launch()
        sleep(3)

        // Debug
        debugPrintButtons(prefix: "After launch - ")

        // Login as Investor first to check investor views
        logStep(1, "Logging in as Investor to check investor views")
        let loginSuccess = loginAsInvestor(number: 1)

        if !loginSuccess {
            let screenshot = app.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = "InvestorLoginFailed_Statements"
            attachment.lifetime = .keepAlways
            add(attachment)
            XCTFail("Could not login as Investor - check screenshot")
            return
        }

        // Debug: Show available tabs
        debugPrintTabs()

        // Check Investments tab
        logStep(2, "Checking Investments tab")
        let investmentsTab = app.tabBars.buttons["Investments"]
        if waitForElement(investmentsTab, timeout: 5) {
            tapElement(investmentsTab, description: "Investments Tab")
            sleep(2)

            // Take screenshot
            let screenshot = app.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = "InvestorInvestmentsView"
            add(attachment)

            // Verify content
            let hasContent = app.staticTexts.count > 0
            print("  📊 Investments view has \(app.staticTexts.count) text elements")
            XCTAssertTrue(hasContent, "Investments view should have content")
        }

        // Check Profile for notifications
        logStep(3, "Checking Profile tab for notifications")
        let profileTab = app.tabBars.buttons["Profile"]
        if waitForElement(profileTab, timeout: 5) {
            tapElement(profileTab, description: "Profile Tab")
            sleep(2)

            // Take screenshot
            let screenshot = app.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = "InvestorProfileView"
            add(attachment)

            print("  📊 Profile view loaded with \(app.staticTexts.count) text elements")
        }

        // Navigate to Dashboard to check account statement access
        logStep(4, "Checking Dashboard for account statement")
        let dashboardTab = app.tabBars.buttons["Dashboard"]
        if waitForElement(dashboardTab, timeout: 5) {
            tapElement(dashboardTab, description: "Dashboard Tab")
            sleep(2)

            // Take screenshot
            let screenshot = app.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = "InvestorDashboardView"
            add(attachment)

            // Look for account statement button/section
            let statementButtons = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Statement' OR label CONTAINS[c] 'Kontoauszug' OR label CONTAINS[c] 'Balance'"))
            print("  📊 Found \(statementButtons.count) statement-related buttons")

            if statementButtons.count > 0 {
                tapElement(statementButtons.element(boundBy: 0), description: "Account Statement")
                sleep(2)

                let screenshot2 = app.screenshot()
                let attachment2 = XCTAttachment(screenshot: screenshot2)
                attachment2.name = "AccountStatementView"
                add(attachment2)

                // Dismiss if needed
                let doneButton = app.buttons["Done"]
                if doneButton.exists {
                    tapElement(doneButton, description: "Done button")
                }
            }
        }

        print("\n✅ Results & Account Statements Test Completed")
    }

    // MARK: - Test 4: Complete Trader Journey

    /// Tests the complete trader journey: Dashboard -> Trade -> View Results
    @MainActor
    func testTraderJourneyWithResults() throws {
        logSection("Complete Trader Journey")

        // Launch the app
        logStep(0, "Launching app")
        app.launch()
        sleep(3)

        // Debug: Show what's on screen
        debugPrintButtons(prefix: "After launch - ")

        // Login as Trader
        logStep(1, "Logging in as Trader")
        let loginSuccess = loginAsTrader(number: 1)

        if !loginSuccess {
            // Take screenshot and skip remaining steps instead of failing hard
            let screenshot = app.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = "TraderLoginFailed"
            attachment.lifetime = .keepAlways
            add(attachment)
            XCTFail("Could not login as Trader - check screenshot")
            return
        }

        // Debug: Show available tabs
        debugPrintTabs()

        // Check Dashboard
        logStep(2, "Viewing Dashboard")
        let dashboardTab = app.tabBars.buttons["Dashboard"]
        if dashboardTab.exists {
            tapElement(dashboardTab, description: "Dashboard Tab")
            sleep(2)

            let screenshot = app.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = "TraderDashboard"
            add(attachment)
        } else {
            print("  ⚠️ Dashboard tab not found")
        }

        // Check Depot tab
        logStep(3, "Viewing Depot")
        let depotTab = app.tabBars.buttons["Depot"]
        if depotTab.exists {
            tapElement(depotTab, description: "Depot Tab")
            sleep(2)

            let screenshot = app.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = "TraderDepot"
            add(attachment)

            print("  📊 Depot view has \(app.staticTexts.count) text elements")
        } else {
            print("  ⚠️ Depot tab not found - may not be trader role")
        }

        // Check Trades tab
        logStep(4, "Viewing Trades")
        let tradesTab = app.tabBars.buttons["Trades"]
        if tradesTab.exists {
            tapElement(tradesTab, description: "Trades Tab")
            sleep(2)

            let screenshot = app.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = "TraderTradesOverview"
            add(attachment)

            // Look for P&L indicators
            let pnlElements = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'Profit' OR label CONTAINS[c] 'Gewinn' OR label CONTAINS[c] 'Verlust' OR label CONTAINS[c] '€'"))
            print("  📊 Found \(pnlElements.count) P&L related elements")
        } else {
            print("  ⚠️ Trades tab not found - may not be trader role")
        }

        // Check Profile
        logStep(5, "Viewing Profile & Notifications")
        let profileTab = app.tabBars.buttons["Profile"]
        if profileTab.exists {
            tapElement(profileTab, description: "Profile Tab")
            sleep(2)

            let screenshot = app.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = "TraderProfile"
            add(attachment)

            // Check for notification badges
            let badgeElements = app.staticTexts.matching(NSPredicate(format: "label MATCHES '[0-9]+'"))
            print("  📊 Found \(badgeElements.count) potential notification badges")
        } else {
            print("  ⚠️ Profile tab not found")
        }

        print("\n✅ Complete Trader Journey Test Completed")
    }

    // MARK: - Combined E2E Test

    /// Comprehensive end-to-end test demonstrating all flows
    @MainActor
    func testCompleteE2EFlow() throws {
        logSection("Complete End-to-End Flow")

        // Launch app
        logStep(0, "Launching app")
        app.launch()
        sleep(2)

        // Take initial screenshot
        let screenshot1 = app.screenshot()
        let attachment1 = XCTAttachment(screenshot: screenshot1)
        attachment1.name = "01_AppLaunched"
        add(attachment1)

        // Print what's visible
        print("  📱 Visible buttons: \(app.buttons.count)")
        print("  📱 Visible text elements: \(app.staticTexts.count)")
        print("  📱 Tab bars: \(app.tabBars.count)")

        // List some button labels for debugging
        let buttonLabels = app.buttons.allElementsBoundByIndex.prefix(10).map { $0.label }
        print("  📱 First 10 button labels: \(buttonLabels)")

        // Try to login
        logStep(1, "Attempting login")

        // First try Trader login
        if loginAsTrader(number: 1) {
            print("  ✅ Logged in as Trader")

            // Navigate through tabs
            let tabs = ["Dashboard", "Depot", "Trades", "Profile"]
            for (index, tabName) in tabs.enumerated() {
                logStep(2 + index, "Navigating to \(tabName)")
                let tab = app.tabBars.buttons[tabName]
                if tab.exists {
                    tapElement(tab, description: "\(tabName) Tab")
                    sleep(1)

                    let screenshot = app.screenshot()
                    let attachment = XCTAttachment(screenshot: screenshot)
                    attachment.name = "Tab_\(tabName)"
                    add(attachment)
                }
            }
        } else if loginAsInvestor(number: 1) {
            print("  ✅ Logged in as Investor")

            // Navigate through tabs
            let tabs = ["Dashboard", "Discover", "Investments", "Profile"]
            for (index, tabName) in tabs.enumerated() {
                logStep(2 + index, "Navigating to \(tabName)")
                let tab = app.tabBars.buttons[tabName]
                if tab.exists {
                    tapElement(tab, description: "\(tabName) Tab")
                    sleep(1)

                    let screenshot = app.screenshot()
                    let attachment = XCTAttachment(screenshot: screenshot)
                    attachment.name = "Tab_\(tabName)"
                    add(attachment)
                }
            }
        } else {
            // Take screenshot of current state
            let screenshot = app.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = "LoginFailed"
            add(attachment)

            XCTFail("Could not login as either Trader or Investor")
        }

        print("\n" + String(repeating: "=", count: 50))
        print("✅ Complete E2E Flow Test Finished")
        print(String(repeating: "=", count: 50))
    }
}
