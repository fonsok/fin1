import Foundation

struct TraderAccountStatementSnapshot {
    let entries: [AccountStatementEntry]
    let openingBalance: Double
    let closingBalance: Double
}

enum TraderAccountStatementBuilder {
    static func buildSnapshot(
        for user: User?,
        invoiceService: any InvoiceServiceProtocol,
        configurationService: any ConfigurationServiceProtocol
    ) -> TraderAccountStatementSnapshot {
        let openingBalance = configurationService.initialAccountBalance
        guard let user else {
            return TraderAccountStatementSnapshot(
                entries: [],
                openingBalance: openingBalance,
                closingBalance: openingBalance
            )
        }

        let invoices = fetchInvoices(for: user, invoiceService: invoiceService)
        guard !invoices.isEmpty else {
            return TraderAccountStatementSnapshot(
                entries: [],
                openingBalance: openingBalance,
                closingBalance: openingBalance
            )
        }

        // Separate credit notes from regular invoices.
        // Credit notes represent the commission payout that happens AFTER a trade
        // completes, so they must be processed after all settlement entries.
        let regularInvoices = invoices
            .filter { $0.type != .creditNote }
            .sorted { $0.createdAt < $1.createdAt }
        let creditNotes = invoices
            .filter { $0.type == .creditNote }
            .sorted { $0.createdAt < $1.createdAt }

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
            let subtitle: String? = {
                if let tradeNumber = invoice.tradeNumber {
                    return String(format: "Trade #%03d", tradeNumber)
                }
                return nil
            }()

            let primarySecuritiesItem = invoice.items.first { $0.itemType == .securities }
            let securitiesDescription = primarySecuritiesItem?.description ?? ""

            let components = securitiesDescription
                .split(separator: "-")
                .map { $0.trimmingCharacters(in: .whitespaces) }

            let wknOrIsin = components.indices.contains(0) ? String(components[0]) : ""
            let optionDirection = components.indices.contains(1) ? String(components[1]) : ""
            let underlyingAsset = components.indices.contains(2) ? String(components[2]) : ""
            let strikePriceText = components.indices.contains(3) ? String(components[3]) : ""
            let issuer = components.indices.contains(4) ? String(components[4]) : ""

            var metadata: [String: String] = [
                "invoiceNumber": invoice.invoiceNumber,
                "tradeId": invoice.tradeId ?? "",
                "transactionType": transactionType.rawValue
            ]

            if let tradeNumber = invoice.tradeNumber {
                metadata["tradeNumber"] = String(format: "%03d", tradeNumber)
            }
            if !wknOrIsin.isEmpty {
                metadata["wknOrIsin"] = wknOrIsin
            }
            if !optionDirection.isEmpty {
                metadata["securitiesDirection"] = optionDirection
            }
            if !underlyingAsset.isEmpty {
                metadata["underlyingAsset"] = underlyingAsset
            }
            if !strikePriceText.isEmpty {
                metadata["strikePrice"] = strikePriceText
            }
            if !issuer.isEmpty {
                metadata["issuer"] = issuer
            }
            if let quantity = primarySecuritiesItem?.quantity {
                metadata["quantity"] = String(quantity)
            }

            let entry = AccountStatementEntry(
                title: transactionType.displayName,
                subtitle: subtitle,
                occurredAt: invoice.createdAt,
                amount: amount,
                direction: direction,
                category: .tradeSettlement,
                reference: reference,
                metadata: metadata,
                balanceAfter: runningBalance
            )
            entries.append(entry)
        }

        // Process credit notes AFTER all settlement entries so the running
        // balance reflects: buy → sell → commission. The occurredAt is set
        // to 1 second after the trade's latest settlement entry so the
        // commission row appears above (newest-first) the sell row.
        for creditNote in creditNotes {
            let tradeLatest = creditNote.tradeId.flatMap { latestDatePerTrade[$0] }
            let adjustedDate = max(
                creditNote.createdAt,
                tradeLatest?.addingTimeInterval(1) ?? creditNote.createdAt
            )
            let entry = createCommissionEntry(
                from: creditNote,
                runningBalance: &runningBalance,
                adjustedDate: adjustedDate
            )
            entries.append(entry)
        }

