import Foundation

/// SSOT for per-investor commission lines on a settled trade (Gutschrift-Beleg, Breakdown-Sheet).
enum TradeCommissionSettlementBreakdownResolver {

    struct ResolvedBreakdown {
        let lines: [TradeInvestorCommissionLine]
        let totalGrossProfit: Double
        let totalCommission: Double
    }

    /// Loads investor commission lines from `getTradeSettlement` (metadata → Commission rows → aggregate).
    @MainActor
    static func resolve(
        tradeId: String,
        creditNoteDocumentId: String?,
        investments: [Investment],
        settlementAPIService: any SettlementAPIServiceProtocol
    ) async -> ResolvedBreakdown? {
        guard let settlement = try? await settlementAPIService.fetchTradeSettlement(tradeId: tradeId) else {
            return nil
        }

        if let fromMetadata = linesFromCreditNoteMetadata(
            settlement: settlement,
            preferredDocumentId: creditNoteDocumentId,
            investments: investments
        ), !fromMetadata.isEmpty {
            return self.summarize(lines: fromMetadata, settlement: settlement)
        }

        let grouped = Dictionary(grouping: settlement.commissions) { $0.investmentId ?? $0.objectId }
        var lines: [TradeInvestorCommissionLine] = []

        for (investmentId, rows) in grouped {
            let commission = rows.compactMap(\.commissionAmount).reduce(0, +)
            guard commission > 0 else { continue }
            let gross = rows.compactMap(\.investorGrossProfit).reduce(0, +)
            guard commission > 0 else { continue }
            let name = TradeInvestorCommissionNameResolver.resolve(
                investmentId: investmentId,
                investorId: rows.first?.investorId,
                investments: investments
            )
            lines.append(TradeInvestorCommissionLine(
                investmentId: investmentId,
                investorName: name,
                grossProfit: gross,
                commission: commission
            ))
        }

        if !lines.isEmpty {
            return self.summarize(lines: lines.sorted { $0.investorName < $1.investorName }, settlement: settlement)
        }

        let aggregateCommission = TraderCommissionSettlementResolver.totalCommission(from: settlement)
        guard aggregateCommission > 0 else { return nil }

        let gross = settlement.grossProfit > 0
            ? settlement.grossProfit
            : (self.creditNoteGrossProfit(from: settlement, preferredDocumentId: creditNoteDocumentId) ?? 0)

        let aggregateLine = TradeInvestorCommissionLine(
            investmentId: "aggregate",
            investorName: String(localized: "Investoren (gesamt)", comment: "Fallback label when per-investor lines are unavailable"),
            grossProfit: gross,
            commission: aggregateCommission
        )
        return ResolvedBreakdown(
            lines: [aggregateLine],
            totalGrossProfit: gross,
            totalCommission: aggregateCommission
        )
    }

    /// Header totals when line breakdown is unavailable (metadata / statement / commission rows).
    @MainActor
    static func resolveSummaryTotals(
        tradeId: String,
        creditNoteDocumentId: String?,
        settlementAPIService: any SettlementAPIServiceProtocol
    ) async -> (grossProfit: Double, commission: Double)? {
        guard let settlement = try? await settlementAPIService.fetchTradeSettlement(tradeId: tradeId) else {
            return nil
        }
        let commission = TraderCommissionSettlementResolver.totalCommission(from: settlement)
        guard commission > 0 else { return nil }
        let gross = self.creditNoteGrossProfit(from: settlement, preferredDocumentId: creditNoteDocumentId)
            ?? settlement.grossProfit
        return (gross, commission)
    }

    // MARK: - Private

    private static func summarize(
        lines: [TradeInvestorCommissionLine],
        settlement: TradeSettlementResponse
    ) -> ResolvedBreakdown {
        let totalGross = lines.reduce(0) { $0 + $1.grossProfit }
        let totalComm = lines.reduce(0) { $0 + $1.commission }
        let gross = totalGross > 0 ? totalGross : settlement.grossProfit
        return ResolvedBreakdown(
            lines: lines,
            totalGrossProfit: gross,
            totalCommission: totalComm > 0 ? totalComm : TraderCommissionSettlementResolver.totalCommission(from: settlement)
        )
    }

    private static func linesFromCreditNoteMetadata(
        settlement: TradeSettlementResponse,
        preferredDocumentId: String?,
        investments: [Investment]
    ) -> [TradeInvestorCommissionLine]? {
        let creditNotes = settlement.documents.filter { $0.type == DocumentType.traderCreditNote.rawValue }
        let doc = preferredDocumentId.flatMap { id in creditNotes.first { $0.objectId == id } }
            ?? creditNotes.first
        guard let breakdown = doc?.metadata?.investorBreakdown, !breakdown.isEmpty else {
            return nil
        }

        let mapped = breakdown.compactMap { row -> TradeInvestorCommissionLine? in
            let commission = row.commission ?? 0
            let gross = row.grossProfit ?? 0
            guard commission > 0 || gross > 0 else { return nil }
            let investmentId = row.investmentId ?? row.investorId ?? UUID().uuidString
            let name = TradeInvestorCommissionNameResolver.resolve(
                serverName: row.investorName,
                investmentId: row.investmentId,
                investorId: row.investorId,
                investments: investments
            )
            return TradeInvestorCommissionLine(
                investmentId: investmentId,
                investorName: name,
                grossProfit: gross,
                commission: commission
            )
        }
        return mapped.isEmpty ? nil : mapped
    }

    private static func creditNoteGrossProfit(
        from settlement: TradeSettlementResponse,
        preferredDocumentId: String?
    ) -> Double? {
        let creditNotes = settlement.documents.filter { $0.type == DocumentType.traderCreditNote.rawValue }
        let doc = preferredDocumentId.flatMap { id in creditNotes.first { $0.objectId == id } }
            ?? creditNotes.first
        guard let gross = doc?.metadata?.grossProfit, gross > 0 else { return nil }
        return gross
    }
}
