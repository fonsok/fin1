import Foundation

/// Publishes an indicative UI quote to Parse `MarketData` before market-order execution.
/// Server execution still resolves price from `MarketData` only (intent-only, ADR-019 Phase 8).
enum MarketDataQuotePublisher {

    private struct PublishResult: Decodable {
        let symbol: String
        let price: Double
        let publishedAt: String
    }

    static func publishBeforeMarketExecution(
        symbol: String,
        indicativePrice: Double,
        via client: any ParseAPIClientProtocol
    ) async throws {
        let trimmedSymbol = symbol.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSymbol.isEmpty else {
            throw AppError.validationError("Symbol fehlt für Marktkurs-Veröffentlichung.")
        }
        guard indicativePrice.isFinite, indicativePrice > 0 else {
            throw AppError.validationError("Ungültiger Anzeigekurs für Marktorder.")
        }

        let _: PublishResult = try await client.callFunction(
            "upsertMarketDataQuote",
            parameters: [
                "symbol": trimmedSymbol,
                "price": indicativePrice
            ]
        )
    }
}