        return TraderAccountStatementSnapshot(
            entries: entries,
            openingBalance: openingBalance,
            closingBalance: runningBalance
        )
    }

    /// Builds a trader account statement snapshot including wallet transactions.
    /// Uses backend `AccountStatement` entries for commission data when available,
    /// falling back to local credit note invoices otherwise.
    static func buildSnapshotWithWallet(
        for user: User?,
        invoiceService: any InvoiceServiceProtocol,
        configurationService: any ConfigurationServiceProtocol,
        paymentService: (any PaymentServiceProtocol)?,
        settlementAPIService: (any SettlementAPIServiceProtocol)? = nil
    ) async -> TraderAccountStatementSnapshot {
        let baseSnapshot: TraderAccountStatementSnapshot

        if let settlementService = settlementAPIService {
            baseSnapshot = await buildSnapshotWithBackendCommissions(
                for: user,
                invoiceService: invoiceService,
                configurationService: configurationService,
                settlementAPIService: settlementService
            )
        } else {
            baseSnapshot = buildSnapshot(
                for: user,
                invoiceService: invoiceService,
                configurationService: configurationService
            )
        }

        let (walletEntries, walletDelta) = await loadWalletEntriesAndDelta(
            for: user,
            paymentService: paymentService
        )

        // Combine trading and wallet entries
        let allEntries = baseSnapshot.entries + walletEntries

        // Recalculate balanceAfter for all entries in chronological order
        let recalculatedEntries = recalculateBalanceAfter(
            entries: allEntries,
            openingBalance: baseSnapshot.openingBalance
        )

        // Calculate combined closing balance
        let combinedClosingBalance = baseSnapshot.closingBalance + walletDelta

        // Return entries sorted by date descending (newest first) for display
        return TraderAccountStatementSnapshot(
            entries: recalculatedEntries.sorted { $0.occurredAt > $1.occurredAt },
            openingBalance: baseSnapshot.openingBalance,
            closingBalance: combinedClosingBalance
        )
    }

    // MARK: - Backend-Hybrid Builder

    /// Builds a snapshot using local invoices for trade entries and backend
    /// `AccountStatement` records for commission entries (authoritative source).
    /// Falls back to local-only if backend is unavailable.
    private static func buildSnapshotWithBackendCommissions(
        for user: User?,
        invoiceService: any InvoiceServiceProtocol,
        configurationService: any ConfigurationServiceProtocol,
        settlementAPIService: any SettlementAPIServiceProtocol
    ) async -> TraderAccountStatementSnapshot {
        let openingBalance = configurationService.initialAccountBalance
        guard let user else {
            return TraderAccountStatementSnapshot(entries: [], openingBalance: openingBalance, closingBalance: openingBalance)
        }

        // Fetch backend commission entries
        let backendEntries: [BackendAccountEntry]
        do {
            let response = try await settlementAPIService.fetchAccountStatement(limit: 200, skip: 0, entryType: nil)
            backendEntries = response.entries
        } catch {
            // Backend unavailable — fall back to fully local snapshot
            return buildSnapshot(for: user, invoiceService: invoiceService, configurationService: configurationService)
        }

        // Build trade settlement entries from local invoices (buy/sell only)
        let invoices = fetchInvoices(for: user, invoiceService: invoiceService)
        let regularInvoices = invoices
            .filter { $0.type != .creditNote }
            .sorted { $0.createdAt < $1.createdAt }

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

            var metadata: [String: String] = [
                "invoiceNumber": invoice.invoiceNumber,
                "tradeId": invoice.tradeId ?? "",
                "transactionType": transactionType.rawValue
            ]
            if let tradeNumber = invoice.tradeNumber {
                metadata["tradeNumber"] = String(format: "%03d", tradeNumber)
            }

            entries.append(AccountStatementEntry(
                title: transactionType.displayName,
                subtitle: subtitle,
                occurredAt: invoice.createdAt,
                amount: amount,
                direction: direction,
                category: .tradeSettlement,
                reference: reference,
                metadata: metadata,
                balanceAfter: runningBalance
            ))
        }

        // Commission entries from backend (authoritative)
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

                entries.append(AccountStatementEntry(
                    title: "Gutschrift Provision",
                    subtitle: subtitle,
                    occurredAt: occurredAt,
                    amount: amount,
                    direction: .credit,
                    category: .commission,
                    reference: entry.objectId,
                    metadata: metadata,
                    balanceAfter: runningBalance
                ))
            }
        } else {
            // No backend commission entries — fall back to local credit notes
            let creditNotes = invoices.filter { $0.type == .creditNote }.sorted { $0.createdAt < $1.createdAt }
            for creditNote in creditNotes {
                let tradeLatest = creditNote.tradeId.flatMap { latestDatePerTrade[$0] }
                let adjustedDate = max(creditNote.createdAt, tradeLatest?.addingTimeInterval(1) ?? creditNote.createdAt)
                entries.append(createCommissionEntry(from: creditNote, runningBalance: &runningBalance, adjustedDate: adjustedDate))
            }
        }

        return TraderAccountStatementSnapshot(entries: entries, openingBalance: openingBalance, closingBalance: runningBalance)
    }

    // MARK: - Private Helper Methods

    /// Loads wallet transactions and calculates delta for the given user
    /// - Parameters:
    ///   - user: The trader user
    ///   - paymentService: Optional payment service
    /// - Returns: Tuple of (wallet entries, wallet delta). Returns empty on failure.
    private static func loadWalletEntriesAndDelta(
        for user: User?,
        paymentService: (any PaymentServiceProtocol)?
    ) async -> ([AccountStatementEntry], Double) {
        guard let paymentService = paymentService,
              let userId = user?.id else {
            return ([], 0.0)
        }

        do {
            let walletTransactions = try await paymentService.getTransactionHistory(limit: 1000, offset: 0)
            let userWalletTransactions = walletTransactions.filter { $0.userId == userId }

            let walletEntries = userWalletTransactions.map { transaction in
                AccountStatementEntry.from(transaction: transaction)
            }

            let walletDelta = userWalletTransactions.reduce(0.0) { total, transaction in
                switch transaction.type {
                case .deposit:
                    return total + transaction.amount
                case .withdrawal:
                    return total - transaction.amount
                default:
                    return total
                }
            }

            return (walletEntries, walletDelta)
        } catch {
            print("⚠️ TraderAccountStatementBuilder: Wallet transactions unavailable (\(error.localizedDescription)) — showing invoice-based entries only")
            return ([], 0.0)
        }
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
        let sortedEntries = entries.sorted { $0.occurredAt < $1.occurredAt }
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
                metadata: entry.metadata,
                balanceAfter: runningBalance,
                valueDate: entry.valueDate
            )
            recalculatedEntries.append(recalculatedEntry)
        }

        return recalculatedEntries
    }

    // MARK: - Commission Entry Creation

    /// Creates an account statement entry for a commission credit note.
    /// - Parameters:
    ///   - invoice: The credit note invoice
    ///   - runningBalance: The running balance (updated in place)
    ///   - adjustedDate: If provided, overrides `invoice.createdAt` for the
    ///     entry's `occurredAt`. Used to place the commission row after the
    ///     trade's last settlement entry in chronological order.
    private static func createCommissionEntry(
        from invoice: Invoice,
        runningBalance: inout Double,
        adjustedDate: Date? = nil
    ) -> AccountStatementEntry {
        let amount = abs(invoice.totalAmount)
        runningBalance += amount

        let commissionItem = invoice.items.first { $0.itemType == .commission }
        let description = commissionItem?.description ?? invoice.invoiceNumber

        var tradeNumbers: [String] = []
        let regex = try? NSRegularExpression(pattern: "Trade #(\\d+)", options: [])
        if let regex = regex {
            let range = NSRange(description.startIndex..., in: description)
            let matches = regex.matches(in: description, options: [], range: range)
            for match in matches {
                if let tradeNumRange = Range(match.range(at: 1), in: description) {
                    tradeNumbers.append(String(description[tradeNumRange]))
                }
            }
        }

        let subtitle: String
        if !tradeNumbers.isEmpty {
            if tradeNumbers.count == 1 {
                subtitle = "Trade #\(tradeNumbers[0])"
            } else {
                subtitle = "Trades #\(tradeNumbers.joined(separator: ", #"))"
            }
        } else if let tradeNumber = invoice.tradeNumber {
            subtitle = String(format: "Trade #%03d", tradeNumber)
        } else {
            subtitle = "Trader Commission"
        }

        var metadata: [String: String] = [
            "invoiceNumber": invoice.invoiceNumber,
            "invoiceType": "creditNote",
            "commissionAmount": String(format: "%.2f", amount)
        ]

        if let tradeId = invoice.tradeId {
            metadata["tradeId"] = tradeId
        }
        if let tradeNumber = invoice.tradeNumber {
            metadata["tradeNumber"] = String(format: "%03d", tradeNumber)
        }
        if !tradeNumbers.isEmpty {
            metadata["tradeNumbers"] = tradeNumbers.joined(separator: ",")
        }

        return AccountStatementEntry(
            title: "Gutschrift Provision",
            subtitle: subtitle,
            occurredAt: adjustedDate ?? invoice.createdAt,
            amount: amount,
            direction: .credit,
            category: .commission,
            reference: invoice.invoiceNumber,
            metadata: metadata,
            balanceAfter: runningBalance
        )
    }

    private static func fetchInvoices(
        for user: User,
        invoiceService: any InvoiceServiceProtocol
    ) -> [Invoice] {
        let possibleCustomerNumbers = [
            user.id,
            user.customerId
        ].filter { !$0.isEmpty }

        for number in possibleCustomerNumbers {
            let invoices = invoiceService.getInvoices(for: number)
            if !invoices.isEmpty {
                return invoices
            }
        }

        return []
    }
}
