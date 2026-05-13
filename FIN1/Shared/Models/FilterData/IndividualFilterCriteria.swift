import Foundation

// MARK: - Individual Filter Criteria
struct IndividualFilterCriteria: Codable, Equatable {
    let type: FilterType
    private let optionValue: String // Store as string for Codable compatibility

    enum FilterType: String, CaseIterable, Codable {
        case returnRate = "Ø-Return per Trade"
        case recentSuccessfulTrades = "Recent successful trades"
        case highestReturn = "Highest Return per Trade in %"
        case numberOfTrades = "Number of trades"
        case timeRange = "Time range"

        var displayName: String { rawValue }
    }

    // Computed properties to get the correct option type
    var returnPercentageOption: ReturnPercentageOption? {
        guard self.type == .returnRate else { return nil }
        return ReturnPercentageOption(rawValue: self.optionValue)
    }

    var numberOfTradesOption: NumberOfTradesOption? {
        guard self.type == .numberOfTrades else { return nil }
        return NumberOfTradesOption(rawValue: self.optionValue)
    }

    var successRateOption: FilterSuccessRateOption? {
        guard self.type == .recentSuccessfulTrades || self.type == .highestReturn || self.type == .timeRange else { return nil }
        return FilterSuccessRateOption(rawValue: self.optionValue)
    }

    // Legacy compatibility: selectedOption (for existing code)
    var selectedOption: FilterSuccessRateOption {
        return FilterSuccessRateOption(rawValue: self.optionValue) ?? .none
    }

    // Initializers for each filter type
    init(type: FilterType, returnPercentageOption: ReturnPercentageOption) {
        self.type = type
        self.optionValue = returnPercentageOption.rawValue
    }

    init(type: FilterType, numberOfTradesOption: NumberOfTradesOption) {
        self.type = type
        self.optionValue = numberOfTradesOption.rawValue
    }

    init(type: FilterType, successRateOption: FilterSuccessRateOption) {
        self.type = type
        self.optionValue = successRateOption.rawValue
    }

    // Legacy initializer for backward compatibility
    init(type: FilterType, selectedOption: FilterSuccessRateOption) {
        self.type = type
        self.optionValue = selectedOption.rawValue
    }

    // Codable implementation
    enum CodingKeys: String, CodingKey {
        case type, optionValue
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try container.decode(FilterType.self, forKey: .type)
        self.optionValue = try container.decode(String.self, forKey: .optionValue)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.type, forKey: .type)
        try container.encode(self.optionValue, forKey: .optionValue)
    }

    // Equatable conformance
    static func == (lhs: IndividualFilterCriteria, rhs: IndividualFilterCriteria) -> Bool {
        return lhs.type == rhs.type && lhs.optionValue == rhs.optionValue
    }
}







