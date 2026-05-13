import Combine
import Foundation

// MARK: - Order Calculation Utility
/// Centralized utility for order calculations to eliminate DRY violations
/// Provides consistent price calculation, cost estimation, and German number parsing
struct OrderCalculationUtility {

    // MARK: - Price Calculation

    /// Calculates the effective price for an order based on mode and limit
    /// - Parameters:
    ///   - orderMode: The order mode (market or limit)
    ///   - limitText: The limit price as text (German format: "12,50")
    ///   - marketPrice: The current market price
    /// - Returns: The effective price to use for calculations
    static func calculateEffectivePrice(
        orderMode: OrderMode,
        limitText: String,
        marketPrice: Double
    ) -> Double {
        switch orderMode {
        case .market:
            return marketPrice
        case .limit:
            return self.parseGermanPrice(limitText) ?? marketPrice
        }
    }

    /// Parses German formatted price text to Double
    /// - Parameter priceText: German format price (e.g., "12,50" or "1.234,56")
    /// - Returns: Parsed price as Double, or nil if invalid
    static func parseGermanPrice(_ priceText: String) -> Double? {
        guard !priceText.isEmpty else { return nil }

        // Validate German format: only numbers, dots (thousands), and exactly one comma (decimal)
        let isValidFormat = priceText.allSatisfy { $0.isNumber || $0 == "," || $0 == "." } &&
            priceText.filter { $0 == "," }.count <= 1 &&
            !priceText.hasPrefix(",") &&
            !priceText.hasSuffix(",")

        guard isValidFormat else { return nil }

        // Convert German format to English format for Double parsing
        // Remove thousand separators (dots) and replace decimal separator (comma) with dot
        let normalizedText = priceText
            .replacingOccurrences(of: ".", with: "") // Remove thousand separators
            .replacingOccurrences(of: ",", with: ".") // Replace decimal separator

        return Double(normalizedText)
    }

    // MARK: - Quantity Parsing

    /// Parses German formatted quantity text to integer
    /// - Parameter quantityText: German format quantity (e.g., "1.000" or "500")
    /// - Returns: Parsed quantity as integer
    static func parseGermanQuantity(_ quantityText: String) -> Int {
        // Remove dots (German thousand separators) and convert to integer
        let numericString = quantityText.replacingOccurrences(of: ".", with: "")
        return Int(numericString) ?? 0
    }

    /// Formats quantity as German localized string
    /// - Parameter quantity: The quantity as integer
    /// - Returns: German formatted string (e.g., "1.000")
    static func formatGermanQuantity(_ quantity: Int) -> String {
        let formatter = NumberFormatter.localizedIntegerFormatter
        return formatter.string(from: NSNumber(value: quantity)) ?? "\(quantity)"
    }

    // MARK: - Cost/Proceeds Calculation

    /// Calculates estimated cost for buy orders
    /// - Parameters:
    ///   - quantity: The quantity as Double
    ///   - orderMode: The order mode
    ///   - limitText: The limit price text
    ///   - marketPrice: The current market price
    /// - Returns: Estimated cost
    static func calculateEstimatedCost(
        quantity: Double,
        orderMode: OrderMode,
        limitText: String,
        marketPrice: Double
    ) -> Double {
        let effectivePrice = self.calculateEffectivePrice(
            orderMode: orderMode,
            limitText: limitText,
            marketPrice: marketPrice
        )
        return quantity * effectivePrice
    }

    /// Calculates estimated proceeds for sell orders
    /// - Parameters:
    ///   - quantity: The quantity as integer
    ///   - orderMode: The order mode
    ///   - limitText: The limit price text
    ///   - marketPrice: The current market price
    /// - Returns: Estimated proceeds
    static func calculateEstimatedProceeds(
        quantity: Int,
        orderMode: OrderMode,
        limitText: String,
        marketPrice: Double
    ) -> Double {
        let effectivePrice = self.calculateEffectivePrice(
            orderMode: orderMode,
            limitText: limitText,
            marketPrice: marketPrice
        )
        return Double(quantity) * effectivePrice
    }

    // MARK: - Validation

    /// Validates German price format
    /// - Parameter priceText: The price text to validate
    /// - Returns: True if valid German price format
    static func isValidGermanPrice(_ priceText: String) -> Bool {
        guard !priceText.isEmpty else { return false }

        return priceText.allSatisfy { $0.isNumber || $0 == "," || $0 == "." } &&
            priceText.filter { $0 == "," }.count <= 1 &&
            !priceText.hasPrefix(",") &&
            !priceText.hasSuffix(",")
    }

    /// Validates German quantity format
    /// - Parameter quantityText: The quantity text to validate
    /// - Returns: True if valid German quantity format
    static func isValidGermanQuantity(_ quantityText: String) -> Bool {
        guard !quantityText.isEmpty else { return false }

        return quantityText.allSatisfy { $0.isNumber || $0 == "." } &&
            !quantityText.hasPrefix(".") &&
            !quantityText.hasSuffix(".")
    }
}

// MARK: - Order Mode Enum
// Note: OrderMode enum is defined in NewBuyOrderViewModel.swift to avoid duplication

// MARK: - Combine Publishers Extension
/// Extension to provide consistent Combine publisher setup for order calculations
extension Publishers {

    /// Creates a publisher that calculates estimated cost/proceeds when order parameters change
    /// - Parameters:
    ///   - quantityText: Publisher for quantity text
    ///   - orderMode: Publisher for order mode
    ///   - limitText: Publisher for limit text
    ///   - marketPrice: Publisher for market price
    ///   - isSellOrder: Whether this is a sell order (affects calculation method)
    /// - Returns: Publisher that emits calculated cost/proceeds
    static func orderCalculation(
        quantityText: AnyPublisher<String, Never>,
        orderMode: AnyPublisher<OrderMode, Never>,
        limitText: AnyPublisher<String, Never>,
        marketPrice: AnyPublisher<Double, Never>,
        isSellOrder: Bool = false
    ) -> AnyPublisher<Double, Never> {
        Publishers.CombineLatest4(quantityText, orderMode, limitText, marketPrice)
            .debounce(for: .milliseconds(50), scheduler: RunLoop.main)
            .map { quantityText, orderMode, limitText, marketPrice in
                if isSellOrder {
                    let quantity = OrderCalculationUtility.parseGermanQuantity(quantityText)
                    return OrderCalculationUtility.calculateEstimatedProceeds(
                        quantity: quantity,
                        orderMode: orderMode,
                        limitText: limitText,
                        marketPrice: marketPrice
                    )
                } else {
                    let quantity = Double(OrderCalculationUtility.parseGermanQuantity(quantityText))
                    return OrderCalculationUtility.calculateEstimatedCost(
                        quantity: quantity,
                        orderMode: orderMode,
                        limitText: limitText,
                        marketPrice: marketPrice
                    )
                }
            }
            .eraseToAnyPublisher()
    }
}
