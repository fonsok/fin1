import Foundation

/// Blocks legacy trader-only buys when pool mirror capital exists (local or server SSOT).
enum TraderPairedBuyPlacementGuard {

    enum BlockReason: Equatable {
        case backendUnreachable
        case serverReservedPoolCapital(Double)
        case staleLocalPoolState(Double)
    }

    static func blockReason(
        mirrorPoolQuantity: Int,
        localReservedPoolCapital: Double,
        parseAPIClient: (any ParseAPIClientProtocol)?,
        investmentAPIService: (any InvestmentAPIServiceProtocol)?,
        traderId: String,
        traderUsername: String?,
        traderName: String?
    ) async -> BlockReason? {
        guard mirrorPoolQuantity <= 0 else { return nil }

        // Demo / unit tests without Parse: keep legacy trader-only path.
        guard parseAPIClient != nil else { return nil }

        let backendHealthy = await MainActor.run { BackendHealthMonitor.shared.isHealthy }
        guard backendHealthy else { return .backendUnreachable }

        if localReservedPoolCapital > 0 {
            return .staleLocalPoolState(localReservedPoolCapital)
        }

        guard let investmentAPIService else { return nil }

        do {
            let capacity = try await investmentAPIService.fetchPoolMirrorCapacity(
                traderId: traderId,
                traderUsername: traderUsername,
                traderName: traderName,
                additionalAmount: 0
            )
            if capacity.reservedTotal > 0.005 {
                return .serverReservedPoolCapital(capacity.reservedTotal)
            }
        } catch {
            return .backendUnreachable
        }

        return nil
    }

    static func appError(for reason: BlockReason) -> AppError {
        switch reason {
        case .backendUnreachable:
            return AppError.validationError(
                String(
                    localized: "Server nicht erreichbar. Bitte warten, bis die Verbindung wieder steht, und den Kauf erneut versuchen."
                )
            )
        case .serverReservedPoolCapital(let amount):
            return AppError.validationError(
                String(
                    localized: "Reserviertes Pool-Kapital auf dem Server (€\(amount.formatted(.number.precision(.fractionLength(2))))). Kauf nur als Paired Buy mit Pool-Mirror — bitte Kauf-Order neu öffnen."
                )
            )
        case .staleLocalPoolState(let amount):
            return AppError.validationError(
                String(
                    localized: "Pool-Daten noch nicht geladen (€\(amount.formatted(.number.precision(.fractionLength(2)))) lokal). Bitte Kauf-Order kurz schließen und erneut öffnen."
                )
            )
        }
    }

    static func localReservedPoolCapital(
        investmentService: any InvestmentServiceProtocol,
        investmentDataProvider: any BuyOrderInvestmentDataProviderProtocol,
        currentUser: User?
    ) -> Double {
        guard let currentUser, currentUser.role == .trader else { return 0 }
        let traderId = investmentDataProvider.findTraderIdForMatching(currentUser: currentUser) ?? currentUser.id
        return investmentService.getInvestments(forTrader: traderId)
            .filter(\.hasPoolCapitalCommitted)
            .reduce(0.0) { $0 + $1.amount }
    }
}
