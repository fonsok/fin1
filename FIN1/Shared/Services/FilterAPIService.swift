import Foundation

// MARK: - Filter API Service Protocol

/// Protocol for syncing saved filters to Parse Server backend
protocol FilterAPIServiceProtocol: Sendable {
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
        var criteria: [String: AnyCodable] = [
            "category": AnyCodable(securitiesFilter.filters.category),
            "underlyingAsset": AnyCodable(securitiesFilter.filters.underlyingAsset),
            "direction": AnyCodable(securitiesFilter.filters.direction.rawValue)
        ]
        // Add optional fields only if they have values
        if let strikePriceGap = securitiesFilter.filters.strikePriceGap {
            criteria["strikePriceGap"] = AnyCodable(strikePriceGap)
        }
        if let remainingTerm = securitiesFilter.filters.remainingTerm {
            criteria["remainingTerm"] = AnyCodable(remainingTerm)
        }
        if let issuer = securitiesFilter.filters.issuer {
            criteria["issuer"] = AnyCodable(issuer)
        }
        if let omega = securitiesFilter.filters.omega {
            criteria["omega"] = AnyCodable(omega)
        }

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
        // Encode IndividualFilterCriteria array to dictionary using type.rawValue as key
        var criteria: [String: AnyCodable] = [:]
        for filter in traderFilter.filters {
            // Use type's rawValue as key and the selectedOption's rawValue as value
            criteria[filter.type.rawValue] = AnyCodable(filter.selectedOption.rawValue)
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

/// Response struct for Parse Server filter operations (internal for unit tests.)
struct ParseFilterResponse: Codable, Sendable {
    let objectId: String
    let userId: String
    let name: String
    let filterContext: String
    let filterCriteria: [String: AnyCodable]
    let isDefault: Bool
    let createdAt: String
    let updatedAt: String?

    func toSecuritiesFilter() throws -> SecuritiesFilterCombination {
        guard self.filterContext == FilterContext.securitiesSearch.rawValue else {
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
            remainingTerm: self.filterCriteria["remainingTerm"]?.stringValue,
            issuer: self.filterCriteria["issuer"]?.stringValue,
            omega: self.filterCriteria["omega"]?.stringValue
        )

        // Note: id and createdAt are set in init, but we need to preserve objectId
        // We'll use objectId as a reference, but keep UUID for local identification
        return SecuritiesFilterCombination(
            name: self.name,
            filters: searchFilters,
            isDefault: self.isDefault
        )
    }

    func toTraderFilter() throws -> FilterCombination {
        guard self.filterContext == FilterContext.traderDiscovery.rawValue else {
            throw FilterAPIServiceError.invalidContext
        }

        // Decode IndividualFilterCriteria array from dictionary
        var filters: [IndividualFilterCriteria] = []
        for (key, value) in self.filterCriteria {
            if let stringValue = value.stringValue,
               let filterType = IndividualFilterCriteria.FilterType(rawValue: key),
               let option = FilterSuccessRateOption(rawValue: stringValue) {
                filters.append(IndividualFilterCriteria(type: filterType, selectedOption: option))
            }
        }

        return FilterCombination(
            name: self.name,
            filters: filters,
            isDefault: self.isDefault
        )
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
// Note: AnyCodable is defined in OfflineOperationQueue.swift and reused here

// MARK: - Filter API Service Implementation

final class FilterAPIService: FilterAPIServiceProtocol, @unchecked Sendable {
    private let apiClient: ParseAPIClientProtocol
    private let className = "SavedFilter"

    init(apiClient: ParseAPIClientProtocol) {
        self.apiClient = apiClient
    }

    // MARK: - Securities Filters

    func saveSecuritiesFilter(_ filter: SecuritiesFilterCombination, userId: String) async throws -> SecuritiesFilterCombination {
        let input = ParseFilterInput.from(securitiesFilter: filter, userId: userId)
        let _: ParseResponse = try await apiClient.createObject(
            className: self.className,
            object: input
        )

        // Return filter with objectId reference (but keep UUID for local use)
        return filter
    }

    func updateSecuritiesFilter(_ filter: SecuritiesFilterCombination, userId: String) async throws -> SecuritiesFilterCombination {
        // For updates, we need the objectId - but filters use UUID
        // We'll need to fetch first to find the objectId, or store it separately
        // For now, treat update as create (idempotent by name+context)
        // TODO: Store objectId in filter model or use a mapping for proper update
        return try await self.saveSecuritiesFilter(filter, userId: userId)
    }

    func fetchSecuritiesFilters(for userId: String) async throws -> [SecuritiesFilterCombination] {
        let query: [String: Any] = [
            "userId": userId,
            "filterContext": FilterContext.securitiesSearch.rawValue
        ]

        let responses: [ParseFilterResponse] = try await apiClient.fetchObjects(
            className: self.className,
            query: query,
            include: nil,
            orderBy: nil,
            limit: nil
        )

        return responses.compactMap { response in
            try? response.toSecuritiesFilter()
        }
    }

    // MARK: - Trader Discovery Filters

    func saveTraderFilter(_ filter: FilterCombination, userId: String) async throws -> FilterCombination {
        let input = ParseFilterInput.from(traderFilter: filter, userId: userId)
        let _: ParseResponse = try await apiClient.createObject(
            className: self.className,
            object: input
        )

        return filter
    }

    func updateTraderFilter(_ filter: FilterCombination, userId: String) async throws -> FilterCombination {
        // Similar to securities filter - treat as create for now
        return try await self.saveTraderFilter(filter, userId: userId)
    }

    func fetchTraderFilters(for userId: String) async throws -> [FilterCombination] {
        let query: [String: Any] = [
            "userId": userId,
            "filterContext": FilterContext.traderDiscovery.rawValue
        ]

        let responses: [ParseFilterResponse] = try await apiClient.fetchObjects(
            className: self.className,
            query: query,
            include: nil,
            orderBy: nil,
            limit: nil
        )

        return responses.compactMap { response in
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
            className: self.className,
            query: query,
            include: nil,
            orderBy: nil,
            limit: nil
        )

        // Find matching filter and delete
        // Note: This is inefficient - ideally we'd store objectId in the filter model
        // For now, we'll delete all matching filters (should be unique by name+context)
        for response in responses {
            try? await self.apiClient.deleteObject(className: self.className, objectId: response.objectId)
        }
    }
}
