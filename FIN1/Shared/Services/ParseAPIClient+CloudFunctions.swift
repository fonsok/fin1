import Foundation

// MARK: - Authentication & Cloud Functions

extension ParseAPIClient {

    func login(username: String, password: String) async throws -> ParseLoginResponse {
        guard let url = URL(string: "\(baseURL)/login") else {
            throw NetworkError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(applicationId, forHTTPHeaderField: "X-Parse-Application-Id")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("1", forHTTPHeaderField: "X-Parse-Revocable-Session")

        let body: [String: String] = ["username": username, "password": password]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        return try Self.makeDateDecoder().decode(ParseLoginResponse.self, from: data)
    }

    // MARK: - Cloud Functions

    func callFunction<T: Decodable>(
        _ name: String,
        parameters: [String: Any]? = nil
    ) async throws -> T {
        do {
            return try await executeWithRetry {
                try await self.performCallFunction(name: name, parameters: parameters)
            }
        } catch {
            if !(await NetworkMonitor.shared.isConnected),
               let queue = offlineQueue,
               let params = parameters,
               let payload = try? JSONSerialization.data(withJSONObject: params) {
                let operation = OfflineOperationQueue.QueuedOperation(
                    type: .callFunction,
                    functionName: name,
                    payload: payload,
                    userId: sessionTokenProvider?()
                )
                await queue.enqueue(operation)
                throw NetworkError.noConnection
            }
            throw error
        }
    }

    func performCallFunction<T: Decodable>(
        name: String,
        parameters: [String: Any]?
    ) async throws -> T {
        guard let url = URL(string: "\(baseURL)/functions/\(name)") else {
            throw NetworkError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        addHeaders(to: &request)

        if let parameters = parameters {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters, options: [])
        } else {
            request.httpBody = try JSONSerialization.data(withJSONObject: [:], options: [])
        }

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        let decoder = Self.makeDateDecoder()
        if let envelope = try? decoder.decode(ParseFunctionEnvelope<T>.self, from: data) {
            return envelope.result
        }
        return try decoder.decode(T.self, from: data)
    }
}
