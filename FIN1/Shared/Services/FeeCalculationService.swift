import Foundation

// MARK: - Fee Calculation Service

/// Centralized service for calculating trading fees
final class FeeCalculationService {

    // MARK: - Public Methods

    /// Calculates total fees for an order amount
    /// - Parameter orderAmount: The order amount in EUR
    /// - Returns: Total fees (order fee + exchange fee + foreign costs)
    static func calculateTotalFees(for orderAmount: Double) -> Double {
        let orderFee = calculateOrderFee(for: orderAmount)
        let exchangeFee = calculateExchangeFee(for: orderAmount)
        let foreignCosts = CalculationConstants.FeeRates.foreignCosts

        return orderFee + exchangeFee + foreignCosts
    }

    /// Calculates order fee based on order amount
    /// - Parameter orderAmount: The order amount in EUR
    /// - Returns: Order fee amount (0.5% of order amount, min €5, max €50)
    static func calculateOrderFee(for orderAmount: Double) -> Double {
        let rate = orderAmount * CalculationConstants.FeeRates.orderFeeRate
        return max(
            CalculationConstants.FeeRates.orderFeeMinimum,
            min(CalculationConstants.FeeRates.orderFeeMaximum, rate)
        )
    }

    /// Calculates exchange fee based on order amount
    /// - Parameter orderAmount: The order amount in EUR
    /// - Returns: Exchange fee amount (0.1% of order amount, min €1, max €20)
    static func calculateExchangeFee(for orderAmount: Double) -> Double {
        let rate = orderAmount * CalculationConstants.FeeRates.exchangeFeeRate
        return max(
            CalculationConstants.FeeRates.exchangeFeeMinimum,
            min(CalculationConstants.FeeRates.exchangeFeeMaximum, rate)
        )
    }

    /// Calculates foreign costs (fixed amount)
    /// - Returns: Foreign costs amount (€1.50)
    static func calculateForeignCosts() -> Double {
        return CalculationConstants.FeeRates.foreignCosts
    }

    /// Creates a detailed breakdown of all fees
    /// - Parameter orderAmount: The order amount in EUR
    /// - Returns: Array of fee details with names and amounts
    static func createFeeBreakdown(for orderAmount: Double) -> [FeeDetail] {
        return [
            FeeDetail(
                name: "Ordergebühr",
                amount: calculateOrderFee(for: orderAmount)
            ),
            FeeDetail(
                name: "Handelsplatzgebühr",
                amount: calculateExchangeFee(for: orderAmount)
            ),
            FeeDetail(
                name: "Fremdkostenpauschale",
                amount: calculateForeignCosts()
            )
        ]
    }
}

// MARK: - Fee Detail Model

/// Represents a single fee component
struct FeeDetail {
    let name: String
    let amount: Double
}
