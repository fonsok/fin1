import Foundation

struct InvestorAccountStatementSnapshot {
    let entries: [AccountStatementEntry]
    let openingBalance: Double
    let closingBalance: Double
}

enum InvestorAccountStatementBuilder {
    /// Builds an investor account statement snapshot including wallet transactions.
    /// Uses backend `AccountStatement` entries when `settlementAPIService` is provided,
    /// falling back to local `investorCashBalanceService` ledger entries otherwise.
    ///
    /// When `configurationService` is provided, opening balance matches admin / `getConfig`
    /// (`initialAccountBalance`), and closing balance is derived from ledger + wallet entries
    /// (same basis as trader statements). Otherwise the legacy path infers opening from
    /// `investorCashBalanceService` cache, which can drift from server configuration.
    @MainActor
    static func buildSnapshotWithWallet(
        for user: User?,
        investorCashBalanceService: any InvestorCashBalanceServiceProtocol,
        paymentService: (any PaymentServiceProtocol)?,
        settlementAPIService: (any SettlementAPIServiceProtocol)? = nil,
        configurationService: (any ConfigurationServiceProtocol)? = nil
    ) async -> InvestorAccountStatementSnapshot {
        guard let user = user else {
            let initialBalance = configurationService?.initialAccountBalance
                ?? CalculationConstants.Account.initialInvestorBalance
            return InvestorAccountStatementSnapshot(
                entries: [],
                openingBalance: initialBalance,
                closingBalance: initialBalance
            )
        }

        let serviceBalance = investorCashBalanceService.getBalance(for: user.id)
        let walletEntries = await loadWalletEntries(for: user, paymentService: paymentService)

        // Try backend entries first; fall back to local ledger
        let investmentEntries: [AccountStatementEntry]
        let serverOnly = configurationService?.investorMonetaryServerOnly ?? false
        if let settlementService = settlementAPIService {
            investmentEntries = await self.loadBackendEntries(
                for: user,
                settlementAPIService: settlementService,
                investorCashBalanceService: investorCashBalanceService,
                monetaryServerOnly: serverOnly
            )
        } else if serverOnly {
            investmentEntries = []
        } else {
            investmentEntries = investorCashBalanceService.getTransactions(for: user.id)
        }

        let allEntries = investmentEntries + walletEntries
        let openingBalance: Double
        if let configurationService {
            openingBalance = configurationService.initialAccountBalance
        } else {
            openingBalance = self.calculateOpeningBalance(serviceBalance: serviceBalance, entries: allEntries)
        }
        let recalculatedEntries = self.recalculateBalanceAfter(entries: allEntries, openingBalance: openingBalance)
        let closingBalance: Double
        if configurationService != nil {
            closingBalance = recalculatedEntries.last?.balanceAfter ?? openingBalance
        } else {
            closingBalance = serviceBalance
        }

        return InvestorAccountStatementSnapshot(
            entries: AccountStatementEntry.sortedForChronologicalDisplay(recalculatedEntries),
            openingBalance: openingBalance,
            closingBalance: closingBalance
        )
    }

    // MARK: - Backend Integration

    /// Fetches investor account statement entries from the backend and converts them
    /// to `AccountStatementEntry` objects. Falls back to the local ledger on error.
    @MainActor
    private static func loadBackendEntries(
        for user: User,
        settlementAPIService: any SettlementAPIServiceProtocol,
        investorCashBalanceService: any InvestorCashBalanceServiceProtocol,
        monetaryServerOnly: Bool
    ) async -> [AccountStatementEntry] {
        do {
            var allBackendEntries: [BackendAccountEntry] = []
            var skip = 0
            let pageSize = 200
            repeat {
                let response = try await settlementAPIService.fetchAccountStatement(
                    limit: pageSize, skip: skip, entryType: nil
                )
                allBackendEntries.append(contentsOf: response.entries)
                skip += response.entries.count
                if !response.hasMore || response.entries.isEmpty { break }
            } while skip < 2_000

            guard !allBackendEntries.isEmpty else {
                if monetaryServerOnly {
                    InvestorCollectionBillLog.warning(InvestorMonetaryMessages.accountStatementUnavailable)
                    return []
                }
                return investorCashBalanceService.getTransactions(for: user.id)
            }
            let converted = allBackendEntries.compactMap { self.convertBackendEntry($0) }
            if Self.backendInvestorTimelineIncludesMergedEscrows(converted) {
                return converted
            }
            return self.mergeMissingLocalEscrowReserves(
                backend: converted,
                local: investorCashBalanceService.getTransactions(for: user.id),
                monetaryServerOnly: monetaryServerOnly
            )
        } catch {
            if monetaryServerOnly {
                InvestorCollectionBillLog.warning(
                    "InvestorAccountStatementBuilder: \(InvestorMonetaryMessages.accountStatementUnavailable) — \(error.localizedDescription)"
                )
                return []
            }
            print("⚠️ InvestorAccountStatementBuilder: Backend entries unavailable (\(error.localizedDescription)) — using local ledger")
            return investorCashBalanceService.getTransactions(for: user.id)
        }
    }

