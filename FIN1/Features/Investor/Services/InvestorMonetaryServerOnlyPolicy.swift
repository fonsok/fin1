import Foundation

// MARK: - GoB: server-only monetary display & cash flows

/// User-facing copy when iOS must not substitute local calculations for booked amounts.
enum InvestorMonetaryMessages {
    static let serverUnavailable =
        "Server nicht erreichbar. Gebuchte Beträge können nicht angezeigt werden. Bitte später erneut öffnen."
    static let noArchivedBeleg =
        "Kein archivierter Collection Bill auf dem Server. Beträge werden erst nach Trade-Abrechnung angezeigt."
    static let accountStatementUnavailable =
        "Kontoauszug konnte nicht vom Server geladen werden. Bitte später erneut versuchen."
    static let cashDistributionBlocked =
        "Auszahlung blockiert: keine gebuchten Kontoauszug-Positionen auf dem Server."
    static let provisionalSectionHint =
        "Beträge ausgeblendet — maßgeblich ist der archivierte Collection Bill nach der Abrechnung."
}

enum InvestorMonetaryServerOnlyError: Error, LocalizedError {
    case serverUnavailable
    case noArchivedBeleg(tradeNumber: Int?)
    case accountStatementUnavailable

    var errorDescription: String? {
        switch self {
        case .serverUnavailable:
            return InvestorMonetaryMessages.serverUnavailable
        case .noArchivedBeleg:
            return InvestorMonetaryMessages.noArchivedBeleg
        case .accountStatementUnavailable:
            return InvestorMonetaryMessages.accountStatementUnavailable
        }
    }
}
