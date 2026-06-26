@testable import FIN1
import XCTest

final class SignUpExperienceNoneFollowUpTests: XCTestCase {
    func testNoneTransactionCountDoesNotRequireFollowUpAnswers() {
        let signUpData = SignUpData()
        signUpData.stocksTransactionsCount = .none
        signUpData.etfsTransactionsCount = .none
        signUpData.derivativesTransactionsCount = .none
        signUpData.otherAssets["No"] = true

        XCTAssertTrue(signUpData.isStocksExperienceComplete)
        XCTAssertTrue(signUpData.isEtfsExperienceComplete)
        XCTAssertTrue(signUpData.isDerivativesExperienceComplete)
        XCTAssertTrue(signUpData.isExperienceStepComplete)
    }

    func testNonNoneTransactionCountStillRequiresFollowUpAnswers() {
        let signUpData = SignUpData()
        signUpData.stocksTransactionsCount = .oneToTen
        signUpData.etfsTransactionsCount = .none
        signUpData.derivativesTransactionsCount = .none
        signUpData.otherAssets["No"] = true

        XCTAssertFalse(signUpData.isStocksExperienceComplete)
        XCTAssertFalse(signUpData.isExperienceStepComplete)
    }
}
