import Foundation

// MARK: - Circuit Breaker Result

/// Wraps a result so `CircuitBreaker.execute` can cross the actor boundary when `T` is not `Sendable`.
struct CircuitBreakerResult<T>: @unchecked Sendable {
    let value: T
}

// MARK: - Circuit Breaker

/// Circuit Breaker pattern implementation to prevent cascading failures
/// When a service is failing repeatedly, the circuit opens to prevent further requests
actor CircuitBreaker {
    /// Circuit breaker state
    enum State {
        case closed      // Normal operation - requests pass through
        case open        // Failing - requests are rejected immediately
        case halfOpen    // Testing if service recovered - one request allowed
    }

    // MARK: - Properties

    private var state: State = .closed
    private var failureCount = 0
    private var lastFailureTime: Date?
    private var successCount = 0

    // Configuration
    private let failureThreshold: Int
    private let timeout: TimeInterval
    private let halfOpenMaxAttempts: Int

    // MARK: - Initialization

    /// Creates a circuit breaker with configurable thresholds
    /// - Parameters:
    ///   - failureThreshold: Number of failures before opening circuit (default: 5)
    ///   - timeout: Time in seconds before attempting half-open state (default: 60)
    ///   - halfOpenMaxAttempts: Number of successful requests needed to close circuit (default: 2)
    init(
        failureThreshold: Int = 5,
        timeout: TimeInterval = 60.0,
        halfOpenMaxAttempts: Int = 2
    ) {
        self.failureThreshold = failureThreshold
        self.timeout = timeout
        self.halfOpenMaxAttempts = halfOpenMaxAttempts
    }

    // MARK: - Public Methods

    /// Executes an operation with circuit breaker protection
    /// - Parameter operation: The operation to execute
    /// - Returns: The result of the operation
    /// - Throws: ServiceError.serviceUnavailable if circuit is open
    func execute<T>(_ operation: () async throws -> T) async throws -> CircuitBreakerResult<T> {
        // Check circuit state before executing
        try self.checkCircuitState()

        do {
            let result = try await operation()
            self.recordSuccess()
            return CircuitBreakerResult(value: result)
        } catch {
            // Only count infrastructure failures (network, server 500+) toward circuit breaker
            // Client errors (400, 404, decoding) mean the server IS available - don't trip the circuit
            if Self.isInfrastructureError(error) {
                self.recordFailure()
            } else {
                // Server responded (even with 400) - it's still available
                self.recordSuccess()
            }
            throw error
        }
    }

    /// Determines if an error indicates actual infrastructure failure vs client/business logic error
    private static func isInfrastructureError(_ error: Error) -> Bool {
        if let networkError = error as? NetworkError {
            switch networkError {
            case .noConnection, .timeout:
                return true
            case .serverError(let code) where code >= 500:
                return true
            case .badRequest, .serverError, .invalidResponse, .decodingError:
                // Client / validation errors — server is reachable
                return false
            }
        }

        // URL errors (connection refused, DNS failure, etc.) are infrastructure errors
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .timedOut, .cannotConnectToHost,
                 .cannotFindHost, .networkConnectionLost, .dnsLookupFailed:
                return true
            default:
                return false
            }
        }

        // ServiceError.serviceUnavailable from nested circuit breakers
        if let serviceError = error as? ServiceError, serviceError == .serviceUnavailable {
            return true
        }

        // Unknown errors - assume infrastructure failure to be safe
        return true
    }

    /// Manually reset the circuit breaker (useful for testing or manual recovery)
    func reset() {
        self.state = .closed
        self.failureCount = 0
        self.successCount = 0
        self.lastFailureTime = nil
    }

    /// Get current circuit breaker state (for monitoring/debugging)
    var currentState: State {
        self.state
    }

    /// Get current failure count (for monitoring/debugging)
    var currentFailureCount: Int {
        self.failureCount
    }

    // MARK: - Private Methods

    /// Checks if circuit should be opened/closed based on current state
    private func checkCircuitState() throws {
        switch self.state {
        case .closed:
            // Normal operation - allow request
            return

        case .open:
            // Circuit is open - check if timeout has passed
            guard let lastFailure = lastFailureTime else {
                // No failure time recorded - allow request to test
                self.state = .halfOpen
                return
            }

            let timeSinceFailure = Date().timeIntervalSince(lastFailure)
            if timeSinceFailure > self.timeout {
                // Timeout passed - move to half-open to test recovery
                self.state = .halfOpen
                self.successCount = 0
                return
            }

            // Still in timeout period - reject request
            throw ServiceError.serviceUnavailable

        case .halfOpen:
            // Testing recovery - allow request
            return
        }
    }

    /// Records a successful operation
    private func recordSuccess() {
        switch self.state {
        case .closed:
            // Reset failure count on success
            self.failureCount = 0

        case .halfOpen:
            // Increment success count
            self.successCount += 1

            // If enough successes, close the circuit
            if self.successCount >= self.halfOpenMaxAttempts {
                self.state = .closed
                self.failureCount = 0
                self.successCount = 0
                self.lastFailureTime = nil
            }

        case .open:
            // Should not happen - circuit is open
            break
        }
    }

    /// Records a failed operation
    private func recordFailure() {
        self.failureCount += 1
        self.lastFailureTime = Date()

        switch self.state {
        case .closed:
            // Check if threshold reached
            if self.failureCount >= self.failureThreshold {
                self.state = .open
            }

        case .halfOpen:
            // Failure during half-open - immediately open circuit
            self.state = .open
            self.successCount = 0

        case .open:
            // Already open - just update failure time
            break
        }
    }
}
