//
//  SignUpContactStepUITests.swift
//  FIN1UITests
//
//  Verifies landing → contact → account-created (Step 3) without a second tap
//  after auth transition (single SignUpView via AuthenticationView fullScreenCover).
//

import XCTest

final class SignUpContactStepUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        self.app = XCUIApplication()
        self.app.launchArguments = [
            "--uitesting",
            "--reset-state",
            "--ui-test-signup-skip-network"
        ]
        self.app.terminate()
    }

    override func tearDownWithError() throws {
        self.app?.terminate()
        self.app = nil
    }

    @MainActor
    func testLandingContactOpenAccountAdvancesToStepThree() throws {
        self.app.launch()

        let getStarted = self.app.buttons["SignUpGetStartedButton"]
        XCTAssertTrue(getStarted.waitForExistence(timeout: 15), "Landing Get Started button")
        getStarted.tap()

        let continueButton = self.app.buttons["SignUpContinueButton"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 10), "Sign-up welcome continue button")
        continueButton.tap()

        let openAccount = self.app.buttons["SignUpOpenAccountButton"]
        XCTAssertTrue(openAccount.waitForExistence(timeout: 10), "Contact step Konto anlegen button")

        let termsToggle = self.app.switches["SignUpAcceptTermsToggle"]
        let privacyToggle = self.app.switches["SignUpAcceptPrivacyToggle"]
        XCTAssertTrue(termsToggle.waitForExistence(timeout: 5))
        XCTAssertTrue(privacyToggle.waitForExistence(timeout: 5))
        if termsToggle.value as? String != "1" {
            termsToggle.tap()
        }
        if privacyToggle.value as? String != "1" {
            privacyToggle.tap()
        }

        openAccount.tap()

        let accountCreatedTitle = self.app.staticTexts["SignUpAccountCreatedTitle"]
        XCTAssertTrue(
            accountCreatedTitle.waitForExistence(timeout: 10),
            "Expected account-created step after first Open account tap"
        )

        let stepLabel = self.app.staticTexts["SignUpProgressStepLabel"]
        XCTAssertTrue(stepLabel.waitForExistence(timeout: 5))
        XCTAssertTrue(
            stepLabel.label.contains("Schritt 3 von"),
            "Progress label should show step 3, got: \(stepLabel.label)"
        )
    }
}
