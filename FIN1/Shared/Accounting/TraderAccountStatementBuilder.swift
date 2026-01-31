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

        let sortedInvoices = invoices.sorted { $0.createdAt < $1.createdAt }
        var runningBalance = openingBalance
        var entries: [AccountStatementEntry] = []

        for invoice in sortedInvoices {
            // Handle Credit Note invoices (commission payments)
            if invoice.type == .creditNote {
                let entry = createCommissionEntry(from: invoice, runningBalance: &runningBalance)
                entries.append(entry)
                continue
            }

            // Handle regular trade invoices (buy/sell)
            guard let transactionType = invoice.transactionType else { continue }
            let direction: AccountStatementEntry.Direction = transactionType == .sell ? .credit : .debit
            let amount = invoice.totalAmount
            runningBalance += direction == .credit ? amount : -amount

            let reference = invoice.tradeId ?? invoice.invoiceNumber
            let subtitle: String? = {
                if let tradeNumber = invoice.tradeNumber {
                    return String(format: "Trade #%03d", tradeNumber)
                }
                return nil
            }()

            // Extract primary securities line (WKN/ISIN, direction, underlying, strike, issuer...)
            let primarySecuritiesItem = invoice.items.first { $0.itemType == .securities }
            let securitiesDescription = primarySecuritiesItem?.description ?? ""

            // Split description "WKN/ISIN - DIRECTION - UNDERLYING - STRIKE - ISSUER" into components
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

            // Enrich metadata with trade/securities details for clearer statements
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

            // Quantity from primary securities item, if present
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

        return TraderAccountStatementSnapshot(
            entries: entries,
            openingBalance: openingBalance,
            closingBalance: runningBalance
        )
    }

    /// Builds a trader account statement snapshot including wallet transactions
    /// This is the single source of truth for trader balance calculation
    /// - Parameters:
    ///   - user: The trader user
    ///   - invoiceService: Service for fetching trade invoices
    ///   - configurationService: Service for initial balance configuration
    ///   - paymentService: Optional service for wallet transactions
    /// - Returns: Snapshot with trading + wallet transactions and combined balance
    /// - Throws: AppError if wallet transactions cannot be loaded
    static func buildSnapshotWithWallet(
        for user: User?,
        invoiceService: any InvoiceServiceProtocol,
        configurationService: any ConfigurationServiceProtocol,
        paymentService: (any PaymentServiceProtocol)?
    ) async throws -> TraderAccountStatementSnapshot {
        // Build base snapshot from trading transactions (invoices)
        let baseSnapshot = buildSnapshot(
            for: user,
            invoiceService: invoiceService,
            configurationService: configurationService
        )

        // Load wallet transactions if payment service is available
        let (walletEntries, walletDelta) = try await loadWalletEntriesAndDelta(
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

    // MARK: - Private Helper Methods

    /// Loads wallet transactions and calculates delta for the given user
    /// - Parameters:
    ///   - user: The trader user
    ///   - paymentService: Optional payment service
    /// - Returns: Tuple of (wallet entries, wallet delta)
    /// - Throws: AppError if loading fails
    private static func loadWalletEntriesAndDelta(
        for user: User?,
        paymentService: (any PaymentServiceProtocol)?
    ) async throws -> ([AccountStatementEntry], Double) {
        guard let paymentService = paymentService,
              let userId = user?.id else {
            return ([], 0.0)
        }

        do {
            let walletTransactions = try await paymentService.getTransactionHistory(limit: 1000, offset: 0)
            let userWalletTransactions = walletTransactions.filter { $0.userId == userId }

            // Convert to AccountStatementEntry
            let walletEntries = userWalletTransactions.map { transaction in
                AccountStatementEntry.from(transaction: transaction)
            }

            // Calculate wallet delta (deposits - withdrawals)
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
            // Map error to AppError and throw
            throw AppError.service(.operationFailed)
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

    /// Creates an account statement entry for a commission credit note
    /// - Parameters:
    ///   - invoice: The credit note invoice
    ///   - runningBalance: The running balance (updated in place)
    /// - Returns: An account statement entry for the commission deposit
    private static func createCommissionEntry(
        from invoice: Invoice,
        runningBalance: inout Double
    ) -> AccountStatementEntry {
        // Commission is always a credit (deposit) for the trader
        let amount = abs(invoice.totalAmount)
        runningBalance += amount

        // Extract trade numbers from commission description
        let commissionItem = invoice.items.first { $0.itemType == .commission }
        let description = commissionItem?.description ?? invoice.invoiceNumber

        // Parse trade numbers from description (e.g., "Trade #001, Trade #002")
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
            occurredAt: invoice.createdAt,
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
        // CRITICAL: Only use user-specific identifiers for proper trade isolation
        // The user.id (e.g., "user:trader1@test.com") should match the invoice's customerNumber
        // which is now set to order.traderId when invoices are created
        let possibleCustomerNumbers = [
            user.id,  // Primary identifier - matches order.traderId used in invoice creation
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
