import Foundation

// MARK: - Request Deduplicator

/// Boxes an arbitrary successful result so pending tasks stay `Sendable` under Swift 6.
private struct AnySendableResult: @unchecked Sendable {
    let value: Any
}

/// Wraps a deduplicated result so it can cross `RequestDeduplicator`'s actor boundary when `T` is not `Sendable`.
struct RequestDeduplicationResult<T>: @unchecked Sendable {
    let value: T
}

/// Prevents duplicate concurrent requests by caching pending operations
/// When multiple components request the same data simultaneously, only one request is executed
actor RequestDeduplicator {
    private var pendingRequests: [String: Task<AnySendableResult, Error>] = [:]

    /// Executes an operation, deduplicating concurrent requests with the same key
    /// - Parameters:
    ///   - key: Unique identifier for the request (e.g., "fetchInvoices:userId123")
    ///   - operation: The async operation to execute
    /// - Returns: The result of the operation
    /// - Throws: The error from the operation
    /// `T` is stored as `Any` inside `AnySendableResult`; callers that capture non-Sendable state must use a `@Sendable` closure via an `@unchecked Sendable` box (see `ParseAPIClient+Fetch`).
    func execute<T>(
        key: String,
        operation: @Sendable @escaping () async throws -> T
    ) async throws -> RequestDeduplicationResult<T> {
        // Check if request is already pending
        if let existingTask = pendingRequests[key] {
            // Wait for existing task to complete
            do {
                let boxed = try await existingTask.value
                let result = boxed.value
                // Cast result to expected type
                guard let typedResult = result as? T else {
                    throw RequestDeduplicationError.typeMismatch
                }
                return RequestDeduplicationResult(value: typedResult)
            } catch {
                // If existing task failed, remove it and retry
                self.pendingRequests.removeValue(forKey: key)
                throw error
            }
        }

        // Create new task
        let task = Task<AnySendableResult, Error> {
            defer {
                Task {
                    await self.removeRequest(key: key)
                }
            }
            let value = try await operation()
            return AnySendableResult(value: value)
        }

        self.pendingRequests[key] = task

        do {
            let boxed = try await task.value
            let result = boxed.value
            guard let typedResult = result as? T else {
                throw RequestDeduplicationError.typeMismatch
            }
            return RequestDeduplicationResult(value: typedResult)
        } catch {
            self.pendingRequests.removeValue(forKey: key)
            throw error
        }
    }

    /// Removes a completed request from the pending requests dictionary
    private func removeRequest(key: String) async {
        self.pendingRequests.removeValue(forKey: key)
    }

    /// Cancels all pending requests (useful for cleanup)
    func cancelAll() {
        for (_, task) in self.pendingRequests {
            task.cancel()
        }
        self.pendingRequests.removeAll()
    }

    /// Returns the number of pending requests
    var pendingCount: Int {
        self.pendingRequests.count
    }
}

// MARK: - Request Deduplication Error

enum RequestDeduplicationError: Error {
    case typeMismatch

    var localizedDescription: String {
        switch self {
        case .typeMismatch:
            return "Request deduplication type mismatch"
        }
    }
}
