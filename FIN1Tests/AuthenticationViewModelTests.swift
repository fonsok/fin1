import XCTest
@testable import FIN1

final class AuthenticationViewModelTests: XCTestCase {
    var viewModel: AuthenticationViewModel!
    var mockUserService: MockUserService!
    var mockTelemetryService: MockTelemetryService!

    override func setUp() {
        super.setUp()
        mockUserService = MockUserService()
        mockTelemetryService = MockTelemetryService()
        viewModel = AuthenticationViewModel(userService: mockUserService)
    }

    override func tearDown() {
        viewModel = nil
        mockUserService = nil
        mockTelemetryService = nil
        super.tearDown()
    }

    // MARK: - Initial State Tests

    func testInitialState() {
        XCTAssertFalse(viewModel.isAuthenticated)
        XCTAssertNil(viewModel.currentUser)
        XCTAssertFalse(viewModel.showError)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isLoading)
    }

    // MARK: - Sign In Tests

    func testSignInSuccess() async {
        // Given
        let expectation = TestHelpers.createExpectation(description: "Sign in success")
        viewModel.email = "test@example.com"
        viewModel.password = "password123"

        // Configure mock to fulfill expectation when signIn completes
        mockUserService.signInHandler = { _, _ in
            expectation.fulfill()
        }

        // When
        viewModel.signIn(email: viewModel.email, password: viewModel.password)
        await TestHelpers.waitForExpectation(expectation)

        // Then
        XCTAssertTrue(viewModel.isAuthenticated)
        XCTAssertNotNil(viewModel.currentUser)
        XCTAssertEqual(viewModel.currentUser?.email, "test@example.com")
    }

    func testSignInWithError() async {
        // Given
        let expectedError = AppError.authenticationError(.invalidCredentials)
        let expectation = XCTestExpectation(description: "Sign in error")
        mockUserService.signInHandler = { _, _ in
            expectation.fulfill()
            throw expectedError
        }
        viewModel.email = "invalid@example.com"
        viewModel.password = "wrongpassword"

        // When
        viewModel.signIn(email: viewModel.email, password: viewModel.password)
        await fulfillment(of: [expectation], timeout: 1.0)

        // Then
        XCTAssertFalse(viewModel.isAuthenticated)
        XCTAssertNil(viewModel.currentUser)
        XCTAssertTrue(viewModel.showError)
        XCTAssertNotNil(viewModel.errorMessage)
    }

    // MARK: - Sign Up Tests

    func testSignUpSuccess() async {
        // Given
        let expectation = TestHelpers.createExpectation(description: "Sign up success")
        let signUpData = SignUpData()
        signUpData.email = "newuser@example.com"
        signUpData.userRole = .investor

        // Configure mock to fulfill expectation when signUp completes
        mockUserService.signUpHandler = { _ in
            expectation.fulfill()
        }

        // When
        viewModel.signUp(userData: signUpData)
        await TestHelpers.waitForExpectation(expectation)

        // Then
        XCTAssertTrue(viewModel.isAuthenticated)
        XCTAssertNotNil(viewModel.currentUser)
        XCTAssertEqual(viewModel.currentUser?.email, "newuser@example.com")
    }

    func testSignUpWithError() async {
        // Given
        let expectedError = AppError.authenticationError(.emailAlreadyExists)
        let expectation = XCTestExpectation(description: "Sign up error")
        mockUserService.signUpHandler = { _ in
            expectation.fulfill()
            throw expectedError
        }

        let signUpData = SignUpData()
        signUpData.email = "test@example.com"
        signUpData.userRole = .investor

        // When
        viewModel.signUp(userData: signUpData)
        await fulfillment(of: [expectation], timeout: 1.0)

        // Then
        XCTAssertFalse(viewModel.isAuthenticated)
        XCTAssertNil(viewModel.currentUser)
        XCTAssertTrue(viewModel.showError)
        XCTAssertNotNil(viewModel.errorMessage)
    }

    // MARK: - Sign Out Tests

    func testSignOut() async {
        // Given
        let signInExpectation = TestHelpers.createExpectation(description: "Sign in")
        mockUserService.signInHandler = { _, _ in
            signInExpectation.fulfill()
        }
        try? await mockUserService.signIn(email: "test@example.com", password: "password123")
        await TestHelpers.waitForExpectation(signInExpectation)
        XCTAssertTrue(viewModel.isAuthenticated)

        // When
        viewModel.signOut()
        // Sign out is synchronous, no async wait needed

        // Then
        XCTAssertFalse(viewModel.isAuthenticated)
        XCTAssertNil(viewModel.currentUser)
    }

    // MARK: - Error Handling Tests

    func testShowError() {
        // Given
        let error = AppError.networkError(.noConnection)

        // When
        viewModel.showError(error)

        // Then
        XCTAssertTrue(viewModel.showError)
        XCTAssertEqual(viewModel.errorMessage, error.localizedDescription)
    }

    func testClearError() {
        // Given
        viewModel.showError = true
        viewModel.errorMessage = "Test error"

        // When
        viewModel.clearError()

        // Then
        XCTAssertFalse(viewModel.showError)
        XCTAssertNil(viewModel.errorMessage)
    }

    // MARK: - User Properties Tests

    func testUserDisplayName() async {
        // Given
        let expectation = TestHelpers.createExpectation(description: "Sign in for display name")
        mockUserService.signInHandler = { _, _ in
            expectation.fulfill()
        }
        try? await mockUserService.signIn(email: "test@example.com", password: "password123")
        await TestHelpers.waitForExpectation(expectation)

        // Then
        XCTAssertEqual(viewModel.userDisplayName, "Test User")
    }

    func testUserRole() async {
        // Given
        let expectation = TestHelpers.createExpectation(description: "Sign in for role")
        mockUserService.signInHandler = { _, _ in
            expectation.fulfill()
        }
        try? await mockUserService.signIn(email: "test@example.com", password: "password123")
        await TestHelpers.waitForExpectation(expectation)

        // Then
        XCTAssertEqual(viewModel.userRole, .investor)
    }

    func testIsInvestor() async {
        // Given
        let expectation = TestHelpers.createExpectation(description: "Sign in as investor")
        mockUserService.signInHandler = { _, _ in
            expectation.fulfill()
        }
        try? await mockUserService.signIn(email: "test@example.com", password: "password123")
        await TestHelpers.waitForExpectation(expectation)

        // Then
        XCTAssertTrue(viewModel.isInvestor)
        XCTAssertFalse(viewModel.isTrader)
    }

    func testIsTrader() async {
        // Given
        let expectation = TestHelpers.createExpectation(description: "Sign in as trader")
        mockUserService.signInHandler = { _, _ in
            expectation.fulfill()
        }
        try? await mockUserService.signIn(email: "trader@example.com", password: "password123")
        await TestHelpers.waitForExpectation(expectation)

        // Then
        XCTAssertTrue(viewModel.isTrader)
        XCTAssertFalse(viewModel.isInvestor)
    }
}
