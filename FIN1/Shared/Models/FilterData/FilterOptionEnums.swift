import Foundation

// MARK: - Return Percentage Options
enum ReturnPercentageOption: String, CaseIterable, Codable {
    case none = "---"
    case greaterThan10 = "≥ 10 %"
    case greaterThan20 = "≥ 20 %"
    case greaterThan30 = "≥ 30 %"
    case greaterThan40 = "≥ 40 %"
    case greaterThan50 = "≥ 50 %"
    case greaterThan60 = "≥ 60 %"
    case greaterThan80 = "≥ 80 %"
    case greaterThan100 = "≥ 100 %"
    case greaterThan150 = "≥ 150 %"

    var displayName: String { rawValue }

    var minimumPercentage: Double? {
        switch self {
        case .greaterThan10: return 10.0
        case .greaterThan20: return 20.0
        case .greaterThan30: return 30.0
        case .greaterThan40: return 40.0
        case .greaterThan50: return 50.0
        case .greaterThan60: return 60.0
        case .greaterThan80: return 80.0
        case .greaterThan100: return 100.0
        case .greaterThan150: return 150.0
        default: return nil
        }
    }
}

// MARK: - Number of Trades Options
enum NumberOfTradesOption: String, CaseIterable, Codable {
    case none = "---"
    case greaterThan5 = "≥ 5"
    case greaterThan10 = "≥ 10"
    case greaterThan20 = "≥ 20"
    case greaterThan30 = "≥ 30"
    case greaterThan40 = "≥ 40"
    case greaterThan50 = "≥ 50"
    case greaterThan60 = "≥ 60"
    case greaterThan80 = "≥ 80"
    case greaterThan100 = "≥ 100"

    var displayName: String { rawValue }

    var minimumCount: Int? {
        switch self {
        case .greaterThan5: return 5
        case .greaterThan10: return 10
        case .greaterThan20: return 20
        case .greaterThan30: return 30
        case .greaterThan40: return 40
        case .greaterThan50: return 50
        case .greaterThan60: return 60
        case .greaterThan80: return 80
        case .greaterThan100: return 100
        default: return nil
        }
    }
}

// MARK: - Filter Success Rate Options (for Recent successful trades)
enum FilterSuccessRateOption: String, CaseIterable, Codable {
    case none = "---"
    case tenOutOfTen = "10 out of 10"
    case atLeast9OutOf10 = "At least 9 out of 10"
    case atLeast8OutOf10 = "At least 8 out of 10"
    case atLeast7OutOf10 = "At least 7 out of 10"
    case atLeast6OutOf10 = "At least 6 out of 10"
    case twentyOutOf20 = "20 out of 20"
    case atLeast18OutOf20 = "At least 18 out of 20"
    case atLeast16OutOf20 = "At least 16 out of 20"
    case atLeast14OutOf20 = "At least 14 out of 20"
    case atLeast12OutOf20 = "At least 12 out of 20"
    case last8Days = "Of last 8 days"
    case last2Weeks = "Of last 2 weeks"
    case lastMonth = "Of last month"
    case last2Months = "Of last 2 month"
    case last3Months = "Of last 3 month"
    case last12Months = "Of last 12 month"

    var displayName: String { rawValue }

    var requiredSuccessCount: Int? {
        switch self {
        case .tenOutOfTen: return 10
        case .atLeast9OutOf10: return 9
        case .atLeast8OutOf10: return 8
        case .atLeast7OutOf10: return 7
        case .atLeast6OutOf10: return 6
        case .twentyOutOf20: return 20
        case .atLeast18OutOf20: return 18
        case .atLeast16OutOf20: return 16
        case .atLeast14OutOf20: return 14
        case .atLeast12OutOf20: return 12
        default: return nil
        }
    }

    var totalTrades: Int? {
        switch self {
        case .tenOutOfTen, .atLeast9OutOf10, .atLeast8OutOf10, .atLeast7OutOf10, .atLeast6OutOf10: return 10
        case .twentyOutOf20, .atLeast18OutOf20, .atLeast16OutOf20, .atLeast14OutOf20, .atLeast12OutOf20: return 20
        default: return nil
        }
    }

    var timePeriod: TimePeriod? {
        switch self {
        case .last8Days: return .days(8)
        case .last2Weeks: return .weeks(2)
        case .lastMonth: return .months(1)
        case .last2Months: return .months(2)
        case .last3Months: return .months(3)
        case .last12Months: return .months(12)
        default: return nil
        }
    }
}







