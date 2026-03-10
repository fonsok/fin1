import Foundation

// MARK: - Request Deduplicator

/// Prevents duplicate concurrent requests by caching pending operations
/// When multiple components request the same data simultaneously, only one request is executed
actor RequestDeduplicator {
    private var pendingRequests: [String: Task<Any, Error>] = [:]

    /// Executes an operation, deduplicating concurrent requests with the same key
    /// - Parameters:
    ///   - key: Unique identifier for the request (e.g., "fetchInvoices:userId123")
    ///   - operation: The async operation to execute
    /// - Returns: The result of the operation
    /// - Throws: The error from the operation
    func execute<T: Sendable>(
        key: String,
        operation: @Sendable @escaping () async throws -> T
    ) async throws -> T {
        // Check if request is already pending
        if let existingTask = pendingRequests[key] {
            // Wait for existing task to complete
            do {
                let result = try await existingTask.value
                // Cast result to expected type
                guard let typedResult = result as? T else {
                    throw RequestDeduplicationError.typeMismatch
                }
                return typedResult
            } catch {
                // If existing task failed, remove it and retry
                pendingRequests.removeValue(forKey: key)
                throw error
            }
        }

        // Create new task
        let task = Task<Any, Error> {
            defer {
                Task {
                    await self.removeRequest(key: key)
                }
            }
            return try await operation() as Any
        }

        pendingRequests[key] = task

        do {
            let result = try await task.value
            guard let typedResult = result as? T else {
                throw RequestDeduplicationError.typeMismatch
            }
            return typedResult
        } catch {
            pendingRequests.removeValue(forKey: key)
            throw error
        }
    }

    /// Removes a completed request from the pending requests dictionary
    private func removeRequest(key: String) async {
        pendingRequests.removeValue(forKey: key)
    }

    /// Cancels all pending requests (useful for cleanup)
    func cancelAll() {
        for (_, task) in pendingRequests {
            task.cancel()
        }
        pendingRequests.removeAll()
    }

    /// Returns the number of pending requests
    var pendingCount: Int {
        pendingRequests.count
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
