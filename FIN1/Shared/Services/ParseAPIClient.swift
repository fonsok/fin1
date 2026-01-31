import Foundation

// MARK: - Parse API Client Protocol

/// Protocol for making HTTP requests to Parse Server
protocol ParseAPIClientProtocol {
    /// Fetches objects from a Parse class
    func fetchObjects<T: Decodable>(
        className: String,
        query: [String: Any]?,
        include: [String]?,
        orderBy: String?,
        limit: Int?
    ) async throws -> [T]

    /// Fetches a single object by ID
    func fetchObject<T: Decodable>(
        className: String,
        objectId: String,
        include: [String]?
    ) async throws -> T

    /// Creates a new object in Parse
    func createObject<T: Encodable>(
        className: String,
        object: T
    ) async throws -> ParseResponse

    /// Updates an existing object in Parse
    func updateObject<T: Encodable>(
        className: String,
        objectId: String,
        object: T
    ) async throws -> ParseResponse

    /// Deletes an object from Parse
    func deleteObject(
        className: String,
        objectId: String
    ) async throws

    /// Calls a Parse Cloud Function
    /// - Note: Uses REST endpoint: POST /functions/{name}
    func callFunction<T: Decodable>(
        _ name: String,
        parameters: [String: Any]?
    ) async throws -> T
}

// MARK: - Parse Response Models

struct ParseResponse: Codable {
    let objectId: String
    let createdAt: String?
    let updatedAt: String?
}

struct ParseQueryResponse<T: Decodable>: Decodable {
    let results: [T]
}

/// Parse Cloud Functions usually respond with `{ "result": <payload> }`
private struct ParseFunctionEnvelope<R: Decodable>: Decodable {
    let result: R
}

// MARK: - Parse API Client Implementation

/// HTTP client for Parse Server REST API
final class ParseAPIClient: ParseAPIClientProtocol {

    // MARK: - Properties

    private let baseURL: String
    private let applicationId: String
    private let sessionToken: String?
    private let session: URLSession

    // MARK: - Initialization

    init(
        baseURL: String,
        applicationId: String,
        sessionToken: String? = nil
    ) {
        self.baseURL = baseURL
        self.applicationId = applicationId
        self.sessionToken = sessionToken

        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: configuration)
    }

    // MARK: - Public Methods

    func fetchObjects<T: Decodable>(
        className: String,
        query: [String: Any]? = nil,
        include: [String]? = nil,
        orderBy: String? = nil,
        limit: Int? = nil
    ) async throws -> [T] {
        guard var components = URLComponents(string: "\(baseURL)/classes/\(className)") else {
            throw NetworkError.invalidResponse
        }

        var queryItems: [URLQueryItem] = []

        // Add query parameters
        if let query = query {
            if let queryJSON = try? JSONSerialization.data(withJSONObject: query),
               let queryString = String(data: queryJSON, encoding: .utf8) {
                queryItems.append(URLQueryItem(name: "where", value: queryString))
            }
        }

        // Add include parameters
        if let include = include, !include.isEmpty {
            queryItems.append(URLQueryItem(name: "include", value: include.joined(separator: ",")))
        }

        // Add order by
        if let orderBy = orderBy {
            queryItems.append(URLQueryItem(name: "order", value: orderBy))
        }

        // Add limit
        if let limit = limit {
            queryItems.append(URLQueryItem(name: "limit", value: "\(limit)"))
        }

        components.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let finalURL = components.url else {
            throw NetworkError.invalidResponse
        }

        var request = URLRequest(url: finalURL)
        request.httpMethod = "GET"
        addHeaders(to: &request)

        let (data, response) = try await session.data(for: request)

        try validateResponse(response)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            // Parse Server uses ISO8601 format with milliseconds
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            if let date = formatter.date(from: dateString) {
                return date
            }

            // Fallback to standard ISO8601
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: dateString) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid date format: \(dateString)"
            )
        }

        let parseResponse = try decoder.decode(ParseQueryResponse<T>.self, from: data)
        return parseResponse.results
    }

    func fetchObject<T: Decodable>(
        className: String,
        objectId: String,
        include: [String]? = nil
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

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            if let date = formatter.date(from: dateString) {
                return date
            }

            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: dateString) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid date format: \(dateString)"
            )
        }

        return try decoder.decode(T.self, from: data)
    }

    func createObject<T: Encodable>(
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
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(object)

        let (data, response) = try await session.data(for: request)

        try validateResponse(response)

        let decoder = JSONDecoder()
        return try decoder.decode(ParseResponse.self, from: data)
    }

    func updateObject<T: Encodable>(
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
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(object)

        let (data, response) = try await session.data(for: request)

        try validateResponse(response)

        let decoder = JSONDecoder()
        return try decoder.decode(ParseResponse.self, from: data)
    }

    func deleteObject(
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

    func callFunction<T: Decodable>(
        _ name: String,
        parameters: [String: Any]? = nil
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

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: dateString) {
                return date
            }
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: dateString) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid date format: \(dateString)"
            )
        }

        // Prefer envelope decode; fallback to direct decode for non-standard functions.
        if let envelope = try? decoder.decode(ParseFunctionEnvelope<T>.self, from: data) {
            return envelope.result
        }
        return try decoder.decode(T.self, from: data)
    }

    // MARK: - Private Methods

    private func addHeaders(to request: inout URLRequest) {
        request.setValue(applicationId, forHTTPHeaderField: "X-Parse-Application-Id")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let sessionToken = sessionToken {
            request.setValue(sessionToken, forHTTPHeaderField: "X-Parse-Session-Token")
        }
    }

    private func validateResponse(_ response: URLResponse) throws {
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
        case 500...599:
            throw NetworkError.serverError(httpResponse.statusCode)
        default:
            throw NetworkError.serverError(httpResponse.statusCode)
        }
    }
}

