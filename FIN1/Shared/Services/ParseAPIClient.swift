import Foundation

// MARK: - Parse API Client Implementation

/// HTTP client for Parse Server REST API
final class ParseAPIClient: ParseAPIClientProtocol, @unchecked Sendable {

    /// Bridges non-`Sendable` operation closures into the `CircuitBreaker` actor.
    private final class UncheckedAsyncOperationBox<T>: @unchecked Sendable {
        let run: () async throws -> T
        init(_ run: @escaping () async throws -> T) { self.run = run }
    }

    // MARK: - Properties (internal for extensions)

    let baseURL: String
    let applicationId: String
    let sessionTokenProvider: (() -> String?)?
    let session: URLSession
    let circuitBreaker: CircuitBreaker
    let requestDeduplicator = RequestDeduplicator()
    var offlineQueue: OfflineOperationQueue?
    var conflictResolver: ConflictResolutionServiceProtocol?
    var networkLogger: NetworkLogger?

    /// Returns the current session token (dynamic lookup via provider).
    /// Only real Parse tokens (r: prefix) are forwarded. Simulated fallback
    /// tokens (sim:) are stripped so the server doesn't reject them with 209.
    var sessionToken: String? {
        guard let token = sessionTokenProvider?(), token.hasPrefix("r:") else {
            return nil
        }
        return token
    }

    // MARK: - Initialization

