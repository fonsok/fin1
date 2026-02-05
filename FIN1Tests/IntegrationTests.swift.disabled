import XCTest
@testable import FIN1

final class IntegrationTests: XCTestCase {
    var mockUserService: MockUserService!
    var mockInvestmentService: MockInvestmentService!
    var mockTelemetryService: MockTelemetryService!

    override func setUp() {
        super.setUp()
        mockUserService = MockUserService()
        mockInvestmentService = MockInvestmentService()
        mockTelemetryService = MockTelemetryService()
    }

    override func tearDown() {
        mockUserService = nil
        mockInvestmentService = nil
        mockTelemetryService = nil
        super.tearDown()
    }

    // MARK: - Authentication Flow Tests

    func testSignInFlow() async {
        // Given
        let email = "test@example.com"
        let password = "password123"

        // When
        do {
            try await mockUserService.signIn(email: email, password: password)
        } catch {
            XCTFail("Sign in should not fail: \(error)")
        }

        // Then
        XCTAssertTrue(mockUserService.isAuthenticated)
        XCTAssertNotNil(mockUserService.currentUser)
        XCTAssertEqual(mockUserService.currentUser?.email, email)
    }

    func testSignOutFlow() async {
        // Given
        try? await mockUserService.signIn(email: "test@example.com", password: "password123")
        XCTAssertTrue(mockUserService.isAuthenticated)

        // When
        await mockUserService.signOut()

        // Then
        XCTAssertFalse(mockUserService.isAuthenticated)
        XCTAssertNil(mockUserService.currentUser)
    }

    // MARK: - Investment Flow Tests

    func testInvestmentCreationFlow() async {
        // Given
        try? await mockUserService.signIn(email: "investor@example.com", password: "password123")
        let trader = TestHelpers.createMockTrader()
        let amountPerPool = 1000.0
        let numberOfPools = 2
        let specialization = "Technology"
        let poolSelection = PoolSelectionStrategy.multiplePools

        // When
        do {
            try await mockInvestmentService.createInvestment(
                investor: mockUserService.currentUser ?? MockUser(),
                trader: trader,
                amountPerPool: amountPerPool,
                numberOfPools: numberOfPools,
                specialization: specialization,
                poolSelection: poolSelection
            )
        } catch {
            XCTFail("Investment creation should not fail: \(error)")
        }

        // Then
        XCTAssertEqual(mockInvestmentService.investments.count, 1)
        guard let investment = mockInvestmentService.investments.first,
              let currentUser = mockUserService.currentUser else {
            XCTFail("Expected investment and current user")
            return
        }
        XCTAssertEqual(investment.investorId, currentUser.id)
        XCTAssertEqual(investment.traderId, trader.id.uuidString)
        XCTAssertEqual(investment.amount, amountPerPool * Double(numberOfPools))
        XCTAssertEqual(investment.numberOfPools, numberOfPools)
        XCTAssertEqual(investment.specialization, specialization)
        XCTAssertEqual(investment.status, InvestmentStatus.active)
    }

    // MARK: - Error Handling Tests

    func testErrorHandlingFlow() async {
        // Given
        let expectedError = AppError.networkError(.noConnection)
        mockUserService.signInHandler = { _, _ in
            throw expectedError
        }

        // When
        do {
            try await mockUserService.signIn(email: "test@example.com", password: "password123")
            XCTFail("Sign in should have failed")
        } catch {
            // Then
            XCTAssertTrue(error is AppError)
            guard let appError = error as? AppError else {
                XCTFail("Expected AppError")
                return
            }
            XCTAssertEqual(appError, expectedError)
        }
    }

    // MARK: - Telemetry Tests

    func testTelemetryTracking() async {
        // Given
        let error = AppError.validationError("Test error")
        let context = ErrorContext(
            screen: "TestScreen",
            action: "testAction",
            userId: "testUser",
            userRole: "investor"
        )

        // When
        mockTelemetryService.trackAppError(error, context: context)

        // Then
        XCTAssertEqual(mockTelemetryService.trackedAppErrors.count, 1)
        XCTAssertEqual(mockTelemetryService.trackedAppErrors.first?.error, error)
        XCTAssertEqual(mockTelemetryService.trackedAppErrors.first?.context?.screen, "TestScreen")
    }

    // MARK: - Service Integration Tests

    func testServiceLifecycle() async {
        // Given
        // Test individual service lifecycle methods

        // When
        mockUserService.start()
        mockInvestmentService.start()
        mockTelemetryService.start()

        // Then
        // All services should be started without errors
        XCTAssertTrue(true) // Basic test that services can be started

        // When
        mockUserService.stop()
        mockInvestmentService.stop()
        mockTelemetryService.stop()

        // Then
        // All services should be stopped without errors
        XCTAssertTrue(true) // Basic test that services can be stopped
    }
}
