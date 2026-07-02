import Foundation

extension CalculationConstants {
    struct FeeRates {
        static let orderFeeRate: Double = 0.005
        static let orderFeeMinimum: Double = 5.0
        static let orderFeeMaximum: Double = 50.0
        static let exchangeFeeRate: Double = 0.001
        static let exchangeFeeMinimum: Double = 1.0
        static let exchangeFeeMaximum: Double = 20.0
        static let foreignCosts: Double = 1.50
        static let traderCommissionRate: Double = 0.05
        static let appCommissionRate: Double = 0.05
        static let investorCommissionRateTotal: Double = 0.1
        static let traderCommissionPercentage: String = "5%"
    }

    struct ServiceCharges {
        static let appServiceChargeRate: Double = 0.02
        static let appServiceChargePercentage: String = "2%"
    }
}
