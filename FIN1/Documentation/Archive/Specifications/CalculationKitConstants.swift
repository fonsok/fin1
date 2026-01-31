import Foundation

// MARK: - Constants

public struct CKCalculationConstants: Codable {
    public struct FeeRates: Codable {
        public let orderFeeRate: Double
        public let orderFeeMinimum: Double
        public let orderFeeMaximum: Double
        public let exchangeFeeRate: Double
        public let exchangeFeeMinimum: Double
        public let exchangeFeeMaximum: Double
        public let foreignCosts: Double
        public let traderCommissionRate: Double
    }

    public struct SecurityDenominations: Codable {
        public let allowed: [Int] // e.g., [1, 10, 100]
        public let minimumOrderAmount: Double?
    }

    public let feeRates: FeeRates
    public let securityDenominations: SecurityDenominations
}

public enum CKGuardMode {
    case strict
    case warning
    case disabled
}














