import Foundation

extension CalculationConstants {
    struct Limits {
        static let minimumTaxableProfit: Double = 0.0
        static let currencyDecimalPlaces: Int = 2
        static let percentageDecimalPlaces: Int = 1
    }

    struct PaymentLimits {
        static let minimumDeposit: Double = 10.0
        static let maximumDeposit: Double = 100_000.0
        static let minimumWithdrawal: Double = 10.0
        static let maximumWithdrawal: Double = 50_000.0
    }

    struct TransactionLimits {
        static let baseDailyLimit: Double = 10_000.0
        static let baseWeeklyLimit: Double = 50_000.0
        static let baseMonthlyLimit: Double = 200_000.0
    }
}
