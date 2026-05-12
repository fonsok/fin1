import Foundation
import Combine

// MARK: - Filter Service Protocol
// CRITICAL: This protocol defines the contract for ALL securities search filters
// Any changes to this protocol must be thoroughly tested to ensure filter logic remains intact
@MainActor
protocol SearchFilterServiceProtocol: ObservableObject {
    // Core filters that determine search results
    var category: String { get set }           // Warrant, Stock, etc.
    var underlyingAsset: String { get set }    // FTSE 100, CAC 40, DAX, etc.
    var direction: SecuritiesSearchView.Direction { get set }  // Call, Put

    // Advanced filters for refined search
    var strikePriceGap: String? { get set } // At the Money, Out of the Money, etc.
    var remainingTerm: String? { get set }     // < 4 Wo., > 1 Jahr, etc.
    var issuer: String? { get set }            // Société Générale, Goldman Sachs, etc.
    var omega: String? { get set }             // > 10, < 5, etc.

    // Removed warrantDetailsViewModel - ViewModels should be managed by Views, not Services

    var filtersPublisher: AnyPublisher<SearchFilters, Never> { get }

    func getCurrentFilters() -> SearchFilters
    func getFilterDescription() -> String
    func getUnderlyingAssetSubtitle() -> String
    func getUnderlyingAssetMarketData() -> SecuritiesSearchViewModel.MarketData
}

// MARK: - Filter Service Implementation
// CRITICAL: This class manages ALL securities search filter state
// Any changes to filter logic here must be thoroughly tested to prevent regressions
@MainActor
final class SearchFilterService: SearchFilterServiceProtocol {
    // CRITICAL: Core filter properties - these determine search results
    @Published var category: String = "Warrant"  // Default to Warrant
    @Published var underlyingAsset: String = "DAX" {         // Default to DAX
        didSet {
            print("🔍 DEBUG: SearchFilterService.underlyingAsset changed from '\(oldValue)' to '\(underlyingAsset)'")
        }
    }
    @Published var direction: SecuritiesSearchView.Direction = .call {  // Default to Call
        didSet {
            print("🔍 DEBUG: SearchFilterService.direction changed from '\(oldValue)' to '\(direction)'")
        }
    }

    // CRITICAL: Advanced filter properties - these refine search results
    @Published var strikePriceGap: String? = "At the Money"  // Default to At the Money
    @Published var remainingTerm: String?            // No default limit for better testing
    @Published var issuer: String?                      // No default (optional)
    @Published var omega: String?                         // No default (optional)
    // Removed ViewModel from service - ViewModels should be managed by Views, not Services

    private nonisolated(unsafe) var cancellables = Set<AnyCancellable>()

    init() {
        setupBindings()
    }

    deinit {
        cancellables.removeAll()
        print("🧹 SearchFilterService deallocated")
    }

    // MARK: - Publishers

    var filtersPublisher: AnyPublisher<SearchFilters, Never> {
        Publishers.CombineLatest3(
            Publishers.CombineLatest3($category, $underlyingAsset, $direction),
            Publishers.CombineLatest3($strikePriceGap, $remainingTerm, $issuer),
            $omega
        )
        .map { first, second, omega in
            SearchFilters(
                category: first.0,
                underlyingAsset: first.1,
                direction: first.2,
                strikePriceGap: second.0,
                remainingTerm: second.1,
                issuer: second.2,
                omega: omega
            )
        }
        .eraseToAnyPublisher()
    }

    // MARK: - Public Interface

    func getCurrentFilters() -> SearchFilters {
        print("🔍 DEBUG: SearchFilterService.getCurrentFilters() - underlyingAsset = '\(underlyingAsset)'")
        return SearchFilters(
            category: category,
            underlyingAsset: underlyingAsset,
            direction: direction,
            strikePriceGap: strikePriceGap,
            remainingTerm: remainingTerm,
            issuer: issuer,
            omega: omega
        )
    }

    func getFilterDescription() -> String {
        var filters: [String] = []

        // Category filter
        if !category.isEmpty {
            filters.append("Category: \(category)")
        }

        // Direction filter
        if category == "Warrants" {
            filters.append("Direction: \(direction.rawValue)")
        }

        // Underlying Asset filter
        if !underlyingAsset.isEmpty {
            filters.append("Underlying Asset: \(underlyingAsset)")
        }

        // Issuer filter
        if let selectedIssuer = issuer, selectedIssuer != "All" {
            filters.append("Issuer: \(selectedIssuer)")
        }

        // Remaining Term filter
        if let selectedTerm = remainingTerm {
            filters.append("Remaining Term: \(selectedTerm)")
        }

        // Strike Price Gap filter
        if let selectedGap = strikePriceGap {
            filters.append("Strike Price Gap: \(selectedGap)")
        }

        // Omega filter
        if let selectedOmega = omega, selectedOmega != "All" {
            filters.append("Omega: \(selectedOmega)")
        }

        return filters.isEmpty ? "No active filters" : filters.joined(separator: ", ")
    }

