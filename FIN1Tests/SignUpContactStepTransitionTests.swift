@testable import FIN1
import XCTest

final class SignUpContactStepTransitionTests: XCTestCase {
    func testEarlyParseSignUpStartsOnAccountCreatedStep() throws {
        let signUpData = SignUpData()
        signUpData.email = "user@example.com"
        signUpData.username = "user1"
        signUpData.password = "Secret1!"
        signUpData.acceptedTerms = true
        signUpData.acceptedPrivacyPolicy = true
        let user = try signUpData.createEarlyAccountUser()
        let body = UserFactory.parseSignUpParameters(from: user)

        XCTAssertEqual(body["onboardingStep"] as? String, SignUpStep.accountCreated.backendKey)
    }

    @MainActor
    func testCreateAccountIfNeededAdvancesWhenAlreadyAuthenticated() async {
        let coordinator = SignUpCoordinator()
        let signUpData = SignUpData()
        coordinator.currentStep = .contact
        coordinator.setUserRole(.investor)

        let userService = MockUserService()
        userService.isAuthenticated = true
        var didCallSignUp = false
        userService.signUpHandler = { _ in
            didCallSignUp = true
        }

        coordinator.configureServices(
            onboardingAPIService: nil,
            userService: userService,
            telemetryService: nil
        )
        coordinator.signUpData = signUpData

        await coordinator.createAccountIfNeeded(with: signUpData)

        XCTAssertEqual(coordinator.currentStep, .accountCreated)
        XCTAssertFalse(didCallSignUp)
    }
}
