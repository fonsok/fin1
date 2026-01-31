import Foundation
import SwiftUI

// MARK: - Account and Personal Information Enums

enum AccountType: String, CaseIterable, Codable {
    case individual
    case company

    var displayName: String {
        switch self {
        case .individual:
            return "Einzelperson"
        case .company:
            return "Firma"
        }
    }
}

enum Salutation: String, CaseIterable, Codable {
    case mr
    case mrs
    case ms
    case dr
    case prof

    var displayName: String {
        switch self {
        case .mr:
            return "Herr"
        case .mrs:
            return "Frau"
        case .ms:
            return "---"
        case .dr:
            return "Dr."
        case .prof:
            return "Prof."
        }
    }
}

enum UserRole: String, CaseIterable, Codable {
    case investor
    case trader
    case admin
    case customerService
    case other

    var displayName: String {
        switch self {
        case .investor: return "Investor"
        case .trader: return "Trader"
        case .admin: return "Admin"
        case .customerService: return "Kundenberater"
        case .other: return "Other"
        }
    }

    /// Icon name for the role (SF Symbol)
    var icon: String {
        switch self {
        case .admin: return "shield.lefthalf.filled"
        case .investor: return "chart.pie.fill"
        case .trader: return "chart.bar.fill"
        case .customerService: return "headphones.circle.fill"
        case .other: return "person.fill"
        }
    }

    /// Whether this role has elevated privileges (admin or customer service)
    var hasElevatedPrivileges: Bool {
        switch self {
        case .admin, .customerService:
            return true
        default:
            return false
        }
    }

    /// Whether this role can view customer data
    var canViewCustomerData: Bool {
        switch self {
        case .admin, .customerService:
            return true
        default:
            return false
        }
    }
}

enum EmploymentStatus: String, CaseIterable, Codable {
    case employed = "employed"
    case selfEmployed = "self_employed"
    case unemployed = "unemployed"
    case student = "student"
    case retired = "retired"

    var displayName: String {
        switch self {
        case .employed: return "Employed"
        case .selfEmployed: return "Self-Employed"
        case .unemployed: return "Unemployed"
        case .student: return "Student"
        case .retired: return "Retired"
        }
    }
}

// MARK: - Financial Information Enums

enum IncomeRange: String, CaseIterable, Codable {
    case low = "low"
    case lowMiddle = "low_middle"
    case middle = "middle"
    case highMiddle = "high_middle"
    case high = "high"
    case veryHigh = "very_high"

    var displayName: String {
        switch self {
        case .low:
            return "Under 25.000"
        case .lowMiddle:
            return "25.000 - 50.000"
        case .middle:
            return "50.000 - 100.000"
        case .highMiddle:
            return "100.000 - 200.000"
        case .high:
            return "200.000 - 500.000"
        case .veryHigh:
            return "More than 500.000"
        }
    }
}

enum CashAndLiquidAssets: String, CaseIterable, Codable {
    case oneMillionPlus = "one_million_plus"
    case fiveHundredKToOneMillion = "five_hundred_k_to_one_million"
    case twoHundredKToFiveHundredK = "two_hundred_k_to_five_hundred_k"
    case fiftyKToTwoHundredK = "fifty_k_to_two_hundred_k"
    case tenKToFiftyK = "ten_k_to_fifty_k"
    case lessThan10k = "less_than_10k"

    var displayName: String {
        switch self {
        case .oneMillionPlus:
            return "1.000.000 +"
        case .fiveHundredKToOneMillion:
            return "500.000 - 1.000.000"
        case .twoHundredKToFiveHundredK:
            return "200.000 - 500.000"
        case .fiftyKToTwoHundredK:
            return "50.000 - 200.000"
        case .tenKToFiftyK:
            return "10.000 - 50.000"
        case .lessThan10k:
            return "Weniger als 10.000"
        }
    }
}

enum AssetType: String, CaseIterable, Codable {
    case privateAssets = "private_assets"
    case businessAssets = "business_assets"

    var displayName: String {
        switch self {
        case .privateAssets: return "Privatvermögen"
        case .businessAssets: return "Betriebsvermögen"
        }
    }
}

// MARK: - Identification and Verification Enums

enum IdentificationType: String, CaseIterable, Codable {
    case passport = "passport"
    case idCard = "id_card"
    case postident = "postident"

    var displayName: String {
        switch self {
        case .passport:
            return "Reisepass"
        case .idCard:
            return "Personalausweis"
        case .postident:
            return "Postident"
        }
    }
}

// MARK: - Investment Experience Enums

enum StocksTransactionCount: String, CaseIterable, Codable {
    case oneToTen = "1-10"
    case tenToFifty = "10-50"
    case fiftyPlus = "50+"
    case none = "None"

    var displayName: String {
        switch self {
        case .oneToTen: return "1 - 10"
        case .tenToFifty: return "10 - 50"
        case .fiftyPlus: return "50+"
        case .none: return "None"
        }
    }
}

enum ETFsTransactionCount: String, CaseIterable, Codable {
    case oneToTen = "1-10"
    case tenToTwenty = "10-20"
    case moreThanTwenty = "More than 20"
    case none = "None"

    var displayName: String {
        switch self {
        case .oneToTen: return "1 - 10"
        case .tenToTwenty: return "10 - 20"
        case .moreThanTwenty: return "More than 20"
        case .none: return "None"
        }
    }
}

enum DerivativesTransactionCount: String, CaseIterable, Codable {
    case oneToTen = "1-10"
    case tenToFifty = "10-50"
    case fiftyPlus = "50+"
    case none = "None"

