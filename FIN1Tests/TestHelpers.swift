import Foundation
import XCTest
@testable import FIN1

// MARK: - Test Helpers
/// Centralized helper methods for common test operations and reusable setup routines
class TestHelpers {

    // MARK: - User Creation

    static func createTestUser(
        email: String = "test@example.com",
        role: UserRole = .investor,
        mockUserService: MockUserService
    ) async -> User? {
        do {
            try await mockUserService.signIn(email: email, password: "password123")
            return mockUserService.currentUser
        } catch {
            return nil
        }
    }

    static func createInvestorUser(mockUserService: MockUserService) async -> User? {
        return await createTestUser(email: "investor@example.com", role: .investor, mockUserService: mockUserService)
    }

    static func createTraderUser(mockUserService: MockUserService) async -> User? {
        return await createTestUser(email: "trader@example.com", role: .trader, mockUserService: mockUserService)
    }

    // MARK: - Mock Data Creation

    static func createMockTrader() -> MockTrader {
        return MockTrader(
            name: "Test Trader",
            username: "test_trader",
            specialization: "Technology",
            experienceYears: 5,
            isVerified: true,
            performance: 15.5,
            totalTrades: 100,
            winRate: 0.75,
            averageReturn: 12.0,
            totalReturn: 1200.0,
            riskLevel: .medium,
            recentTrades: [],
            lastNTrades: 10,
            successfulTradesInLastN: 8,
            averageReturnLastNTrades: 150.0,
            consecutiveWinningTrades: 5,
            maxDrawdown: 5.0,
            sharpeRatio: 1.8
        )
    }

    // MARK: - Async Test Helpers

    /// Creates and configures an XCTestExpectation for async operations
    /// - Parameters:
    ///   - description: Description of what is being awaited
    ///   - timeout: Maximum time to wait (default: 1.0 seconds)
    /// - Returns: Configured expectation
    static func createExpectation(description: String, timeout: TimeInterval = 1.0) -> XCTestExpectation {
        return XCTestExpectation(description: description)
    }

    /// Waits for an expectation to be fulfilled
    /// - Parameters:
    ///   - expectation: The expectation to wait for
    ///   - timeout: Maximum time to wait (default: 1.0 seconds)
    static func waitForExpectation(_ expectation: XCTestExpectation, timeout: TimeInterval = 1.0) async {
        await fulfillment(of: [expectation], timeout: timeout)
    }

    /// Creates expectation and waits for it - convenience method for simple async tests
    /// - Parameters:
    ///   - description: Description of what is being awaited
    ///   - timeout: Maximum time to wait (default: 1.0 seconds)
    ///   - operation: The async operation that should fulfill the expectation
    static func waitForAsync(
        description: String = "Async operation",
        timeout: TimeInterval = 1.0,
        operation: @escaping (XCTestExpectation) -> Void
    ) async {
        let expectation = XCTestExpectation(description: description)
        operation(expectation)
        await fulfillment(of: [expectation], timeout: timeout)
    }

    // MARK: - Repository Test Helpers

    /// Creates an in-memory UserDefaults instance for repository testing
    /// Each call returns a unique, isolated UserDefaults suite
    /// - Returns: Isolated in-memory UserDefaults instance
    static func createInMemoryUserDefaults() -> UserDefaults {
        guard let userDefaults = UserDefaults(suiteName: UUID().uuidString) else {
            fatalError("Failed to create in-memory UserDefaults - this should never happen")
        }
        return userDefaults
    }

    // MARK: - Mock Configuration Helpers

    /// Configures a mock service handler to return a value
    /// - Parameters:
    ///   - handler: The handler property to set
    ///   - value: The value to return
    ///   - expectation: Optional expectation to fulfill
    static func configureMockHandler<T>(
        handler: inout ((T) async throws -> T)?,
        value: T,
        expectation: XCTestExpectation? = nil
    ) {
        handler = { _ in
            expectation?.fulfill()
            return value
        }
    }

    /// Configures a mock service handler to throw an error
    /// - Parameters:
    ///   - handler: The handler property to set
    ///   - error: The error to throw
    ///   - expectation: Optional expectation to fulfill
    static func configureMockErrorHandler<T>(
        handler: inout (() async throws -> T)?,
        error: Error,
        expectation: XCTestExpectation? = nil
    ) {
        handler = {
            expectation?.fulfill()
            throw error
        }
    }

    // MARK: - Deprecated (Use XCTestExpectation instead)

    /// ⚠️ DEPRECATED: Use `XCTestExpectation` instead
    /// This method uses `Task.sleep` which is fragile and unreliable
    @available(*, deprecated, message: "Use XCTestExpectation with fulfillment instead")
    static func waitForAsync(seconds: Double = 0.2) async {
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
}

// MARK: - XCTestCase Compatibility Helpers
extension XCTestCase {
    /// Backport helper for async tests on toolchains that don't expose XCTest's native `fulfillment` API.
    func fulfillment(
        of expectations: [XCTestExpectation],
        timeout: TimeInterval,
        enforceOrder: Bool = false
    ) async {
        if responds(to: #selector(XCTestCase.wait(for:timeout:enforceOrder:))) {
            wait(for: expectations, timeout: timeout, enforceOrder: enforceOrder)
        } else {
            wait(for: expectations, timeout: timeout)
        }
    }
}
