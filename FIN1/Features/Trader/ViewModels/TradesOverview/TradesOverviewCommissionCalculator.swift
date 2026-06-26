import Foundation

// MARK: - Commission amount (shared parsing)

enum TradesOverviewCommissionAmounts {
    /// Gross commission (net commission line + VAT) from a credit-note `Invoice`.
    static func grossCommission(from invoice: Invoice) -> Double? {
        let commissionItems = invoice.items.filter { $0.itemType == .commission }
        let vatItems = invoice.items.filter { $0.itemType == .vat }
        let netCommission = commissionItems.reduce(0.0) { $0 + abs($1.totalAmount) }
        let vatAmount = vatItems.reduce(0.0) { $0 + abs($1.totalAmount) }
        let gross = netCommission + vatAmount
        return gross > 0 ? gross : nil
    }

    /// Provision is booked only when the trade completes and pool partial-sell P/L is saldiert server-side.
    static func isCommissionPending(tradeIsCompleted: Bool, hasProfit: Bool, commission: Double) -> Bool {
        guard hasProfit else { return false }
        guard tradeIsCompleted else { return true }
        return commission <= 0
    }
}

// MARK: - Trades Overview Commission Calculator

/// Commission for **Abgeschlossene Trades** — same SSOT as Kontoauszug / Gutschrift-Belege:
/// 1. In-memory `DocumentService` (trader credit note, already loaded for inbox / collection bills)
/// 2. Backend customer timeline (`TraderAccountStatementBuilder`, identical to account statement)
/// 3. Local credit-note `InvoiceService`
@MainActor
final class TradesOverviewCommissionCalculator {
    private let invoiceService: (any InvoiceServiceProtocol)?
    private let documentService: (any DocumentServiceProtocol)?
    private let tradeService: (any TradeLifecycleServiceProtocol)?
    private let settlementAPIService: (any SettlementAPIServiceProtocol)?

    private var commissionCreditByTradeId: [String: Double] = [:]
    private var pendingRefreshTask: Task<Void, Never>?

    init(
        invoiceService: (any InvoiceServiceProtocol)?,
        tradeService: (any TradeLifecycleServiceProtocol)?,
        poolTradeParticipationService: (any PoolTradeParticipationServiceProtocol)?,
        commissionCalculationService: (any CommissionCalculationServiceProtocol)?,
        configurationService: (any ConfigurationServiceProtocol)? = nil,
        settlementAPIService: (any SettlementAPIServiceProtocol)? = nil,
        documentService: (any DocumentServiceProtocol)? = nil
    ) {
        self.invoiceService = invoiceService
        self.documentService = documentService
        self.tradeService = tradeService
        self.settlementAPIService = settlementAPIService
        _ = poolTradeParticipationService
        _ = commissionCalculationService
        _ = configurationService
    }

    /// Loads commission map from sources that already power Kontoauszug / document inbox.
    func refreshCommissionCache(traderId: String) async {
        self.commissionCreditByTradeId = self.loadCommissionFromDocuments(traderId: traderId)

        if let settlementAPIService {
            let fromStatement = await TraderAccountStatementBuilder.commissionCreditTotalsByTradeId(
                settlementAPIService: settlementAPIService
            )
            for (tradeId, amount) in fromStatement where amount > 0 {
                if self.commissionCreditByTradeId[tradeId] == nil {
                    self.commissionCreditByTradeId[tradeId] = amount
                }
            }
            NSLog(
                "🧮 TradesOverviewCommissionCache: documents=\(self.commissionCreditByTradeId.count) "
                    + "statement=\(fromStatement.count) trade(s)"
            )
        }

        self.mergeInvoiceCreditNotes()
        await self.mergeFromTradeSettlements()
    }

    func calculateCommission(tradeId: String, hasProfit: Bool) async -> Double {
        guard hasProfit else { return 0.0 }

        if let cached = self.commissionCreditByTradeId[tradeId], cached > 0 {
            return cached
        }

        if let commissionFromInvoice = self.getCommissionFromCreditNoteInvoice(tradeId: tradeId) {
            self.commissionCreditByTradeId[tradeId] = commissionFromInvoice
            return commissionFromInvoice
        }

        if let fromSettlement = await self.commissionFromTradeSettlement(tradeId: tradeId), fromSettlement > 0 {
            self.commissionCreditByTradeId[tradeId] = fromSettlement
            return fromSettlement
        }

        return 0.0
    }

