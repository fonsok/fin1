import Foundation

// MARK: - Create, Update, Delete

extension ParseAPIClient {

    func createObject<T: Encodable>(
        className: String,
        object: T
    ) async throws -> ParseResponse {
        do {
            return try await executeWithRetry {
                try await self.performCreateObject(className: className, object: object)
            }
        } catch {
            if !(await NetworkMonitor.shared.isConnected),
               let queue = offlineQueue,
               let payload = try? JSONEncoder().encode(object) {
                let operation = OfflineOperationQueue.QueuedOperation(
                    type: .create,
                    className: className,
                    payload: payload,
                    userId: sessionTokenProvider?()
                )
                await queue.enqueue(operation)
                throw NetworkError.noConnection
            }
            throw error
        }
    }

    func performCreateObject<T: Encodable>(
        className: String,
        object: T
    ) async throws -> ParseResponse {
        guard let url = URL(string: "\(baseURL)/classes/\(className)") else {
            throw NetworkError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        addHeaders(to: &request)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = Self.parseDateEncodingStrategy
        request.httpBody = try encoder.encode(object)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        if (200...299).contains(httpResponse.statusCode) {
            return try JSONDecoder().decode(ParseResponse.self, from: data)
        }
        if httpResponse.statusCode == 400 {
            if let message = ParseAPIClient.parseErrorMessageFromResponseBody(data) {
                throw NetworkError.badRequest(message)
            }
            throw NetworkError.badRequest(String(localized: "Die Anfrage wurde vom Server abgelehnt."))
        }
        try validateResponse(response)
        throw NetworkError.invalidResponse
    }

    func updateObject<T: Codable & Sendable>(
        className: String,
        objectId: String,
        object: T
    ) async throws -> ParseResponse {
        do {
            return try await executeWithRetry {
                try await self.performUpdateObject(className: className, objectId: objectId, object: object)
            }
        } catch let error as NetworkError {
            if case .serverError(409) = error,
               let resolver = conflictResolver {
                return try await handleConflict(
                    className: className,
                    objectId: objectId,
                    localObject: object,
                    resolver: resolver
                )
            }

            if !(await NetworkMonitor.shared.isConnected),
               let queue = offlineQueue,
               let payload = try? JSONEncoder().encode(object) {
                let operation = OfflineOperationQueue.QueuedOperation(
                    type: .update,
                    className: className,
                    objectId: objectId,
                    payload: payload,
                    userId: sessionTokenProvider?()
                )
                await queue.enqueue(operation)
                throw NetworkError.noConnection
            }
            throw error
        } catch {
            if !(await NetworkMonitor.shared.isConnected),
               let queue = offlineQueue,
               let payload = try? JSONEncoder().encode(object) {
                let operation = OfflineOperationQueue.QueuedOperation(
                    type: .update,
                    className: className,
                    objectId: objectId,
                    payload: payload,
                    userId: sessionTokenProvider?()
                )
                await queue.enqueue(operation)
                throw NetworkError.noConnection
            }
            throw error
        }
    }

    func handleConflict<T: Codable & Sendable>(
        className: String,
        objectId: String,
        localObject: T,
        resolver: ConflictResolutionServiceProtocol
    ) async throws -> ParseResponse {
        let remoteObject: T = try await fetchObject(className: className, objectId: objectId)
        let localUpdatedAt = self.extractUpdatedAt(from: localObject)
        let remoteUpdatedAt = self.extractUpdatedAt(from: remoteObject)

        let resolvedObject = try await resolver.resolveConflict(
            local: localObject,
            remote: remoteObject,
            localUpdatedAt: localUpdatedAt,
            remoteUpdatedAt: remoteUpdatedAt
        )

        return try await executeWithRetry {
            try await self.performUpdateObject(className: className, objectId: objectId, object: resolvedObject)
        }
    }

    func extractUpdatedAt<T>(from object: T) -> Date? {
        let mirror = Mirror(reflecting: object)
        for child in mirror.children {
            if let label = child.label,
               (label == "updatedAt" || label == "lastModified"),
               let date = child.value as? Date {
                return date
            }
        }

        if let encodable = object as? Encodable,
           let data = try? JSONEncoder().encode(encodable),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let updatedAtString = dict["updatedAt"] as? String {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return formatter.date(from: updatedAtString) ?? formatter.date(
                from: updatedAtString.replacingOccurrences(of: "\\.\\d+", with: "", options: .regularExpression)
            )
        }

        return nil
    }

    func performUpdateObject<T: Encodable>(
        className: String,
        objectId: String,
        object: T
    ) async throws -> ParseResponse {
        guard let url = URL(string: "\(baseURL)/classes/\(className)/\(objectId)") else {
            throw NetworkError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        addHeaders(to: &request)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = Self.parseDateEncodingStrategy
        request.httpBody = try encoder.encode(object)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        if (200...299).contains(httpResponse.statusCode) {
            return try JSONDecoder().decode(ParseResponse.self, from: data)
        }
        if httpResponse.statusCode == 400 {
            if let message = ParseAPIClient.parseErrorMessageFromResponseBody(data) {
                throw NetworkError.badRequest(message)
            }
            throw NetworkError.badRequest(String(localized: "Die Anfrage wurde vom Server abgelehnt."))
        }
        try validateResponse(response)
        throw NetworkError.invalidResponse
    }

    func deleteObject(
        className: String,
        objectId: String
    ) async throws {
        do {
            try await executeWithRetry {
                try await self.performDeleteObject(className: className, objectId: objectId)
            }
        } catch {
            if !(await NetworkMonitor.shared.isConnected),
               let queue = offlineQueue {
                let payload = try? JSONEncoder().encode([String: String]())
                let operation = OfflineOperationQueue.QueuedOperation(
                    type: .delete,
                    className: className,
                    objectId: objectId,
                    payload: payload ?? Data(),
                    userId: sessionTokenProvider?()
                )
                await queue.enqueue(operation)
                throw NetworkError.noConnection
            }
            throw error
        }
    }

    func performDeleteObject(
        className: String,
        objectId: String
    ) async throws {
        guard let url = URL(string: "\(baseURL)/classes/\(className)/\(objectId)") else {
            throw NetworkError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        addHeaders(to: &request)

        let (_, response) = try await session.data(for: request)
        try validateResponse(response)
    }
}
