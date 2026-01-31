import Foundation
import SwiftUI
import Combine

// MARK: - Search Result Card View Model
/// ViewModel for SearchResultCard to handle all business logic, data processing, and formatting
@MainActor
final class SearchResultCardViewModel: ObservableObject {
    // MARK: - Dependencies
    private let result: SearchResult
    private let directionLabel: String
    let warrantDetailsViewModel: WarrantDetailsViewModel
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Published Properties

    /// Controls whether additional details are shown
    @Published var showAdditionalDetails: Bool = false

    // MARK: - Initialization

    init(result: SearchResult, directionLabel: String, warrantDetailsViewModel: WarrantDetailsViewModel) {
        self.result = result
        self.directionLabel = directionLabel
        self.warrantDetailsViewModel = warrantDetailsViewModel

        // Observe changes to warrantDetailsViewModel to trigger tiles recomputation
        warrantDetailsViewModel.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    // MARK: - Computed Properties

    /// Generates tiles based on warrant details selection and expansion state
    var tiles: [TileData] {
        print("🔍 DEBUG: SearchResultCardViewModel - result.direction: \(result.direction ?? "nil"), directionLabel: \(directionLabel)")

        var allTiles: [TileData] = []

        // Always show: WKN, Basiswert, Kategorie, Richtung
        allTiles.append(TileData(title: "WKN", value: result.wkn))
        allTiles.append(TileData(title: "Basiswert", value: result.underlyingAsset ?? "N/A"))
        allTiles.append(TileData(title: "Kategorie", value: getDerivateCategory(result.category ?? (result.direction ?? "Stock"))))
        allTiles.append(TileData(title: "Richtung", value: directionLabel))

        // Conditionally show based on WarrantDetailsViewModel
        if isDetailSelected("Bewertungstag") {
            allTiles.append(TileData(title: "Bewertungstag", value: result.valuationDate))
        }

        if isDetailSelected("Strike Price") {
            allTiles.append(TileData(title: "Strike Price", value: DepotUtils.formatStrikePrice(result.strike, result.underlyingAsset)))
        }

        if isDetailSelected("Brief-Kurs") {
            allTiles.append(TileData(title: "Brief-Kurs (Ask)", value: formatBriefkurs(result.askPrice)))
        }

        if isDetailSelected("Emittent") {
            allTiles.append(TileData(title: "Emittent", value: getEmittentFromWKN(result.wkn)))
        }

        // Additional details (shown when expanded)
        if showAdditionalDetails {
            if isDetailSelected("Geld-Kurs") {
                allTiles.append(TileData(title: "Geld-Kurs (Bid)", value: formatGeldkurs(getMockGeldkurs())))
            }

            if isDetailSelected("Implizite Volatilität") {
                allTiles.append(TileData(title: "Implizite Volatilität", value: getMockImpliziteVolatilitaet()))
            }

            if isDetailSelected("Omega") {
                allTiles.append(TileData(title: "Omega", value: getMockOmega()))
            }

            if isDetailSelected("Subscription ratio") {
                allTiles.append(TileData(title: "Subscriptionratio", value: getMockSubscriptionratio()))
            }

            if isDetailSelected("Ausübung") {
                allTiles.append(TileData(title: "Ausübung", value: getMockAusuebung()))
            }
        }

        return allTiles
    }

    /// Formats the ask price (Brief-Kurs) for display
    var formattedAskPrice: String {
        formatBriefkurs(result.askPrice)
    }

    // MARK: - Public Methods

    /// Formats the bid price (Geld-Kurs) for display
    func formattedBidPrice(_ geldkurs: String?) -> String {
        formatGeldkurs(geldkurs)
    }

    /// Toggles the additional details visibility
    func toggleAdditionalDetails() {
        showAdditionalDetails.toggle()
    }

    // MARK: - Private Helper Methods

    /// Checks if a detail item is selected in the warrant details view model
    private func isDetailSelected(_ itemName: String) -> Bool {
        return warrantDetailsViewModel.items.first(where: { $0.name == itemName })?.isSelected ?? false
    }

    // MARK: - Formatting Methods

    private func formatBriefkurs(_ briefkurs: String) -> String {
        // Convert German decimal format (comma) to Double, then format as localized currency
        let normalizedString = briefkurs.replacingOccurrences(of: ",", with: ".")
        if let value = Double(normalizedString) {
            return value.formattedAsLocalizedCurrency()
        }
        return "\(briefkurs) €"
    }

    private func formatGeldkurs(_ geldkurs: String?) -> String {
        guard let geldkurs = geldkurs else { return "N/A" }
        // Convert German decimal format (comma) to Double, then format as localized currency
        let normalizedString = geldkurs.replacingOccurrences(of: ",", with: ".")
        if let value = Double(normalizedString) {
            return value.formattedAsLocalizedCurrency()
        }
        return "\(geldkurs) €"
    }

    // MARK: - Mock Data Helpers for Additional Details

    private func getMockGeldkurs() -> String? {
        // Generate mock current price (slightly lower than ask price)
        let normalizedString = result.askPrice.replacingOccurrences(of: ",", with: ".")
        if let briefkursValue = Double(normalizedString) {
            let geldkursValue = briefkursValue * 0.95 // 5% lower than briefkurs
            return String(format: "%.2f", geldkursValue).replacingOccurrences(of: ".", with: ",")
        }
        return nil
    }

    private func getMockImpliziteVolatilitaet() -> String {
        // Generate mock implied volatility based on WKN
        let hash = result.wkn.hash
        let volatility = Double(abs(hash) % 50) + 15.0 // Range: 15-65%
        return String(format: "%.1f%%", volatility)
    }

    private func getMockOmega() -> String {
        // Generate mock Omega based on WKN
        let hash = result.wkn.hash
        let omega = Double(abs(hash) % 10) + 0.5 // Range: 0.5-10.5
        return String(format: "%.2f", omega)
    }

    private func getMockSubscriptionratio() -> String {
        // Display subscription ratio as decimal format (e.g., 0,1 or 0,01)
        let ratio = result.subscriptionRatio

        // Format with appropriate decimal places
        if ratio == 1.0 {
            return "1,0"
        } else if ratio < 0.01 {
            // For very small ratios, show 4 decimal places
            return String(format: "%.4f", ratio).replacingOccurrences(of: ".", with: ",")
        } else if ratio < 0.1 {
            // For ratios like 0.01, show 2 decimal places
            return String(format: "%.2f", ratio).replacingOccurrences(of: ".", with: ",")
        } else if ratio < 1.0 {
            // For ratios like 0.1, show 1 decimal place
            return String(format: "%.1f", ratio).replacingOccurrences(of: ".", with: ",")
        } else {
            // For ratios >= 1.0, show as integer or 1 decimal place
            if ratio.truncatingRemainder(dividingBy: 1.0) == 0 {
                return String(format: "%.0f", ratio).replacingOccurrences(of: ".", with: ",")
            } else {
                return String(format: "%.1f", ratio).replacingOccurrences(of: ".", with: ",")
            }
        }
    }

    private func getMockAusuebung() -> String {
        // Generate mock exercise type based on category
        switch result.category?.lowercased() {
        case "optionsschein":
            return "Amerikanisch"
        case "aktie":
            return "N/A"
        default:
            return "Europäisch"
        }
    }

    private func getDerivateCategory(_ typ: String) -> String {
        switch typ.lowercased() {
        case "call", "put":
            return "Optionsschein"
        case "aktie":
            return "Aktie"
        case "inline os":
            return "Inline OS"
        case "factor-os":
            return "Factor-OS"
        case "discount os":
            return "Discount OS"
        case "knockout":
            return "Knockout"
        default:
            return typ
        }
    }

    private func getEmittentFromWKN(_ wkn: String) -> String {
        let issuerCode = String(wkn.prefix(2))
        switch issuerCode {
        case "SG": return "Société Générale"
        case "DB": return "Deutsche Bank"
        case "VT": return "Volksbank"
        case "DZ": return "DZ Bank"
        case "BN": return "BNP Paribas"
        case "CI": return "Citigroup"
        case "GS": return "Goldman Sachs"
        case "HS": return "HSBC"
        case "JP": return "J.P. Morgan"
        case "MS": return "Morgan Stanley"
        case "UB": return "UBS"
        case "VO": return "Vontobel"
        case "AAPL", "TSLA", "MSFT", "GOOGL": return "US Stock"
        case "BMW", "DAX": return "German Stock"
        default: return "Unknown"
        }
    }
}