    /// When `getAccountStatement` already returns the merged investor timeline (AccountStatement + AVA AppLedger),
    /// do not merge in local cash-balance lines — they duplicate escrow legs and look like an extra „GoB“ layer.
    private static func backendInvestorTimelineIncludesMergedEscrows(_ backend: [AccountStatementEntry]) -> Bool {
        backend.contains { entry in
            if entry.metadata["source"] == "app_subledger" { return true }
            let t = entry.metadata["backendEntryType"] ?? ""
            if t.hasPrefix("investment_escrow_") { return true }
            return false
        }
    }

    /// When the API returns only `AccountStatement` rows (e.g. after first buy) but escrow
    /// reserves live in `AppLedgerEntry`, keep local reserve lines until the backend merge includes them.
    private static func mergeMissingLocalEscrowReserves(
        backend: [AccountStatementEntry],
        local: [AccountStatementEntry],
        monetaryServerOnly: Bool
    ) -> [AccountStatementEntry] {
        guard !monetaryServerOnly else { return backend }

        let backendReserveInvestmentIds = Set(
            backend.compactMap { entry -> String? in
                guard entry.category == .investment, entry.direction == .debit else { return nil }
                let type = entry.metadata["backendEntryType"] ?? ""
                if type == "investment_escrow_reserve" || type.isEmpty {
                    return entry.metadata["investmentId"]
                }
                return nil
            }
        )

        let supplemental = local.filter { localEntry in
            guard localEntry.category == .investment,
                  localEntry.direction == .debit,
                  let investmentId = localEntry.metadata["investmentId"],
                  !investmentId.isEmpty else { return false }
            return !backendReserveInvestmentIds.contains(investmentId)
        }

        guard !supplemental.isEmpty else { return backend }
        return backend + supplemental
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
            subtitle = String(format: "Trade #%03d", tradeNumber)
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
        if let tradeNumber = entry.tradeNumber { metadata["tradeNumber"] = String(format: "%03d", tradeNumber) }
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
        guard let paymentService = paymentService else {
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

    /// Calculates the opening balance from service balance and all entries
    /// - Parameters:
    ///   - serviceBalance: Current balance from service
    ///   - entries: All account statement entries
    /// - Returns: Calculated opening balance
    private static func calculateOpeningBalance(
        serviceBalance: Double,
        entries: [AccountStatementEntry]
    ) -> Double {
        let totalDelta = entries.reduce(0.0) { $0 + $1.signedAmount }
        let calculatedOpening = serviceBalance - totalDelta
        return max(0, calculatedOpening)
    }

    /// Recalculates balanceAfter for all entries in chronological order
    /// - Parameters:
    ///   - entries: All account statement entries
    ///   - openingBalance: Opening balance to start from
    /// - Returns: Array of entries with recalculated balanceAfter values
    private static func recalculateBalanceAfter(
        entries: [AccountStatementEntry],
        openingBalance: Double
    ) -> [AccountStatementEntry] {
        let sortedEntries = AccountStatementEntry.sortedForChronologicalDisplay(entries)
        var runningBalance = openingBalance
        var recalculatedEntries: [AccountStatementEntry] = []

        for entry in sortedEntries {
            // Update running balance
            runningBalance += entry.signedAmount

            // Create new entry with recalculated balanceAfter
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
