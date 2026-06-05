import Foundation

extension TraderAccountStatementBuilder {
    /// Builds a snapshot from the server customer timeline (`source: customer_display`).
    /// Falls back to local invoices when the backend is unavailable, empty, or not yet on presentation API.
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

        let fetchResult = await fetchAllBackendEntries(settlementAPIService: settlementAPIService)
        if fetchResult.entries.isEmpty {
            return buildSnapshot(for: user, invoiceService: invoiceService, configurationService: configurationService)
        }

        if fetchResult.entries.contains(where: { $0.source == "customer_display" }) {
            return self.buildSnapshotFromCustomerDisplayBackend(
                entries: fetchResult.entries,
                openingBalance: openingBalance,
                timelineTruncated: fetchResult.timelineTruncated
            )
        }

        return buildSnapshot(for: user, invoiceService: invoiceService, configurationService: configurationService)
    }

    // MARK: - Backend fetch & mapping

    /// Maps server-built customer timeline rows (`source: customer_display`) without client-side trade merging.
    private static func buildSnapshotFromCustomerDisplayBackend(
        entries: [BackendAccountEntry],
        openingBalance: Double,
        timelineTruncated: Bool
    ) -> TraderAccountStatementSnapshot {
        let sorted = AccountStatementEntry.sortedForChronologicalDisplay(
            entries.compactMap { self.convertCustomerDisplayBackendEntry($0) }
        )
        let closingBalance = sorted.last?.balanceAfter ?? openingBalance
        return TraderAccountStatementSnapshot(
            entries: sorted,
            openingBalance: openingBalance,
            closingBalance: closingBalance,
            timelineTruncated: timelineTruncated
        )
    }

    private static func convertCustomerDisplayBackendEntry(_ entry: BackendAccountEntry) -> AccountStatementEntry? {
        let occurredAt = entry.createdAtDate ?? Date()
        let signedAmount = entry.amount
        let amount = abs(signedAmount)
        let direction: AccountStatementEntry.Direction = signedAmount >= 0 ? .credit : .debit

        let title: String
        let category: AccountStatementEntry.Category
        var metadata: [String: String] = [
            "source": entry.source ?? "customer_display",
            "backendEntryType": entry.entryType
        ]

        if let statementTitle = entry.statementTitle, !statementTitle.isEmpty {
            metadata["statementTitle"] = statementTitle
        }
        if let displayAmountMode = entry.displayAmountMode, !displayAmountMode.isEmpty {
            metadata["displayAmountMode"] = displayAmountMode
        }
        if let transactionType = entry.transactionType, !transactionType.isEmpty {
            metadata["transactionType"] = transactionType
        }
        if let wknOrIsin = entry.wknOrIsin, !wknOrIsin.isEmpty { metadata["wknOrIsin"] = wknOrIsin }
        if let underlyingAsset = entry.underlyingAsset, !underlyingAsset.isEmpty {
            metadata["underlyingAsset"] = underlyingAsset
        }
        if let securitiesDirection = entry.securitiesDirection, !securitiesDirection.isEmpty {
            metadata["securitiesDirection"] = securitiesDirection
        }
        if let quantity = entry.quantity, !quantity.isEmpty { metadata["quantity"] = quantity }
        if let strikePrice = entry.strikePrice, !strikePrice.isEmpty { metadata["strikePrice"] = strikePrice }
        if let issuer = entry.issuer, !issuer.isEmpty { metadata["issuer"] = issuer }
        if let tradeId = entry.tradeId { metadata["tradeId"] = tradeId }
        if let tradeNumber = entry.tradeNumber {
            metadata["tradeNumber"] = String(format: "%03d", tradeNumber)
        }
        if let referenceDocumentId = entry.referenceDocumentId, !referenceDocumentId.isEmpty {
            metadata["referenceDocumentId"] = referenceDocumentId
        }
        if let referenceDocumentNumber = entry.referenceDocumentNumber, !referenceDocumentNumber.isEmpty {
            metadata["referenceDocumentNumber"] = referenceDocumentNumber
        }

        switch entry.entryType {
        case "trade_buy", "trade_sell":
            title = entry.transactionType.flatMap { TransactionType(rawValue: $0)?.displayName }
                ?? (entry.entryType == "trade_sell" ? TransactionType.sell.displayName : TransactionType.buy.displayName)
            category = .tradeSettlement
        case "commission_credit":
            title = "Gutschrift Provision"
            category = .commission
            metadata["commissionAmount"] = String(format: "%.2f", amount)
        case "deposit":
            title = "Einzahlung"
            category = .walletDeposit
        case "withdrawal":
            title = "Auszahlung"
            category = .walletWithdrawal
        default:
            return nil
        }

        let subtitle = entry.tradeNumber.map { String(format: "Trade #%03d", $0) }
            ?? entry.description

        return AccountStatementEntry(
            title: title,
            subtitle: subtitle,
            occurredAt: occurredAt,
            amount: amount,
            direction: direction,
            category: category,
            reference: entry.objectId,
            referenceDocumentId: entry.referenceDocumentId,
            referenceDocumentNumber: entry.referenceDocumentNumber,
            metadata: metadata,
            balanceAfter: entry.balanceAfter
        )
    }

    private struct BackendEntriesFetchResult {
        let entries: [BackendAccountEntry]
        let timelineTruncated: Bool
    }

    /// Same amounts as **Kontoauszug** `commission_credit` rows — fetched with `entryType` filter (not full timeline).
    static func commissionCreditTotalsByTradeId(
        settlementAPIService: any SettlementAPIServiceProtocol
    ) async -> [String: Double] {
        let entries = await fetchCommissionCreditBackendEntries(settlementAPIService: settlementAPIService)
        var totals: [String: Double] = [:]
        for entry in entries {
            guard let tradeId = entry.tradeId, !tradeId.isEmpty else { continue }
            totals[tradeId, default: 0] += abs(entry.amount)
        }
        return totals
    }

    /// Paginated `getAccountStatement(entryType: commission_credit)` with full-timeline fallback.
    private static func fetchCommissionCreditBackendEntries(
        settlementAPIService: any SettlementAPIServiceProtocol
    ) async -> [BackendAccountEntry] {
        let filtered = await fetchCommissionCreditPages(
            settlementAPIService: settlementAPIService,
            entryType: "commission_credit"
        )
        if !filtered.isEmpty {
            return filtered
        }
        let full = await fetchCommissionCreditPages(
            settlementAPIService: settlementAPIService,
            entryType: nil
        )
        return full.filter { $0.entryType == "commission_credit" }
    }

    private static func fetchCommissionCreditPages(
        settlementAPIService: any SettlementAPIServiceProtocol,
        entryType: String?
    ) async -> [BackendAccountEntry] {
        do {
            var all: [BackendAccountEntry] = []
            var skip = 0
            let pageSize = 200
            repeat {
                let response = try await settlementAPIService.fetchAccountStatement(
                    limit: pageSize,
                    skip: skip,
                    entryType: entryType
                )
                all.append(contentsOf: response.entries)
                skip += response.entries.count
                if !response.hasMore || response.entries.isEmpty { break }
            } while skip < 1_000
            return all
        } catch {
            return []
        }
    }

    private static func fetchAllBackendEntries(
        settlementAPIService: any SettlementAPIServiceProtocol
    ) async -> BackendEntriesFetchResult {
        do {
            var all: [BackendAccountEntry] = []
            var timelineTruncated = false
            var skip = 0
            let pageSize = 500
            repeat {
                let response = try await settlementAPIService.fetchAccountStatement(
                    limit: pageSize, skip: skip, entryType: nil
                )
                if response.timelineTruncated {
                    timelineTruncated = true
                }
                all.append(contentsOf: response.entries)
                skip += response.entries.count
                let isCustomerDisplay = response.entries.contains { $0.source == "customer_display" }
                if isCustomerDisplay, !response.hasMore {
                    break
                }
                if !response.hasMore || response.entries.isEmpty { break }
            } while skip < 2_000
            return BackendEntriesFetchResult(entries: all, timelineTruncated: timelineTruncated)
        } catch {
            return BackendEntriesFetchResult(entries: [], timelineTruncated: false)
        }
    }
}
