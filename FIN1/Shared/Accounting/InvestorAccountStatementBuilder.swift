import Foundation

struct InvestorAccountStatementSnapshot {
    let entries: [AccountStatementEntry]
    let openingBalance: Double
    let closingBalance: Double
}

private struct InvestorBackendStatementFetch {
    let entries: [AccountStatementEntry]
    let timelineTruncated: Bool
}

enum InvestorAccountStatementBuilder {
    /// Builds an investor account statement snapshot including wallet transactions.
    /// Closing balance follows the server merge timeline (`getAccountStatement`) — same as Admin „Kundensicht“.
    @MainActor
    static func buildSnapshotWithWallet(
        for user: User?,
        investorCashBalanceService _: any InvestorCashBalanceServiceProtocol,
        paymentService: (any PaymentServiceProtocol)?,
        settlementAPIService: (any SettlementAPIServiceProtocol)? = nil,
        configurationService: (any ConfigurationServiceProtocol)? = nil
    ) async -> InvestorAccountStatementSnapshot {
        let openingBalance = configurationService?.initialAccountBalance
            ?? CalculationConstants.Account.initialInvestorBalance

        guard let user else {
            return InvestorAccountStatementSnapshot(
                entries: [],
                openingBalance: openingBalance,
                closingBalance: openingBalance
            )
        }

        let serverOnly = configurationService?.investorStatementServerOnly ?? true

        guard let settlementService = settlementAPIService else {
            let walletEntries = await loadWalletEntries(for: user, paymentService: paymentService)
            let recalculated = self.recalculateBalanceAfter(entries: walletEntries, openingBalance: openingBalance)
            let sorted = AccountStatementEntry.sortedForChronologicalDisplay(recalculated)
            return InvestorAccountStatementSnapshot(
                entries: sorted,
                openingBalance: openingBalance,
                closingBalance: sorted.last?.balanceAfter ?? openingBalance
            )
        }

        let fetchResult = await self.fetchBackendStatement(
            settlementAPIService: settlementService,
            monetaryServerOnly: serverOnly
        )

        guard !fetchResult.entries.isEmpty else {
            return InvestorAccountStatementSnapshot(
                entries: [],
                openingBalance: openingBalance,
                closingBalance: openingBalance
            )
        }

        let backendSorted = AccountStatementEntry.sortedForChronologicalDisplay(fetchResult.entries)
        let backendIncludesWallet = backendSorted.contains {
            $0.category == .walletDeposit || $0.category == .walletWithdrawal
        }

        if backendIncludesWallet {
            return InvestorAccountStatementSnapshot(
                entries: backendSorted,
                openingBalance: openingBalance,
                closingBalance: backendSorted.last?.balanceAfter ?? openingBalance
            )
        }

        let walletEntries = await loadWalletEntries(for: user, paymentService: paymentService)
        guard !walletEntries.isEmpty else {
            return InvestorAccountStatementSnapshot(
                entries: backendSorted,
                openingBalance: openingBalance,
                closingBalance: backendSorted.last?.balanceAfter ?? openingBalance
            )
        }

        let recalculated = self.recalculateBalanceAfter(
            entries: backendSorted + walletEntries,
            openingBalance: openingBalance
        )
        let sorted = AccountStatementEntry.sortedForChronologicalDisplay(recalculated)
        return InvestorAccountStatementSnapshot(
            entries: sorted,
            openingBalance: openingBalance,
            closingBalance: sorted.last?.balanceAfter ?? openingBalance
        )
    }

    // MARK: - Backend Integration

    @MainActor
    private static func fetchBackendStatement(
        settlementAPIService: any SettlementAPIServiceProtocol,
        monetaryServerOnly: Bool
    ) async -> InvestorBackendStatementFetch {
        do {
            var allBackendEntries: [BackendAccountEntry] = []
            var skip = 0
            let pageSize = 200
            var timelineTruncated = false
            repeat {
                let response = try await settlementAPIService.fetchAccountStatement(
                    limit: pageSize,
                    skip: skip,
                    entryType: nil
                )
                if response.timelineTruncated == true {
                    timelineTruncated = true
                }
                allBackendEntries.append(contentsOf: response.entries)
                skip += response.entries.count
                if !response.hasMore || response.entries.isEmpty { break }
            } while skip < 2_000

            guard !allBackendEntries.isEmpty else {
                if monetaryServerOnly {
                    InvestorCollectionBillLog.warning(InvestorMonetaryMessages.accountStatementUnavailable)
                }
                return InvestorBackendStatementFetch(entries: [], timelineTruncated: timelineTruncated)
            }

            let converted = allBackendEntries.compactMap { self.convertBackendEntry($0) }
            return InvestorBackendStatementFetch(entries: converted, timelineTruncated: timelineTruncated)
        } catch {
            if monetaryServerOnly {
                InvestorCollectionBillLog.warning(
                    "InvestorAccountStatementBuilder: \(InvestorMonetaryMessages.accountStatementUnavailable) — \(error.localizedDescription)"
                )
            }
            return InvestorBackendStatementFetch(entries: [], timelineTruncated: false)
        }
    }

