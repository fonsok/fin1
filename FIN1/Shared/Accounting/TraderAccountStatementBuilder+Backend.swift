import Foundation

extension TraderAccountStatementBuilder {
    /// Builds a snapshot using local invoices for trade entries and backend
    /// `AccountStatement` records for commission entries (authoritative source).
    /// Falls back to local-only if backend is unavailable.
    static func buildSnapshotWithBackendCommissions(
        for user: User?,
        invoiceService: any InvoiceServiceProtocol,
        configurationService: any ConfigurationServiceProtocol,
        settlementAPIService: any SettlementAPIServiceProtocol
    ) async -> TraderAccountStatementSnapshot {
        let openingBalance = configurationService.initialAccountBalance
        guard let user else {
            return TraderAccountStatementSnapshot(entries: [], openingBalance: openingBalance, closingBalance: openingBalance)
        }

        let backendEntries: [BackendAccountEntry]
        do {
            let response = try await settlementAPIService.fetchAccountStatement(limit: 200, skip: 0, entryType: nil)
            backendEntries = response.entries
        } catch {
            return buildSnapshot(for: user, invoiceService: invoiceService, configurationService: configurationService)
        }

        let invoices = fetchInvoices(for: user, invoiceService: invoiceService)
        let regularInvoices = invoices.filter { $0.type != .creditNote }.sorted { $0.createdAt < $1.createdAt }

        struct BackendTradeRef { let docId: String?; let docNumber: String? }
        var tradeRefByKey: [String: BackendTradeRef] = [:]
        for entry in backendEntries {
            guard let tradeId = entry.tradeId else { continue }
            let side: String
            switch entry.entryType {
            case "trade_buy": side = "buy"
            case "trade_sell": side = "sell"
            default: continue
            }
            tradeRefByKey["\(tradeId)#\(side)"] = BackendTradeRef(
                docId: entry.referenceDocumentId,
                docNumber: entry.referenceDocumentNumber
            )
        }

        var runningBalance = openingBalance
        var entries: [AccountStatementEntry] = []
        var latestDatePerTrade: [String: Date] = [:]

        for invoice in regularInvoices {
            guard let transactionType = invoice.transactionType else { continue }
            let direction: AccountStatementEntry.Direction = transactionType == .sell ? .credit : .debit
            let amount = invoice.totalAmount
            runningBalance += direction == .credit ? amount : -amount

            if let tradeId = invoice.tradeId {
                let current = latestDatePerTrade[tradeId] ?? .distantPast
                latestDatePerTrade[tradeId] = max(current, invoice.createdAt)
            }

            let reference = invoice.tradeId ?? invoice.invoiceNumber
            let subtitle: String? = invoice.tradeNumber.map { String(format: "Trade #%03d", $0) }

            let backendRef: BackendTradeRef? = invoice.tradeId.flatMap {
                tradeRefByKey["\($0)#\(transactionType.rawValue)"]
            }
            let resolvedDocId = backendRef?.docId
            let resolvedDocNumber = backendRef?.docNumber ?? invoice.invoiceNumber

            var metadata: [String: String] = [
                "invoiceNumber": invoice.invoiceNumber,
                "tradeId": invoice.tradeId ?? "",
                "transactionType": transactionType.rawValue
            ]
            if let tradeNumber = invoice.tradeNumber {
                metadata["tradeNumber"] = String(format: "%03d", tradeNumber)
            }
            if let docId = resolvedDocId, !docId.isEmpty {
                metadata["referenceDocumentId"] = docId
            }
            if let docNumber = backendRef?.docNumber, !docNumber.isEmpty {
                metadata["referenceDocumentNumber"] = docNumber
            }

            entries.append(AccountStatementEntry(
                title: transactionType.displayName,
                subtitle: subtitle,
                occurredAt: invoice.createdAt,
                amount: amount,
                direction: direction,
                category: .tradeSettlement,
                reference: reference,
                referenceDocumentId: resolvedDocId,
                referenceDocumentNumber: resolvedDocNumber,
                metadata: metadata,
                balanceAfter: runningBalance
            ))
        }

        let commissionEntries = backendEntries.filter { $0.entryType == "commission_credit" }
        if !commissionEntries.isEmpty {
            for entry in commissionEntries {
                let amount = abs(entry.amount)
                runningBalance += amount
                let tradeLatest = entry.tradeId.flatMap { latestDatePerTrade[$0] }
                let occurredAt = tradeLatest?.addingTimeInterval(1) ?? Date()

                let subtitle = entry.tradeNumber.map { String(format: "Trade #%03d", $0) } ?? "Trader Commission"
                var metadata: [String: String] = [
                    "source": "backend",
                    "commissionAmount": String(format: "%.2f", amount)
                ]
                if let tradeId = entry.tradeId { metadata["tradeId"] = tradeId }
                if let referenceDocumentId = entry.referenceDocumentId, !referenceDocumentId.isEmpty {
                    metadata["referenceDocumentId"] = referenceDocumentId
                }
                if let referenceDocumentNumber = entry.referenceDocumentNumber, !referenceDocumentNumber.isEmpty {
                    metadata["referenceDocumentNumber"] = referenceDocumentNumber
                }

                entries.append(AccountStatementEntry(
                    title: "Gutschrift Provision",
                    subtitle: subtitle,
                    occurredAt: occurredAt,
                    amount: amount,
                    direction: .credit,
                    category: .commission,
                    reference: entry.objectId,
                    referenceDocumentId: entry.referenceDocumentId,
                    referenceDocumentNumber: entry.referenceDocumentNumber,
                    metadata: metadata,
                    balanceAfter: runningBalance
                ))
            }
        } else {
            let creditNotes = invoices.filter { $0.type == .creditNote }.sorted { $0.createdAt < $1.createdAt }
            for creditNote in creditNotes {
                let tradeLatest = creditNote.tradeId.flatMap { latestDatePerTrade[$0] }
                let adjustedDate = max(creditNote.createdAt, tradeLatest?.addingTimeInterval(1) ?? creditNote.createdAt)
                entries.append(createCommissionEntry(from: creditNote, runningBalance: &runningBalance, adjustedDate: adjustedDate))
            }
        }

        return TraderAccountStatementSnapshot(entries: entries, openingBalance: openingBalance, closingBalance: runningBalance)
    }
}