    var displayName: String {
        switch self {
        case .oneToTen: return "1 - 10"
        case .tenToFifty: return "10 - 50"
        case .fiftyPlus: return "50+"
        case .none: return "None"
        }
    }
}

enum InvestmentAmount: String, CaseIterable, Codable {
    case hundredToTenThousand = "hundred_to_ten_thousand"
    case tenThousandToHundredThousand = "ten_thousand_to_hundred_thousand"
    case hundredThousandToMillion = "hundred_thousand_to_million"
    case moreThanMillion = "more_than_million"

    var displayName: String {
        switch self {
        case .hundredToTenThousand: return "100€ - 10.000€"
        case .tenThousandToHundredThousand: return "10.000€ - 100.000€"
        case .hundredThousandToMillion: return "100.000€ - 1.000.000€"
        case .moreThanMillion: return "More than 1.000.000€"
        }
    }

    var riskScore: Int {
        switch self {
        case .hundredToTenThousand: return 0
        case .tenThousandToHundredThousand: return 1
        case .hundredThousandToMillion: return 2
        case .moreThanMillion: return 4
        }
    }
}

enum DerivativesInvestmentAmount: String, CaseIterable, Codable {
    case zeroToThousand = "zero_to_thousand"
    case thousandToTenThousand = "thousand_to_ten_thousand"
    case tenThousandToHundredThousand = "ten_thousand_to_hundred_thousand"
    case moreThanHundredThousand = "more_than_hundred_thousand"

    var displayName: String {
        switch self {
        case .zeroToThousand: return "0€ - 1.000€"
        case .thousandToTenThousand: return "1.000€ - 10.000€"
        case .tenThousandToHundredThousand: return "10.000€ - 100.000€"
        case .moreThanHundredThousand: return "More than 100.000€"
        }
    }

    var riskScore: Int {
        switch self {
        case .zeroToThousand: return 0
        case .thousandToTenThousand: return 1
        case .tenThousandToHundredThousand: return 2
        case .moreThanHundredThousand: return 4
        }
    }
}

enum HoldingPeriod: String, CaseIterable, Codable {
    case minutesToHours = "minutes_to_hours"
    case daysToWeeks = "days_to_weeks"
    case monthsToYears = "months_to_years"

    var displayName: String {
        switch self {
        case .minutesToHours: return "Minutes to hours"
        case .daysToWeeks: return "Days to weeks"
        case .monthsToYears: return "Months to years"
        }
    }
}

enum DesiredReturn: String, CaseIterable, Codable {
    case atLeastTenPercent = "at_least_10_percent"
    case atLeastFiftyPercent = "at_least_50_percent"
    case atLeastHundredPercent = "at_least_100_percent"

    var displayName: String {
        switch self {
        case .atLeastTenPercent: return "At least 10%"
        case .atLeastFiftyPercent: return "At least 50%"
        case .atLeastHundredPercent: return "At least 100%"
        }
    }
}

// MARK: - Risk Class Enum

enum RiskClass: Int, CaseIterable, Codable {
    case riskClass1 = 1
    case riskClass2 = 2
    case riskClass3 = 3
    case riskClass4 = 4
    case riskClass5 = 5
    case riskClass6 = 6
    case riskClass7 = 7

    var displayName: String {
        switch self {
        case .riskClass1: return "Risikoklasse 1"
        case .riskClass2: return "Risikoklasse 2"
        case .riskClass3: return "Risikoklasse 3"
        case .riskClass4: return "Risikoklasse 4"
        case .riskClass5: return "Risikoklasse 5"
        case .riskClass6: return "Risikoklasse 6"
        case .riskClass7: return "Risikoklasse 7"
        }
    }

    var shortName: String {
        switch self {
        case .riskClass1: return "1"
        case .riskClass2: return "2"
        case .riskClass3: return "3"
        case .riskClass4: return "4"
        case .riskClass5: return "5"
        case .riskClass6: return "6"
        case .riskClass7: return "7"
        }
    }

    var description: String {
        switch self {
        case .riskClass1: return "Focus on value preservation and security, low price fluctuations, capital loss unlikely"
        case .riskClass2: return "Mostly investments in longer-term government bonds from industrialized countries"
        case .riskClass3: return "Security still important, but risk increases slightly with possible partial capital loss"
        case .riskClass4: return "Balanced mix of security and return, more risk tolerance required"
        case .riskClass5: return "Growth-oriented investments with significantly higher risk and return opportunities"
        case .riskClass6: return "Very speculative investments with large value fluctuations and possible total loss"
        case .riskClass7: return "Very high risk, total capital loss possible, only for experienced investors"
        }
    }

    var examples: String {
        switch self {
        case .riskClass1: return "Money market funds, savings accounts, fixed deposits, savings bonds, building society contracts"
        case .riskClass2: return "Government bond funds with high credit ratings"
        case .riskClass3: return "Bonds with good credit ratings, mixed funds"
        case .riskClass4: return "Globally diversified stock funds, ETFs"
        case .riskClass5: return "Country stock funds, currency bonds with medium credit ratings, OTC stocks"
        case .riskClass6: return "Warrants, dividend funds, CFDs, junk bonds, futures"
        case .riskClass7: return "Hedge funds, sector funds, emerging market funds, cryptocurrencies, leveraged products"
        }
    }

    var color: Color {
        switch self {
        case .riskClass1, .riskClass2: return .green
        case .riskClass3, .riskClass4: return .orange
        case .riskClass5, .riskClass6, .riskClass7: return .red
        }
    }

    var isHighRisk: Bool {
        return self.rawValue >= 5
    }

    var requiresManualSelection: Bool {
        return self == .riskClass7
    }
}