    func getUnderlyingAssetSubtitle() -> String {
        // Map underlying asset to asset type based on the underlying asset categories
        let indices = ["DAX", "MDAX", "Dow Jones", "S&P 500", "NASDAQ 100", "Euro Stoxx 50", "FTSE 100", "CAC 40", "SMI"]
        let stocks = ["Apple", "BMW", "Tesla", "Microsoft"]
        let metals = ["Gold", "Silver"]
        let currencies = ["USD/JPY", "EUR/USD", "GBP/USD"]

        if indices.contains(underlyingAsset) {
            return "Index - 84690"
        } else if stocks.contains(underlyingAsset) {
            return "Stock - \(getStockCode(for: underlyingAsset))"
        } else if metals.contains(underlyingAsset) {
            return "Commodity - \(getMetalCode(for: underlyingAsset))"
        } else if currencies.contains(underlyingAsset) {
            return "Currency - \(getCurrencyCode(for: underlyingAsset))"
        } else {
            return "Index - 84690" // Default fallback
        }
    }

    func getUnderlyingAssetMarketData() -> SecuritiesSearchViewModel.MarketData {
        // Generate deterministic market data based on underlying asset for consistency
        let seed = underlyingAsset.hash
        var rng = Int(truncatingIfNeeded: seed)
        rng = abs(rng == .min ? 0 : rng)

        // Generate price based on underlying asset type
        let price: Double
        switch underlyingAsset {
        case "DAX", "MDAX", "Dow Jones", "S&P 500", "NASDAQ 100", "Euro Stoxx 50", "FTSE 100", "CAC 40", "SMI":
            // Index prices (higher values)
            price = Double((rng % 4000000) + 1000000) / 100.0 // 10.000,00 - 50.000,00
        case "Apple", "Microsoft", "Tesla":
            // Stock prices (medium values)
            price = Double((rng % 20000) + 10000) / 100.0 // 100.00 - 300.00
        case "BMW":
            // BMW stock price
            price = Double((rng % 5000) + 5000) / 100.0 // 50.00 - 100.00
        case "Gold", "Silver":
            // Commodity prices
            price = Double((rng % 10000) + 10000) / 100.0 // 100.00 - 200.00
        case "USD/JPY", "EUR/USD", "GBP/USD":
            // Currency prices
            price = Double((rng % 5000) + 10000) / 100.0 // 100.00 - 150.00
        default:
            price = 150.00
        }

        // Generate percentage change
        let changePercent = Double((rng / 7) % 500) / 100.0 // 0.00 - 5.00
        let isPositive = (rng % 2) == 0
        let changeStr = String(format: "%@%.2f", isPositive ? "+ " : "- ", changePercent).replacingOccurrences(of: ".", with: ",")

        // Format price with localized locale
        let priceStr = NumberFormatter.localizedDecimalFormatter.string(for: price) ?? "0,00"

        // Static time and market for now
        let timeStr = "15:30"
        let marketStr = "Xetra"

        return SecuritiesSearchViewModel.MarketData(price: priceStr, change: changeStr, time: timeStr, market: marketStr)
    }

    // MARK: - Private Methods

    private func setupBindings() {
        // No additional bindings needed - publishers are already set up
    }

    private func getStockCode(for underlyingAsset: String) -> String {
        switch underlyingAsset {
        case "Apple": return "AAPL"
        case "BMW": return "519000"
        case "Tesla": return "TSLA"
        case "Microsoft": return "MSFT"
        default: return "N/A"
        }
    }

    private func getMetalCode(for underlyingAsset: String) -> String {
        switch underlyingAsset {
        case "Gold": return "965515"
        case "Silver": return "965310"
        default: return "N/A"
        }
    }

    private func getCurrencyCode(for underlyingAsset: String) -> String {
        switch underlyingAsset {
        case "USD/JPY": return "965991"
        case "EUR/USD": return "965275"
        case "GBP/USD": return "965123"
        default: return "N/A"
        }
    }
}
