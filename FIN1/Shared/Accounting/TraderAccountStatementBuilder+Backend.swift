import Foundation

extension TraderAccountStatementBuilder {
    /// Empty snapshot when server-only mode blocks local invoice fallback.
    static func emptyServerOnlySnapshot(openingBalance: Double) -> TraderAccountStatementSnapshot {
        TraderAccountStatementSnapshot(
            entries: [],
            openingBalance: openingBalance,
            closingBalance: openingBalance
        )
    }

    /// Builds a snapshot from the server customer timeline (`source: customer_display`).
    /// Falls back to local invoices only when `traderStatementServerOnly` is false.
    static func buildSnapshotWithBackendCommissions(
        for user: User?,
        invoiceService: any InvoiceServiceProtocol,
        configurationService: any ConfigurationServiceProtocol,
        settlementAPIService: any SettlementAPIServiceProtocol
    ) async -> TraderAccountStatementSnapshot {
        let openingBalance = configurationService.initialAccountBalance
        let serverOnly = configurationService.traderStatementServerOnly
        guard let user else {
            return TraderAccountStatementSnapshot(entries: [], openingBalance: openingBalance, closingBalance: openingBalance)
        }

        let fetchResult = await fetchAllBackendEntries(settlementAPIService: settlementAPIService)
        if fetchResult.entries.isEmpty {
            if fetchResult.fetchFailed, serverOnly {
                print("⚠️ TraderAccountStatementBuilder: \(TraderMonetaryMessages.accountStatementUnavailable)")
                return self.emptyServerOnlySnapshot(openingBalance: openingBalance)
            }
            if serverOnly {
                return self.emptyServerOnlySnapshot(openingBalance: openingBalance)
            }
            return buildSnapshot(for: user, invoiceService: invoiceService, configurationService: configurationService)
        }

        if fetchResult.entries.contains(where: { $0.source == "customer_display" }) {
            let snapshot = self.buildSnapshotFromCustomerDisplayBackend(
                entries: fetchResult.entries,
                openingBalance: openingBalance,
                timelineTruncated: fetchResult.timelineTruncated
            )
            return await self.mergeMissingCommissionCredits(
                into: snapshot,
                settlementAPIService: settlementAPIService
            )
        }

        if serverOnly {
            print("⚠️ TraderAccountStatementBuilder: \(TraderMonetaryMessages.accountStatementUnavailable) (no customer_display)")
            return self.emptyServerOnlySnapshot(openingBalance: openingBalance)
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
            metadata["tradeNumber"] = TradeNumberFormatting.display(
                number: tradeNumber,
                year: TradeNumberFormatting.calendarYear(for: occurredAt)
            )
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

        let subtitle = entry.tradeNumber.map {
            TradeNumberFormatting.labeled(
                number: $0,
                year: TradeNumberFormatting.calendarYear(for: occurredAt)
            )
        } ?? entry.description

        return AccountStatementEntry(
            id: Self.stableEntryId(from: entry.objectId),
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
        let fetchFailed: Bool
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

    /// Ensures `commission_credit` rows from the filtered API are present even when the merged timeline omits them.
    private static func mergeMissingCommissionCredits(
        into snapshot: TraderAccountStatementSnapshot,
        settlementAPIService: any SettlementAPIServiceProtocol
    ) async -> TraderAccountStatementSnapshot {
        let creditBackendRows = await fetchCommissionCreditBackendEntries(settlementAPIService: settlementAPIService)
        guard !creditBackendRows.isEmpty else { return snapshot }

        let existingObjectIds = Set(snapshot.entries.compactMap(\.reference))
        let existingDocumentNumbers = Set(
            snapshot.entries.compactMap(\.referenceDocumentNumber).filter { !$0.isEmpty }
        )

        var extras: [AccountStatementEntry] = []
        for row in creditBackendRows {
            let objectId = row.objectId
            let documentNumber = row.referenceDocumentNumber ?? ""
            if existingObjectIds.contains(objectId) { continue }
            if !documentNumber.isEmpty, existingDocumentNumbers.contains(documentNumber) { continue }
            guard let converted = convertCustomerDisplayBackendEntry(row) else { continue }
            extras.append(converted)
        }

        guard !extras.isEmpty else { return snapshot }

        let merged = snapshot.entries + extras
        let recalculated = recalculateBalanceAfter(entries: merged, openingBalance: snapshot.openingBalance)
        return TraderAccountStatementSnapshot(
            entries: AccountStatementEntry.sortedForChronologicalDisplay(recalculated),
            openingBalance: snapshot.openingBalance,
            closingBalance: recalculated.last?.balanceAfter ?? snapshot.closingBalance,
            timelineTruncated: snapshot.timelineTruncated
        )
    }

    private static func stableEntryId(from objectId: String) -> UUID {
        UUID(uuidString: objectId) ?? UUID()
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
            return BackendEntriesFetchResult(entries: all, timelineTruncated: timelineTruncated, fetchFailed: false)
        } catch {
            return BackendEntriesFetchResult(entries: [], timelineTruncated: false, fetchFailed: true)
        }
    }
}
