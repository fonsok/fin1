import Foundation

extension CalculationConstants {
    struct Account {
        static let initialBalance: Double = 0.0
        static let initialInvestorBalance: Double = 0.0
        static let minimumCashReserve: Double = 20.0
    }

    struct Investment {
        static let defaultAmount: Double = 3_000.0
        static let fallbackMinimumInvestmentAmount: Double = 20.0
        static let fallbackMaximumInvestmentAmount: Double = 100_000.0
    }

    struct TraderBuyOrder {
        static let fallbackMinimumBuyOrderAmount: Double = 300.0
    }
}
