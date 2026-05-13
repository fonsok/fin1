import Foundation

// MARK: - Trades Overview Commission Calculator

/// Handles commission calculation for trades overview
/// SINGLE SOURCE OF TRUTH: First tries to read from existing Credit Note invoice (if trade completed)
/// Includes retry mechanism for race condition when credit note is added asynchronously
/// Falls back to calculation if no credit note exists yet (for active trades)
@MainActor
final class TradesOverviewCommissionCalculator {
    private let invoiceService: (any InvoiceServiceProtocol)?
    private let tradeService: (any TradeLifecycleServiceProtocol)?
    private let poolTradeParticipationService: (any PoolTradeParticipationServiceProtocol)?
    private let commissionCalculationService: (any CommissionCalculationServiceProtocol)?
    private let configurationService: (any ConfigurationServiceProtocol)?

    init(
        invoiceService: (any InvoiceServiceProtocol)?,
        tradeService: (any TradeLifecycleServiceProtocol)?,
        poolTradeParticipationService: (any PoolTradeParticipationServiceProtocol)?,
        commissionCalculationService: (any CommissionCalculationServiceProtocol)?,
        configurationService: (any ConfigurationServiceProtocol)? = nil
    ) {
        self.invoiceService = invoiceService
        self.tradeService = tradeService
        self.poolTradeParticipationService = poolTradeParticipationService
        self.commissionCalculationService = commissionCalculationService
        self.configurationService = configurationService
    }

    /// Calculates total commission for a trade using centralized services
    /// - Parameters:
    ///   - tradeId: Trade ID to check for investor participations
    ///   - hasProfit: Whether the trade has positive profit (used for guard check)
    /// - Returns: Commission amount (0 if no investors, no profit, or service unavailable)
    func calculateCommission(tradeId: String, hasProfit: Bool) async -> Double {
        NSLog("🧮 TradesOverviewCalc[trade=\(tradeId)] calculateCommission hasProfit=\(hasProfit)")
        guard hasProfit else {
            return 0.0 // No commission on losses or zero profit
        }

        // SINGLE SOURCE OF TRUTH: Try to read commission from existing Credit Note invoice first
        // This matches what Account Statement shows (reads from invoice)
        if let commissionFromInvoice = getCommissionFromCreditNoteInvoice(tradeId: tradeId) {
            NSLog("🧮 TradesOverviewCalc[trade=\(tradeId)] from invoice = €\(commissionFromInvoice)")
            return commissionFromInvoice
        }

        // BACKEND-AUTHORITATIVE: ask the Settlement API for the trader's
        // `commission_credit` posting on this trade. The local
        // PoolTradeParticipation cache is unreliable on the trader side
        // (participations are owned by investors and may not be replicated
        // into the trader's local view), so we must NOT gate this call on a
        // local participation check. The CommissionCalculationService falls
        // back to `commission_debit` and the local `investorGrossProfitService`
        // when needed.
        if let commissionCalculationService = commissionCalculationService,
           let configurationService = configurationService {
            let commissionRate = configurationService.effectiveCommissionRate
            do {
                let totalCommission = try await commissionCalculationService.calculateTotalCommissionForTrade(
                    tradeId: tradeId,
                    commissionRate: commissionRate
                )
                NSLog("🧮 TradesOverviewCalc[trade=\(tradeId)] backend returned €\(totalCommission)")
                if totalCommission > 0 {
                    return totalCommission
                }
            } catch {
                NSLog("🧮 TradesOverviewCalc[trade=\(tradeId)] backend lookup failed: \(error)")
            }
        } else {
            NSLog(
                "🧮 TradesOverviewCalc[trade=\(tradeId)] services missing (commCalcSvc=\(commissionCalculationService != nil), configSvc=\(configurationService != nil))"
            )
        }

        // RACE CONDITION FIX: Credit note might be added asynchronously after trade completion
        // Retry reading from invoice with a small delay (credit note is added shortly after trade completes)
        // This handles cases where trades complete out of order
        if let trade = tradeService?.completedTrades.first(where: { $0.id == tradeId }),
           trade.isCompleted {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            if let commissionFromInvoice = getCommissionFromCreditNoteInvoice(tradeId: tradeId) {
                print(
                    "✅ TradesOverviewCommissionCalculator: Using commission from Credit Note invoice (after retry): €\(String(format: "%.2f", commissionFromInvoice))"
                )
                return commissionFromInvoice
            }
            // Retry backend call too — settlement happens asynchronously after the
            // sell-save returns from `upsertTrade`.
            if let commissionCalculationService = commissionCalculationService,
               let configurationService = configurationService {
                let commissionRate = configurationService.effectiveCommissionRate
                if let total = try? await commissionCalculationService.calculateTotalCommissionForTrade(
                    tradeId: tradeId,
                    commissionRate: commissionRate
                ), total > 0 {
                    print(
                        "✅ TradesOverviewCommissionCalculator: Backend commission (after retry) for trade \(tradeId): €\(String(format: "%.2f", total))"
                    )
                    return total
                }
            }
        }

        // No commission available (e.g. trader keeps full profit because no
        // investor pool participated, or settlement has not run yet).
        return 0.0
    }

    /// Gets commission amount from existing Credit Note invoice (SINGLE SOURCE OF TRUTH)
    /// This matches what Account Statement displays - both read from the same invoice
    /// - Parameter tradeId: Trade ID
    /// - Returns: Commission amount from credit note, or nil if no credit note exists
    private func getCommissionFromCreditNoteInvoice(tradeId: String) -> Double? {
        guard let invoiceService = invoiceService else {
            return nil
        }

        // Get all invoices for this trade
        let allInvoices = invoiceService.getInvoicesForTrade(tradeId)

        // Find credit note invoice (commission is stored in credit note)
        // Also check by tradeNumber in case tradeId doesn't match
        let creditNote = allInvoices.first { invoice in
            invoice.type == .creditNote && (
                invoice.tradeId == tradeId ||
                    (invoice.tradeNumber != nil && invoice.tradeNumber == self.getTradeNumber(for: tradeId))
            )
        }

        guard let creditNote = creditNote else {
            return nil
        }

        // Extract commission amount from credit note items
        // Credit note has: commission item (net) + VAT item = gross commission
        let commissionItems = creditNote.items.filter { $0.itemType == .commission }
        let vatItems = creditNote.items.filter { $0.itemType == .vat }

        // Calculate gross commission (net commission + VAT)
        let netCommission = commissionItems.reduce(0.0) { $0 + abs($1.totalAmount) }
        let vatAmount = vatItems.reduce(0.0) { $0 + abs($1.totalAmount) }
        let grossCommission = netCommission + vatAmount

        guard grossCommission > 0 else {
            return nil
        }

        return grossCommission
    }

    /// Helper to get trade number for matching credit notes
    private func getTradeNumber(for tradeId: String) -> Int? {
        return self.tradeService?.completedTrades.first(where: { $0.id == tradeId })?.tradeNumber
    }
}

