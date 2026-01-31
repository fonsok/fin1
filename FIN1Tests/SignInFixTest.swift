import XCTest
@testable import FIN1

final class SignInFixTest: XCTestCase {
    var userService: UserService!

    override func setUp() {
        super.setUp()
        userService = UserService.shared
    }

    override func tearDown() {
        userService = nil
        super.tearDown()
    }

    func testTraderSignIn() async {
        // Given
        let email = "trader1@test.com"
        let password = "password123"

        // When
        do {
            try await userService.signIn(email: email, password: password)

            // Then
            XCTAssertTrue(userService.isAuthenticated)
            XCTAssertNotNil(userService.currentUser)
            XCTAssertEqual(userService.currentUser?.role, .trader)
            XCTAssertEqual(userService.currentUser?.email, email)
        } catch {
            XCTFail("Trader sign-in should succeed: \(error)")
        }
    }

    func testInvestorSignIn() async {
        // Given
        let email = "investor1@test.com"
        let password = "password123"

        // When
        do {
            try await userService.signIn(email: email, password: password)

            // Then
            XCTAssertTrue(userService.isAuthenticated)
            XCTAssertNotNil(userService.currentUser)
            XCTAssertEqual(userService.currentUser?.role, .investor)
            XCTAssertEqual(userService.currentUser?.email, email)
        } catch {
            XCTFail("Investor sign-in should succeed: \(error)")
        }
    }

    func testTrader2SignIn() async {
        // Given
        let email = "trader2@test.com"
        let password = "password123"

        // When
        do {
            try await userService.signIn(email: email, password: password)

            // Then
            XCTAssertTrue(userService.isAuthenticated)
            XCTAssertNotNil(userService.currentUser)
            XCTAssertEqual(userService.currentUser?.role, .trader)
            XCTAssertEqual(userService.currentUser?.email, email)
        } catch {
            XCTFail("Trader2 sign-in should succeed: \(error)")
        }
    }

    func testInvestor2SignIn() async {
        // Given
        let email = "investor2@test.com"
        let password = "password123"

        // When
        do {
            try await userService.signIn(email: email, password: password)

            // Then
            XCTAssertTrue(userService.isAuthenticated)
            XCTAssertNotNil(userService.currentUser)
            XCTAssertEqual(userService.currentUser?.role, .investor)
            XCTAssertEqual(userService.currentUser?.email, email)
        } catch {
            XCTFail("Investor2 sign-in should succeed: \(error)")
        }
    }
}