    /// Single deferred refresh when inbox/timeline was empty on first paint. Primary path: notifications (`.commissionSettled`, inbox refresh).
    func scheduleDeferredCommissionRefreshIfNeeded(
        traderId: String,
        tradeIds: [String],
        onUpdate: @escaping () async -> Void
    ) {
        self.pendingRefreshTask?.cancel()
        let pending = tradeIds.filter { (self.commissionCreditByTradeId[$0] ?? 0) <= 0 }
        guard !pending.isEmpty else { return }

        self.pendingRefreshTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if Task.isCancelled { return }
            guard let self else { return }
            await self.refreshCommissionCache(traderId: traderId)
            await onUpdate()
        }
    }

    func cancelPendingRefresh() {
        self.pendingRefreshTask?.cancel()
        self.pendingRefreshTask = nil
    }

    // MARK: - Private

    private func loadCommissionFromDocuments(traderId: String) -> [String: Double] {
        guard let documentService else { return [:] }
        var map: [String: Double] = [:]
        for document in documentService.getDocuments(for: traderId) {
            guard document.type == .traderCreditNote,
                  let tradeId = document.tradeId,
                  let gross = document.resolvedTraderCreditNoteCommissionAmount,
                  gross > 0 else { continue }
            map[tradeId] = gross
        }
        return map
    }

    private func mergeInvoiceCreditNotes() {
        guard let tradeService else { return }
        for trade in tradeService.completedTrades {
            guard self.commissionCreditByTradeId[trade.id] == nil,
                  let amount = self.getCommissionFromCreditNoteInvoice(tradeId: trade.id),
                  amount > 0 else { continue }
            self.commissionCreditByTradeId[trade.id] = amount
        }
    }

    /// Fills gaps when Gutschrift-Beleg / `commission_credit` were not created yet but `getTradeSettlement` has Commission rows.
    private func mergeFromTradeSettlements() async {
        guard self.settlementAPIService != nil, let tradeService else { return }

        let candidates = tradeService.completedTrades.filter { trade in
            trade.displayProfit > 0 && (self.commissionCreditByTradeId[trade.id] ?? 0) <= 0
        }
        guard !candidates.isEmpty else { return }

        for trade in candidates {
            guard let amount = await self.commissionFromTradeSettlement(tradeId: trade.id), amount > 0 else { continue }
            self.commissionCreditByTradeId[trade.id] = amount
            await self.mergeSettlementDocuments(for: trade)
        }
    }

    private func commissionFromTradeSettlement(tradeId: String) async -> Double? {
        guard let settlementAPIService else { return nil }
        guard let settlement = try? await settlementAPIService.fetchTradeSettlement(tradeId: tradeId) else {
            return nil
        }
        let total = TraderCommissionSettlementResolver.totalCommission(from: settlement)
        return total > 0 ? total : nil
    }

    private func mergeSettlementDocuments(for trade: Trade) async {
        guard let settlementAPIService, let documentService else { return }
        guard let settlement = try? await settlementAPIService.fetchTradeSettlement(tradeId: trade.id) else { return }
        let docs = Document.inboxEligible(from: settlement.documents)
        guard !docs.isEmpty else { return }
        documentService.mergeDocuments(docs)
    }

    private func getCommissionFromCreditNoteInvoice(tradeId: String) -> Double? {
        guard let invoiceService else { return nil }

        let allInvoices = invoiceService.getInvoicesForTrade(tradeId)
        let creditNote = allInvoices.first { invoice in
            invoice.type == .creditNote && (
                invoice.tradeId == tradeId ||
                    (invoice.tradeNumber != nil && invoice.tradeNumber == self.getTradeNumber(for: tradeId))
            )
        }

        guard let creditNote else { return nil }
        return TradesOverviewCommissionAmounts.grossCommission(from: creditNote)
    }

    private func getTradeNumber(for tradeId: String) -> Int? {
        self.tradeService?.completedTrades.first(where: { $0.id == tradeId })?.tradeNumber
    }
}
