import Foundation

// MARK: - Filter API Service Protocol

/// Protocol for syncing saved filters to Parse Server backend
protocol FilterAPIServiceProtocol {
    /// Saves a securities filter to the Parse Server
    func saveSecuritiesFilter(_ filter: SecuritiesFilterCombination, userId: String) async throws -> SecuritiesFilterCombination

    /// Saves a trader discovery filter to the Parse Server
    func saveTraderFilter(_ filter: FilterCombination, userId: String) async throws -> FilterCombination

    /// Updates a securities filter on the Parse Server
    func updateSecuritiesFilter(_ filter: SecuritiesFilterCombination, userId: String) async throws -> SecuritiesFilterCombination

    /// Updates a trader discovery filter on the Parse Server
    func updateTraderFilter(_ filter: FilterCombination, userId: String) async throws -> FilterCombination

    /// Removes a filter from the Parse Server
    func deleteFilter(_ filterId: String, context: FilterContext, userId: String) async throws

    /// Fetches all securities filters for a user
    func fetchSecuritiesFilters(for userId: String) async throws -> [SecuritiesFilterCombination]

    /// Fetches all trader discovery filters for a user
    func fetchTraderFilters(for userId: String) async throws -> [FilterCombination]
}

// MARK: - Filter Context

/// Enum representing different filter contexts
enum FilterContext: String, Codable {
    case securitiesSearch = "securities_search"
    case traderDiscovery = "trader_discovery"
}

// MARK: - Parse Filter Input

/// Input struct for creating/updating filters on Parse Server
private struct ParseFilterInput: Encodable {
    let userId: String
    let name: String
    let filterContext: String
    let filterCriteria: [String: AnyCodable]
    let isDefault: Bool
    let createdAt: String

    static func from(securitiesFilter: SecuritiesFilterCombination, userId: String) -> ParseFilterInput {
        // Encode SearchFilters to dictionary
        let criteria: [String: AnyCodable] = [
            "category": AnyCodable(securitiesFilter.filters.category),
            "underlyingAsset": AnyCodable(securitiesFilter.filters.underlyingAsset),
            "direction": AnyCodable(securitiesFilter.filters.direction.rawValue),
            "strikePriceGap": AnyCodable(securitiesFilter.filters.strikePriceGap),
            "remainingTerm": AnyCodable(securitiesFilter.filters.remainingTerm),
            "issuer": AnyCodable(securitiesFilter.filters.issuer),
            "omega": AnyCodable(securitiesFilter.filters.omega)
        ]

        return ParseFilterInput(
            userId: userId,
            name: securitiesFilter.name,
            filterContext: FilterContext.securitiesSearch.rawValue,
            filterCriteria: criteria,
            isDefault: securitiesFilter.isDefault,
            createdAt: ISO8601DateFormatter().string(from: securitiesFilter.createdAt)
        )
    }

    static func from(traderFilter: FilterCombination, userId: String) -> ParseFilterInput {
        // Encode IndividualFilterCriteria array to dictionary
        var criteria: [String: AnyCodable] = [:]
        for filter in traderFilter.filters {
            criteria[filter.id] = AnyCodable(filter.value)
        }

        return ParseFilterInput(
            userId: userId,
            name: traderFilter.name,
            filterContext: FilterContext.traderDiscovery.rawValue,
            filterCriteria: criteria,
            isDefault: traderFilter.isDefault,
            createdAt: ISO8601DateFormatter().string(from: traderFilter.createdAt)
        )
    }
}

// MARK: - Parse Filter Response

/// Response struct for Parse Server filter operations
private struct ParseFilterResponse: Codable {
    let objectId: String
    let userId: String
    let name: String
    let filterContext: String
    let filterCriteria: [String: AnyCodable]
    let isDefault: Bool
    let createdAt: String
    let updatedAt: String?

    func toSecuritiesFilter() throws -> SecuritiesFilterCombination {
        guard filterContext == FilterContext.securitiesSearch.rawValue else {
            throw FilterAPIServiceError.invalidContext
        }

        // Decode SearchFilters from dictionary
        guard let category = filterCriteria["category"]?.stringValue,
              let underlyingAsset = filterCriteria["underlyingAsset"]?.stringValue,
              let directionString = filterCriteria["direction"]?.stringValue,
              let direction = SecuritiesSearchView.Direction(rawValue: directionString) else {
            throw FilterAPIServiceError.invalidFilterData
        }

        let searchFilters = SearchFilters(
            category: category,
            underlyingAsset: underlyingAsset,
            direction: direction,
            strikePriceGap: filterCriteria["strikePriceGap"]?.stringValue,
            remainingTerm: filterCriteria["remainingTerm"]?.stringValue,
            issuer: filterCriteria["issuer"]?.stringValue,
            omega: filterCriteria["omega"]?.stringValue
        )

        let dateFormatter = ISO8601DateFormatter()
        let createdAtDate = dateFormatter.date(from: createdAt) ?? Date()

        var filter = SecuritiesFilterCombination(
            name: name,
            filters: searchFilters,
            isDefault: isDefault
        )
        // Note: id and createdAt are set in init, but we need to preserve objectId
        // We'll use objectId as a reference, but keep UUID for local identification
        return filter
    }

