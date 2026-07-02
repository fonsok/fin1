import Foundation

extension CalculationConstants {
    struct SecurityDenominations {
        static let validDenominations: [Int] = [10, 20, 50, 100, 1_000]
        static let noDenomination: Int? = nil
        static let noMinimumOrderAmount: Double? = nil

        static func meetsMinimumOrderAmount(_ orderAmount: Double, minimumOrderAmount: Double?) -> Bool {
            guard let minimum = minimumOrderAmount, minimum > 0 else { return true }
            return orderAmount >= minimum
        }

        static func calculateMinimumQuantity(pricePerSecurity: Double, minimumOrderAmount: Double?) -> Int {
            guard let minimum = minimumOrderAmount, minimum > 0, pricePerSecurity > 0 else { return 0 }
            return Int(ceil(minimum / pricePerSecurity))
        }

        static func roundDownToDenomination(_ quantity: Int, denominations: [Int] = validDenominations) -> Int {
            guard quantity > 0 else { return 0 }
            guard let smallestDenomination = denominations.min(), quantity >= smallestDenomination else { return 0 }

            for denomination in denominations.sorted(by: >) {
                let rounded = (quantity / denomination) * denomination
                if rounded > 0 { return rounded }
            }
            return 0
        }

        static func isValidDenomination(_ quantity: Int, denominations: [Int] = validDenominations) -> Bool {
            guard quantity > 0 else { return false }
            return denominations.contains { quantity % $0 == 0 }
        }

        static func defaultDenomination(forSubscriptionRatio subscriptionRatio: Double) -> Int? {
            guard subscriptionRatio > 0 else { return self.noDenomination }

            let unitsPerShare: Double = subscriptionRatio >= 1 ? subscriptionRatio : 1.0 / subscriptionRatio

            if unitsPerShare >= 100 { return 100 }
            if unitsPerShare >= 10 { return 10 }
            return self.noDenomination
        }
    }
}
