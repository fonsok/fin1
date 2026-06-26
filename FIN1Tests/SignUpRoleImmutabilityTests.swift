@testable import FIN1
import XCTest

final class SignUpRoleImmutabilityTests: XCTestCase {
    func testRestoreSkipsUserRoleFromBlobWhenAccountRoleLocked() throws {
        let signUpData = SignUpData()
        signUpData.userRole = .trader

        let saved = try JSONDecoder().decode(
            SavedOnboardingData.self,
            from: Data(#"{"userRole":"investor"}"#.utf8)
        )

        signUpData.restoreFromSavedData(saved, lockAccountRole: true)

        XCTAssertEqual(signUpData.userRole, .trader)
    }

    func testRestoreAppliesUserRoleFromBlobBeforeAccountCreation() throws {
        let signUpData = SignUpData()
        signUpData.userRole = .investor

        let saved = try JSONDecoder().decode(
            SavedOnboardingData.self,
            from: Data(#"{"userRole":"trader"}"#.utf8)
        )

        signUpData.restoreFromSavedData(saved, lockAccountRole: false)

        XCTAssertEqual(signUpData.userRole, .trader)
    }
}
