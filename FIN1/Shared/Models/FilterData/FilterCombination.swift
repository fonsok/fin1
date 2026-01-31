import Foundation

// MARK: - Filter Combination
struct FilterCombination: Identifiable, Codable, Equatable {
    var id = UUID()
    let name: String
    let filters: [IndividualFilterCriteria]
    let isDefault: Bool
    let createdAt: Date

    init(name: String, filters: [IndividualFilterCriteria], isDefault: Bool = false) {
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
        self.filters = try container.decode([IndividualFilterCriteria].self, forKey: .filters)
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







