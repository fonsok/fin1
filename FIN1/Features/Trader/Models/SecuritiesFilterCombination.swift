import Foundation

// MARK: - Securities Filter Combination
/// Model for saving and restoring securities search filter combinations
struct SecuritiesFilterCombination: Identifiable, Codable, Equatable {
    var id = UUID()
    let name: String
    let filters: SearchFilters
    let isDefault: Bool
    let createdAt: Date

    init(name: String, filters: SearchFilters, isDefault: Bool = false) {
        self.name = name
        self.filters = filters
        self.isDefault = isDefault
        self.createdAt = Date()
    }

    // Custom coding keys to handle UUID
    private enum CodingKeys: String, CodingKey {
        case name, filters, isDefault, createdAt
    }

    // Custom initializer for decoding
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        self.name = try container.decode(String.self, forKey: .name)
        self.filters = try container.decode(SearchFilters.self, forKey: .filters)
        self.isDefault = try container.decode(Bool.self, forKey: .isDefault)
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
    }

    // Custom encoding function
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(filters, forKey: .filters)
        try container.encode(isDefault, forKey: .isDefault)
        try container.encode(createdAt, forKey: .createdAt)
    }
}

// MARK: - SearchFilters Codable Extension
extension SearchFilters: Codable {
    enum CodingKeys: String, CodingKey {
        case category, underlyingAsset, direction, strikePriceGap, remainingTerm, issuer, omega
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let category = try container.decode(String.self, forKey: .category)
        let underlyingAsset = try container.decode(String.self, forKey: .underlyingAsset)

        // Decode direction as rawValue string
        let directionString = try container.decode(String.self, forKey: .direction)
        guard let direction = SecuritiesSearchView.Direction(rawValue: directionString) else {
            throw DecodingError.dataCorruptedError(forKey: .direction, in: container, debugDescription: "Invalid direction value")
        }

        let strikePriceGap = try container.decodeIfPresent(String.self, forKey: .strikePriceGap)
        let remainingTerm = try container.decodeIfPresent(String.self, forKey: .remainingTerm)
        let issuer = try container.decodeIfPresent(String.self, forKey: .issuer)
        let omega = try container.decodeIfPresent(String.self, forKey: .omega)

        // Use memberwise initializer
        self.init(
            category: category,
            underlyingAsset: underlyingAsset,
            direction: direction,
            strikePriceGap: strikePriceGap,
            remainingTerm: remainingTerm,
            issuer: issuer,
            omega: omega
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(category, forKey: .category)
        try container.encode(underlyingAsset, forKey: .underlyingAsset)
        try container.encode(direction.rawValue, forKey: .direction)
        try container.encodeIfPresent(strikePriceGap, forKey: .strikePriceGap)
        try container.encodeIfPresent(remainingTerm, forKey: .remainingTerm)
        try container.encodeIfPresent(issuer, forKey: .issuer)
        try container.encodeIfPresent(omega, forKey: .omega)
    }
}
