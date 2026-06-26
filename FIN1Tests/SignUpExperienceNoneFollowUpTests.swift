@testable import FIN1
import XCTest

final class SignUpExperienceNoneFollowUpTests: XCTestCase {
    func testNoneTransactionCountDoesNotRequireFollowUpAnswers() {
        let signUpData = SignUpData()
        signUpData.stocksTransactionsCount = StocksTransactionCount.none
        signUpData.etfsTransactionsCount = ETFsTransactionCount.none
        signUpData.derivativesTransactionsCount = DerivativesTransactionCount.none
        signUpData.otherAssets = [
            "Real estate": false,
            "Gold, silver": false,
            "No": true
        ]

        XCTAssertTrue(signUpData.isStocksExperienceComplete)
        XCTAssertTrue(signUpData.isEtfsExperienceComplete)
        XCTAssertTrue(signUpData.isDerivativesExperienceComplete)
        XCTAssertTrue(signUpData.isExperienceStepComplete)
    }

    func testNonNoneTransactionCountStillRequiresFollowUpAnswers() {
        let signUpData = SignUpData()
        signUpData.stocksTransactionsCount = .oneToTen
        signUpData.etfsTransactionsCount = ETFsTransactionCount.none
        signUpData.derivativesTransactionsCount = DerivativesTransactionCount.none
        signUpData.otherAssets = [
            "Real estate": false,
            "Gold, silver": false,
            "No": true
        ]

        XCTAssertFalse(signUpData.isStocksExperienceComplete)
        XCTAssertFalse(signUpData.isExperienceStepComplete)
    }
}
