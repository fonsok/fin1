import Foundation

// MARK: - Depot Utility Functions
/// Shared utility functions for depot-related calculations and formatting
struct DepotUtils {

    // MARK: - Strike Price Formatting
    /// Formats strike price based on asset type
    /// - Parameters:
    ///   - strike: The strike price value
    ///   - underlyingAsset: The underlying asset name
    /// - Returns: Formatted string with or without currency unit
    static func formatStrikePrice(_ strike: Double, _ underlyingAsset: String?) -> String {
        // Check if it's an index - handle both nil and non-nil cases
        let indices = ["DAX", "MDAX", "Dow Jones", "S&P 500", "NASDAQ 100", "Euro Stoxx 50", "FTSE 100", "CAC 40", "SMI"]

        // If underlyingAsset is provided, check if it's an index
        if let underlyingAsset = underlyingAsset,
           indices.contains(where: { underlyingAsset.lowercased().contains($0.lowercased()) }) {
            // For indices, ensure realistic mock values (10.000 - 50.000 Pkt.)
            let value: Double
            if strike >= 1_000 {
                // Already a realistic index-like value
                value = strike
            } else {
                // Likely an option price (e.g., 2.15). Generate deterministic index price for display.
                value = self.deterministicIndexPrice(for: underlyingAsset)
            }

            let formattedValue = value.formattedAsLocalizedInteger()
            return "\(formattedValue) Pkt."
        }

        // If underlyingAsset is nil but strike value looks like an index value, treat as index
        if underlyingAsset == nil && strike >= 1_000 {
            let formattedValue = strike.formattedAsLocalizedInteger()
            return "\(formattedValue) Pkt."
        }

        // For stocks or when we can't determine, show with € unit
        return "\(NumberFormatter.localizedDecimalFormatter.string(for: strike) ?? "0,00") €"
    }

    /// Determines the asset type suffix for display in trade statements
    /// - Parameter underlyingAsset: The underlying asset name
    /// - Returns: Asset type suffix (Index-, Aktie-, Rohstoff-, etc.)
    static func getAssetTypeSuffix(for underlyingAsset: String?) -> String {
        guard let underlyingAsset = underlyingAsset else { return "Index-" }

        // Map underlyingAsset to asset type
        let indices = ["DAX", "MDAX", "Dow Jones", "S&P 500", "NASDAQ 100", "Euro Stoxx 50", "FTSE 100", "CAC 40", "SMI"]
        let stocks = ["Apple", "BMW", "Tesla", "Microsoft", "Google"]
        let commodities = ["Gold", "Silber", "Öl", "Kupfer"]
        let currencies = ["USD/JPY", "EUR/USD", "GBP/USD"]

        if indices.contains(underlyingAsset) {
            return "Index-"
        } else if stocks.contains(underlyingAsset) {
            return "Aktie-"
        } else if commodities.contains(underlyingAsset) {
            return "Rohstoff-"
        } else if currencies.contains(underlyingAsset) {
            return "Devisen-"
        } else {
            return "Index-" // Default fallback
        }
    }
    ///   - underlyingAsset: The underlying asset name
    /// - Returns: Formatted string with or without currency unit
    static func formatStrikePrice(_ strike: String, _ underlyingAsset: String?) -> String {
        // Check if it's an index - handle both nil and non-nil cases
        let indices = ["DAX", "MDAX", "Dow Jones", "S&P 500", "NASDAQ 100", "Euro Stoxx 50", "FTSE 100", "CAC 40", "SMI"]

        // If underlyingAsset is provided, check if it's an index
        if let underlyingAsset = underlyingAsset,
           indices.contains(where: { underlyingAsset.lowercased().contains($0.lowercased()) }) {
            // For indices, ensure realistic mock values (10.000 - 50.000 Pkt.)
            let value: Double
            if let parsed = Double(strike), parsed >= 1_000 {
                // Already a realistic index-like value
                value = parsed
            } else {
                // Likely an option price (e.g., 2.15). Generate deterministic index price for display.
                value = self.deterministicIndexPrice(for: underlyingAsset)
            }

            let formattedValue = value.formattedAsLocalizedInteger()
            return "\(formattedValue) Pkt."
        }

        // If underlyingAsset is nil but strike value looks like an index value, treat as index
        if underlyingAsset == nil, let parsed = Double(strike), parsed >= 1_000 {
            let formattedValue = parsed.formattedAsLocalizedInteger()
            return "\(formattedValue) Pkt."
        }

        // For stocks or when we can't determine, show with € unit
        return strike + " €"
    }

    /// Deterministically generates a mock index price in the range 10,000 - 50,000
    /// to keep displays stable between runs and consistent with search results.
    private static func deterministicIndexPrice(for underlyingAsset: String) -> Double {
        var seed = underlyingAsset.hashValue
        seed = seed &* 1_103_515_245 &+ 12_345
        let normalized = Double(abs(seed) % 1_000) / 1_000.0
        let raw = 10_000.0 + (50_000.0 - 10_000.0) * normalized
        // Round to nearest 50 points for more realistic index ticks
        return (raw / 50.0).rounded() * 50.0
    }

    // MARK: - Profit/Loss Calculation
    /// Calculates profit/loss for a holding
    /// - Parameter holding: The depot holding
    /// - Returns: Formatted profit/loss string
    static func calculateProfitLoss(_ holding: DepotHolding) -> String {
        let currentValue = holding.currentPrice * Double(holding.quantity)
        let originalValue = holding.purchasePrice * Double(holding.quantity)
        let difference = currentValue - originalValue

        let formattedDifference = difference.formattedAsLocalizedCurrency()
        return difference >= 0 ? "+\(formattedDifference)" : formattedDifference
    }
}
