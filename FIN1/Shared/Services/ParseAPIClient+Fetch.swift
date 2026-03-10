import Foundation

// MARK: - Fetch (fetchObjects, fetchObject)

extension ParseAPIClient {

    func fetchObjects<T: Decodable>(
        className: String,
        query: [String: Any]? = nil,
        include: [String]? = nil,
        orderBy: String? = nil,
        limit: Int? = nil
    ) async throws -> [T] {
        let deduplicationKey = createDeduplicationKey(
            operation: "fetchObjects",
            className: className,
            query: query,
            include: include,
            orderBy: orderBy,
            limit: limit
        )

        return try await requestDeduplicator.execute(key: deduplicationKey) {
            try await self.executeWithRetry {
                try await self.performFetchObjects(
                    className: className,
                    query: query,
                    include: include,
                    orderBy: orderBy,
                    limit: limit
                )
            }
        }
    }

    func performFetchObjects<T: Decodable>(
        className: String,
        query: [String: Any]?,
        include: [String]?,
        orderBy: String?,
        limit: Int?
    ) async throws -> [T] {
        let endpoint = "/classes/\(className)"
        let startTime = Date()
        var requestSize: Int?
        var responseSize: Int?
        var statusCode: Int?
        var error: Error?
        let retryCount = 0

        defer {
            let duration = Date().timeIntervalSince(startTime)
            networkLogger?.logRequest(
                endpoint: endpoint,
                method: "GET",
                statusCode: statusCode,
                duration: duration,
                requestSize: requestSize,
                responseSize: responseSize,
                error: error,
                retryCount: retryCount
            )
        }

        guard var components = URLComponents(string: "\(baseURL)\(endpoint)") else {
            error = NetworkError.invalidResponse
            throw NetworkError.invalidResponse
        }

        var queryItems: [URLQueryItem] = []
        if let query = query,
           let queryJSON = try? JSONSerialization.data(withJSONObject: query),
           let queryString = String(data: queryJSON, encoding: .utf8) {
            queryItems.append(URLQueryItem(name: "where", value: queryString))
        }
        if let include = include, !include.isEmpty {
            queryItems.append(URLQueryItem(name: "include", value: include.joined(separator: ",")))
        }
        if let orderBy = orderBy {
            queryItems.append(URLQueryItem(name: "order", value: orderBy))
        }
        if let limit = limit {
            queryItems.append(URLQueryItem(name: "limit", value: "\(limit)"))
        }

        components.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let finalURL = components.url else {
            error = NetworkError.invalidResponse
            throw NetworkError.invalidResponse
        }

        var request = URLRequest(url: finalURL)
        request.httpMethod = "GET"
        addHeaders(to: &request)
        requestSize = request.httpBody?.count

        do {
            let (data, response) = try await session.data(for: request)
            responseSize = data.count
            if let httpResponse = response as? HTTPURLResponse {
                statusCode = httpResponse.statusCode
            }
            try validateResponse(response)
            let decoder = Self.makeDateDecoder()
            let parseResponse = try decoder.decode(ParseQueryResponse<T>.self, from: data)
            return parseResponse.results
        } catch {
            throw error
        }
    }

    func fetchObject<T: Decodable>(
        className: String,
        objectId: String,
        include: [String]? = nil
    ) async throws -> T {
        let deduplicationKey = createDeduplicationKey(
            operation: "fetchObject",
            className: className,
            include: include,
            objectId: objectId
        )

        return try await requestDeduplicator.execute(key: deduplicationKey) {
            try await self.executeWithRetry {
                try await self.performFetchObject(
                    className: className,
                    objectId: objectId,
                    include: include
                )
            }
        }
    }

    func performFetchObject<T: Decodable>(
        className: String,
        objectId: String,
        include: [String]?
    ) async throws -> T {
        var components = URLComponents(string: "\(baseURL)/classes/\(className)/\(objectId)")
        if let include = include, !include.isEmpty {
            components?.queryItems = [
                URLQueryItem(name: "include", value: include.joined(separator: ","))
            ]
        }

        guard let url = components?.url else {
            throw NetworkError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addHeaders(to: &request)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        let decoder = Self.makeDateDecoder()
        return try decoder.decode(T.self, from: data)
    }
}
