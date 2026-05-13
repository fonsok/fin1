import Foundation

/// Service to generate consistent market prices for underlying assets
/// This ensures that the displayed price in MarketDataRow matches the basePrice used in MockDataGenerator
final class MarketPriceService {

    /// Generate deterministic market price for an underlying asset
    /// This price will be used both for display and for warrant calculations
    static func getMarketPrice(for underlyingAsset: String) -> Double {
        // Generate deterministic market data based on underlyingAsset for consistency
        let seed = underlyingAsset.hash
        var rng = Int(truncatingIfNeeded: seed)
        rng = abs(rng == .min ? 0 : rng)

        // Generate price based on underlyingAsset type
        let price: Double
        switch underlyingAsset {
        case "DAX", "MDAX", "Dow Jones", "S&P 500", "NASDAQ 100", "Euro Stoxx 50", "FTSE 100", "CAC 40", "SMI":
            // Index prices (higher values) - matches MarketDataRow logic
            price = Double((rng % 4_000_000) + 1_000_000) / 100.0 // 10.000,00 - 50.000,00
        case "Apple", "Microsoft", "Tesla":
            // Stock prices (medium values) - matches MarketDataRow logic
            price = Double((rng % 20_000) + 10_000) / 100.0 // 100.00 - 300.00
        case "BMW":
            // BMW stock price - matches MarketDataRow logic
            price = Double((rng % 5_000) + 5_000) / 100.0 // 50.00 - 100.00
        case "Gold", "Silber":
            // Commodity prices - matches MarketDataRow logic
            price = Double((rng % 10_000) + 10_000) / 100.0 // 100.00 - 200.00
        case "USD/JPY", "EUR/USD", "GBP/USD":
            // Currency prices - matches MarketDataRow logic
            price = Double((rng % 5_000) + 10_000) / 100.0 // 100.00 - 150.00
        default:
            price = 150.00
        }

        return price
    }

    /// Generate market data (price, change, time, market) for display
    static func getMarketData(for underlyingAsset: String) -> MarketData {
        let price = self.getMarketPrice(for: underlyingAsset)

        // Generate percentage change
        let seed = underlyingAsset.hash
        var rng = Int(truncatingIfNeeded: seed)
        rng = abs(rng == .min ? 0 : rng)

        let changePercent = Double((rng / 7) % 500) / 100.0 // 0.00 - 5.00
        let isPositive = (rng % 2) == 0
        let changeStr = String(format: "%@%.2f", isPositive ? "+ " : "- ", changePercent).replacingOccurrences(of: ".", with: ",")

        // Format price with German locale
        let priceStr = NumberFormatter.localizedDecimalFormatter.string(for: price) ?? "0,00"

        // Static time and market for now
        let timeStr = "15:30"
        let marketStr = "Xetra"

        return MarketData(price: priceStr, change: changeStr, time: timeStr, market: marketStr)
    }
}

struct MarketData {
    let price: String
    let change: String
    let time: String
    let market: String
}