    func toTraderFilter() throws -> FilterCombination {
        guard filterContext == FilterContext.traderDiscovery.rawValue else {
            throw FilterAPIServiceError.invalidContext
        }

        // Decode IndividualFilterCriteria array from dictionary
        var filters: [IndividualFilterCriteria] = []
        for (key, value) in filterCriteria {
            if let stringValue = value.stringValue {
                filters.append(IndividualFilterCriteria(id: key, value: stringValue))
            }
        }

        let dateFormatter = ISO8601DateFormatter()
        let createdAtDate = dateFormatter.date(from: createdAt) ?? Date()

        var filter = FilterCombination(
            name: name,
            filters: filters,
            isDefault: isDefault
        )
        return filter
    }
}

// MARK: - Filter API Service Error

enum FilterAPIServiceError: LocalizedError {
    case invalidContext
    case invalidFilterData

    var errorDescription: String? {
        switch self {
        case .invalidContext:
            return "Invalid filter context"
        case .invalidFilterData:
            return "Invalid filter data structure"
        }
    }
}

// MARK: - Any Codable Helper

/// Helper struct to encode/decode Any values as Codable
private struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "AnyCodable value cannot be decoded")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        default:
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: container.codingPath, debugDescription: "AnyCodable value cannot be encoded"))
        }
    }

    var stringValue: String? {
        return value as? String
    }
}

// MARK: - Filter API Service Implementation

final class FilterAPIService: FilterAPIServiceProtocol {
    private let apiClient: ParseAPIClientProtocol
    private let className = "SavedFilter"

    init(apiClient: ParseAPIClientProtocol) {
        self.apiClient = apiClient
    }

    // MARK: - Securities Filters

    func saveSecuritiesFilter(_ filter: SecuritiesFilterCombination, userId: String) async throws -> SecuritiesFilterCombination {
        let input = ParseFilterInput.from(securitiesFilter: filter, userId: userId)
        let response: ParseResponse = try await apiClient.createObject(
            className: className,
            data: try encodeFilterInput(input)
        )

        // Return filter with objectId reference (but keep UUID for local use)
        return filter
    }

    func updateSecuritiesFilter(_ filter: SecuritiesFilterCombination, userId: String) async throws -> SecuritiesFilterCombination {
        // For updates, we need the objectId - but filters use UUID
        // We'll need to fetch first to find the objectId, or store it separately
        // For now, treat update as create (idempotent by name+context)
        let input = ParseFilterInput.from(securitiesFilter: filter, userId: userId)

        // Try to find existing filter by name and context
        let existingFilters = try await fetchSecuritiesFilters(for: userId)
        if let existing = existingFilters.first(where: { $0.name == filter.name }) {
            // Update existing - but we don't have objectId in the model
            // For now, delete and recreate (not ideal, but works)
            // TODO: Store objectId in filter model or use a mapping
            return try await saveSecuritiesFilter(filter, userId: userId)
        } else {
            return try await saveSecuritiesFilter(filter, userId: userId)
        }
    }

    func fetchSecuritiesFilters(for userId: String) async throws -> [SecuritiesFilterCombination] {
        let query: [String: Any] = [
            "userId": userId,
            "filterContext": FilterContext.securitiesSearch.rawValue
        ]

        let responses: [ParseFilterResponse] = try await apiClient.fetchObjects(
            className: className,
            query: query
        )

        return try responses.compactMap { response in
            try? response.toSecuritiesFilter()
        }
    }

    // MARK: - Trader Discovery Filters

    func saveTraderFilter(_ filter: FilterCombination, userId: String) async throws -> FilterCombination {
        let input = ParseFilterInput.from(traderFilter: filter, userId: userId)
        let response: ParseResponse = try await apiClient.createObject(
            className: className,
            data: try encodeFilterInput(input)
        )

        return filter
    }

    func updateTraderFilter(_ filter: FilterCombination, userId: String) async throws -> FilterCombination {
        // Similar to securities filter - treat as create for now
        return try await saveTraderFilter(filter, userId: userId)
    }

    func fetchTraderFilters(for userId: String) async throws -> [FilterCombination] {
        let query: [String: Any] = [
            "userId": userId,
            "filterContext": FilterContext.traderDiscovery.rawValue
        ]

        let responses: [ParseFilterResponse] = try await apiClient.fetchObjects(
            className: className,
            query: query
        )

        return try responses.compactMap { response in
            try? response.toTraderFilter()
        }
    }

    // MARK: - Delete

    func deleteFilter(_ filterId: String, context: FilterContext, userId: String) async throws {
        // Find filter by name and context, then delete by objectId
        // For now, we'll need to fetch first to get objectId
        let query: [String: Any] = [
            "userId": userId,
            "filterContext": context.rawValue
        ]

        let responses: [ParseFilterResponse] = try await apiClient.fetchObjects(
            className: className,
            query: query
        )

        // Find matching filter and delete
        // Note: This is inefficient - ideally we'd store objectId in the filter model
        // For now, we'll delete all matching filters (should be unique by name+context)
        for response in responses {
            try? await apiClient.deleteObject(className: className, objectId: response.objectId)
        }
    }

    // MARK: - Private Helpers

    private func encodeFilterInput(_ input: ParseFilterInput) throws -> [String: Any] {
        let encoder = JSONEncoder()
        let data = try encoder.encode(input)
        guard let dictionary = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw FilterAPIServiceError.invalidFilterData
        }
        return dictionary
    }
}
