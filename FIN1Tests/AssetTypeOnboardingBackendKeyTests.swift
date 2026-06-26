@testable import FIN1
import XCTest

final class AssetTypeOnboardingBackendKeyTests: XCTestCase {
    func testOnboardingBackendKeyUsesCamelCase() {
        XCTAssertEqual(AssetType.privateAssets.onboardingBackendKey, "privateAssets")
        XCTAssertEqual(AssetType.businessAssets.onboardingBackendKey, "businessAssets")
    }

    func testFromOnboardingBackendKeyAcceptsLegacySnakeCase() {
        XCTAssertEqual(AssetType.fromOnboardingBackendKey("private_assets"), .privateAssets)
        XCTAssertEqual(AssetType.fromOnboardingBackendKey("business_assets"), .businessAssets)
        XCTAssertEqual(AssetType.fromOnboardingBackendKey("privateAssets"), .privateAssets)
    }
}
