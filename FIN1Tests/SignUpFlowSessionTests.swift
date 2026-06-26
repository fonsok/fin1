@testable import FIN1
import XCTest

@MainActor
final class SignUpFlowSessionTests: XCTestCase {
    override func tearDown() {
        SignUpFlowSession.reset()
        super.tearDown()
    }

    func testBeginAndEndFromLanding() {
        XCTAssertFalse(SignUpFlowSession.isPresentingFromLanding)
        XCTAssertFalse(SignUpFlowSession.userLeftOnboarding)

        SignUpFlowSession.beginFromLanding()
        XCTAssertTrue(SignUpFlowSession.isPresentingFromLanding)
        XCTAssertFalse(SignUpFlowSession.userLeftOnboarding)

        SignUpFlowSession.end()
        XCTAssertFalse(SignUpFlowSession.isPresentingFromLanding)
    }

    func testMarkUserLeftOnboardingBlocksUntilReset() {
        SignUpFlowSession.markUserLeftOnboarding()
        XCTAssertTrue(SignUpFlowSession.userLeftOnboarding)

        SignUpFlowSession.reset()
        XCTAssertFalse(SignUpFlowSession.userLeftOnboarding)
    }
}
