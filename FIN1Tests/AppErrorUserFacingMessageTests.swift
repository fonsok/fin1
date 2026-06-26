@testable import FIN1
import XCTest

final class AppErrorUserFacingMessageTests: XCTestCase {

    func testUserFacingBuyOrderMessage_validationReturnsRawGermanText() {
        let error = AppError.validationError("Ungültige Stückzahl.")
        XCTAssertEqual(error.userFacingBuyOrderMessage, "Ungültige Stückzahl.")
        XCTAssertFalse(error.userFacingBuyOrderMessage.contains("Validation Error:"))
    }

    func testUserFacingBuyOrderMessage_networkOmitsEnglishPrefix() {
        let error = AppError.networkError(.noConnection)
        XCTAssertEqual(
            error.userFacingBuyOrderMessage,
            error.userFacingInvestmentMessage
        )
        XCTAssertFalse(error.userFacingBuyOrderMessage.contains("Network Error:"))
    }

    func testUserFacingBuyOrderMessage_pairedBuyConflictUsesGermanCopy() {
        let message =
            "Der Kauf konnte wegen eines Server-Konflikts nicht abgeschlossen werden. "
                + "Bitte prüfen Sie zuerst Ihr Depot — der Auftrag könnte bereits eingegangen sein."
        let error = AppError.validationError(message)
        XCTAssertEqual(error.userFacingBuyOrderMessage, message)
    }
}