    /// Creates a ParseAPIClient with a dynamic session token provider
    /// - Parameters:
    ///   - baseURL: Parse Server base URL
    ///   - applicationId: Parse Application ID
    ///   - sessionTokenProvider: Closure that returns the current session token (called on each request)
    ///   - circuitBreaker: Optional circuit breaker instance (creates default if nil)
    ///   - offlineQueue: Optional offline operation queue for offline support
    init(
        baseURL: String,
        applicationId: String,
        sessionTokenProvider: (() -> String?)? = nil,
        circuitBreaker: CircuitBreaker? = nil,
        offlineQueue: OfflineOperationQueue? = nil
    ) {
        self.baseURL = baseURL
        self.applicationId = applicationId
        self.sessionTokenProvider = sessionTokenProvider
        self.circuitBreaker = circuitBreaker ?? CircuitBreaker()
        self.offlineQueue = offlineQueue

        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: configuration)
    }

    /// Configure offline queue for offline operation support
    func configure(offlineQueue: OfflineOperationQueue) {
        self.offlineQueue = offlineQueue
        Task { @MainActor in
            offlineQueue.configure(parseAPIClient: self)
        }
    }

    /// Configure conflict resolution service
    func configure(conflictResolver: ConflictResolutionServiceProtocol) {
        self.conflictResolver = conflictResolver
    }

    /// Configure network logger for request logging
    func configure(networkLogger: NetworkLogger) {
        self.networkLogger = networkLogger
    }

    /// Resets the circuit breaker to closed state (used after health check recovery)
    func resetCircuitBreaker() async {
        await circuitBreaker.reset()
        #if DEBUG
        print("🔄 ParseAPIClient: Circuit breaker reset to closed state")
        #endif
    }

    /// Legacy initializer for backward compatibility
    convenience init(
        baseURL: String,
        applicationId: String,
        sessionToken: String?
    ) {
        self.init(
            baseURL: baseURL,
            applicationId: applicationId,
            sessionTokenProvider: sessionToken != nil ? { sessionToken } : nil
        )
    }

    // MARK: - Retry Logic & Circuit Breaker

    /// Executes a network operation with circuit breaker protection and automatic retry logic
    func executeWithRetry<T>(_ operation: @escaping () async throws -> T) async throws -> T {
        let box = UncheckedAsyncOperationBox {
            try await self.executeRetryLogic(operation: operation)
        }
        return try await circuitBreaker.execute {
            try await box.run()
        }.value
    }

    /// Executes retry logic with exponential backoff
    func executeRetryLogic<T>(operation: @escaping () async throws -> T) async throws -> T {
        var lastError: Error?

        for attempt in 0...NetworkRetryPolicy.maxRetries {
            do {
                return try await operation()
            } catch {
                lastError = error

                // Check if we should retry this error
                guard NetworkRetryPolicy.shouldRetry(error: error, attempt: attempt) else {
                    // Don't retry - throw the error immediately
                    throw error
                }

                // Calculate delay before retry
                let delay = NetworkRetryPolicy.delay(for: attempt)

                // Log retry attempt (only in debug builds)
                #if DEBUG
                print("⚠️ ParseAPIClient: Retry attempt \(attempt + 1)/\(NetworkRetryPolicy.maxRetries + 1) after \(String(format: "%.2f", delay))s - Error: \(error.localizedDescription)")
                #endif

                // Wait before retrying
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

                // Continue to next retry attempt
                continue
            }
        }

        // All retries exhausted - throw the last error
        throw lastError ?? NetworkError.timeout
    }

    // MARK: - Private Methods

    /// Creates a deduplication key from request parameters
    func createDeduplicationKey(
        operation: String,
        className: String,
        query: [String: Any]? = nil,
        include: [String]? = nil,
        orderBy: String? = nil,
        limit: Int? = nil,
        objectId: String? = nil
    ) -> String {
        var keyComponents: [String] = [operation, className]

        if let objectId = objectId {
            keyComponents.append(objectId)
        }

        if let query = query, let queryData = try? JSONSerialization.data(withJSONObject: query),
           let queryString = String(data: queryData, encoding: .utf8) {
            keyComponents.append("query:\(queryString)")
        }

        if let include = include, !include.isEmpty {
            keyComponents.append("include:\(include.sorted().joined(separator: ","))")
        }

        if let orderBy = orderBy {
            keyComponents.append("orderBy:\(orderBy)")
        }

        if let limit = limit {
            keyComponents.append("limit:\(limit)")
        }

        return keyComponents.joined(separator: "|")
    }

    func addHeaders(to request: inout URLRequest) {
        request.setValue(applicationId, forHTTPHeaderField: "X-Parse-Application-Id")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let sessionToken = sessionToken {
            request.setValue(sessionToken, forHTTPHeaderField: "X-Parse-Session-Token")
        }
    }

    // MARK: - Parse Date Encoding

    /// Custom date encoding strategy that outputs Parse Server Date format.
    static let parseDateEncodingStrategy: JSONEncoder.DateEncodingStrategy = .custom { date, encoder in
        var container = encoder.container(keyedBy: ParseDateCodingKeys.self)
        try container.encode("Date", forKey: .type)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        try container.encode(formatter.string(from: date), forKey: .iso)
    }

    /// Coding keys for Parse Server Date format
    enum ParseDateCodingKeys: String, CodingKey {
        case type = "__type"
        case iso
    }

    /// Parse REST error JSON: `{ "code": 142, "error": "…" }`.
    static func parseErrorMessageFromResponseBody(_ data: Data) -> String? {
        struct ParseRESTError: Decodable {
            let code: Int?
            let error: String?
        }
        guard !data.isEmpty,
              let body = try? JSONDecoder().decode(ParseRESTError.self, from: data),
              let message = body.error?.trimmingCharacters(in: .whitespacesAndNewlines),
              !message.isEmpty else {
            return nil
        }
        return message
    }

    func validateResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            return
        case 400:
            throw NetworkError.invalidResponse
        case 401:
            throw NetworkError.serverError(401)
        case 404:
            throw NetworkError.invalidResponse
        case 409:
            throw NetworkError.serverError(409)
        case 429:
            throw NetworkError.serverError(429)
        case 500...599:
            throw NetworkError.serverError(httpResponse.statusCode)
        default:
            throw NetworkError.serverError(httpResponse.statusCode)
        }
    }

    /// JSONDecoder configured for Parse Server date format (for use in extensions).
    static func makeDateDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: dateString) { return date }
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: dateString) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date format: \(dateString)")
        }
        return decoder
    }
}

extension ParseAPIClient: SessionStateProviding {
    var hasAuthenticatedSession: Bool {
        sessionToken != nil
    }
}