    /// Converts a single `BackendAccountEntry` to a display `AccountStatementEntry`.
    private static func convertBackendEntry(_ entry: BackendAccountEntry) -> AccountStatementEntry? {
        let occurredAt = entry.createdAtDate ?? Date()

        let title: String
        let direction: AccountStatementEntry.Direction
        let category: AccountStatementEntry.Category

        switch entry.entryType {
        case "commission_debit":
            title = "Commission"
            direction = .debit
            category = .commission
        case "investment_profit":
            title = "Profit Distribution"
            direction = .credit
            category = .profitDistribution
        case "residual_return":
            title = "Residual"
            direction = .credit
            category = .investment
        case "investment_activate":
            title = "Investment Activated"
            direction = .debit
            category = .investment
        case "investment_return":
            title = "Investment Return"
            direction = .credit
            category = .investment
        case "investment_refund":
            title = "Investment Refund"
            direction = .credit
            category = .investment
        case "deposit":
            title = "Deposit"
            direction = .credit
            category = .walletDeposit
        case "withdrawal":
            title = "Withdrawal"
            direction = .debit
            category = .walletWithdrawal
        case "app_service_charge":
            title = entry.description ?? entry.entryType
            direction = .debit
            category = .serviceCharge
        case let t where t.hasPrefix("investment_escrow_"):
            title = entry.description ?? entry.entryType
            direction = entry.amount >= 0 ? .credit : .debit
            category = .investment
        default:
            title = entry.description ?? entry.entryType
            direction = entry.amount >= 0 ? .credit : .debit
            category = .tradeSettlement
        }

        let amount = abs(entry.amount)

        var subtitle: String?
        if let tradeNumber = entry.tradeNumber {
            let year = entry.tradeNumberYear
                ?? TradeNumberFormatting.calendarYear(for: occurredAt)
            subtitle = TradeNumberFormatting.labeled(number: tradeNumber, year: year)
        }

        var metadata: [String: String] = ["source": entry.source ?? "backend", "backendEntryType": entry.entryType]
        if let tradeId = entry.tradeId { metadata["tradeId"] = tradeId }
        if let investmentId = entry.investmentId { metadata["investmentId"] = investmentId }
        if let investmentNumber = entry.investmentNumber, !investmentNumber.isEmpty {
            metadata["investmentNumber"] = investmentNumber
            metadata["businessReference"] = investmentNumber
        } else if let businessReference = entry.businessReference, !businessReference.isEmpty {
            metadata["businessReference"] = businessReference
        }
        if let tradeNumber = entry.tradeNumber {
            let year = entry.tradeNumberYear
                ?? TradeNumberFormatting.calendarYear(for: occurredAt)
            metadata["tradeNumber"] = TradeNumberFormatting.display(number: tradeNumber, year: year)
        }
        if let referenceDocumentId = entry.referenceDocumentId, !referenceDocumentId.isEmpty {
            metadata["referenceDocumentId"] = referenceDocumentId
        }
        if let referenceDocumentNumber = entry.referenceDocumentNumber, !referenceDocumentNumber.isEmpty {
            metadata["referenceDocumentNumber"] = referenceDocumentNumber
        }

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

    // MARK: - Private Helper Methods

    /// Loads wallet transactions for the given user
    private static func loadWalletEntries(
        for user: User,
        paymentService: (any PaymentServiceProtocol)?
    ) async -> [AccountStatementEntry] {
        guard let paymentService else {
            return []
        }

        do {
            let walletTransactions = try await paymentService.getTransactionHistory(limit: 1_000, offset: 0)
            let userWalletTransactions = walletTransactions.filter { $0.userId == user.id }

            return userWalletTransactions.map { transaction in
                AccountStatementEntry.from(transaction: transaction)
            }
        } catch {
            print(
                "⚠️ InvestorAccountStatementBuilder: Wallet transactions unavailable (\(error.localizedDescription)) — showing investment-based entries only"
            )
            return []
        }
    }

    /// Recalculates balanceAfter for supplemental wallet rows only (backend rows keep server `balanceAfter`).
    private static func recalculateBalanceAfter(
        entries: [AccountStatementEntry],
        openingBalance: Double
    ) -> [AccountStatementEntry] {
        let sortedEntries = AccountStatementEntry.sortedForChronologicalDisplay(entries)
        var runningBalance = openingBalance
        var recalculatedEntries: [AccountStatementEntry] = []

        for entry in sortedEntries {
            runningBalance += entry.signedAmount

            let recalculatedEntry = AccountStatementEntry(
                id: entry.id,
                title: entry.title,
                subtitle: entry.subtitle,
                occurredAt: entry.occurredAt,
                amount: entry.amount,
                direction: entry.direction,
                category: entry.category,
                reference: entry.reference,
                referenceDocumentId: entry.referenceDocumentId,
                referenceDocumentNumber: entry.referenceDocumentNumber,
                metadata: entry.metadata,
                balanceAfter: runningBalance,
                valueDate: entry.valueDate
            )
            recalculatedEntries.append(recalculatedEntry)
        }

        return recalculatedEntries
    }
}
