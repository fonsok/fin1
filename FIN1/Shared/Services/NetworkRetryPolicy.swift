import Foundation

// MARK: - Network Retry Policy

/// Defines retry behavior for network requests with exponential backoff
struct NetworkRetryPolicy {
    /// Maximum number of retry attempts
    static let maxRetries = 3

    /// Base delay in seconds before first retry
    static let baseDelay: TimeInterval = 1.0

    /// Maximum delay in seconds (caps exponential growth)
    static let maxDelay: TimeInterval = 10.0

    /// Calculate delay for a specific retry attempt
    /// - Parameter attempt: The retry attempt number (0-based)
    /// - Returns: Delay in seconds before next retry
    static func delay(for attempt: Int) -> TimeInterval {
        let exponentialDelay = baseDelay * pow(2.0, Double(attempt))
        return min(exponentialDelay, maxDelay)
    }

    /// Determines if a request should be retried based on the error and attempt number
    /// - Parameters:
    ///   - error: The error that occurred
    ///   - attempt: Current retry attempt number (0-based)
    /// - Returns: `true` if request should be retried, `false` otherwise
    static func shouldRetry(error: Error, attempt: Int) -> Bool {
        // Don't retry if max attempts reached
        guard attempt < maxRetries else {
            return false
        }

        // Map error to NetworkError if possible
        let networkError: NetworkError?
        if let error = error as? NetworkError {
            networkError = error
        } else if let error = error as? URLError {
            networkError = mapURLError(error)
        } else {
            // Unknown error - don't retry
            return false
        }

        guard let networkError = networkError else {
            return false
        }

        // Retry logic based on error type
        switch networkError {
        case .noConnection, .timeout:
            // Always retry connection/timeout errors
            return true

        case .serverError(let code):
            // Retry on 5xx server errors (server-side issues)
            // Retry on 429 (Rate Limit) - might be temporary
            // Don't retry on 4xx client errors (except 429)
            return code >= 500 || code == 429

        case .badRequest:
            return false

        case .invalidResponse, .decodingError:
            // Don't retry invalid responses or decoding errors
            // These are likely permanent issues
            return false
        }
    }

    /// Maps URLError to NetworkError
    private static func mapURLError(_ error: URLError) -> NetworkError? {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost, .cannotConnectToHost:
            return .noConnection
        case .timedOut:
            return .timeout
        default:
            return nil
        }
    }
}
