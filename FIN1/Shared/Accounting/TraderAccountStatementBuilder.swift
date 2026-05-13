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

        let invoices = self.fetchInvoices(for: user, invoiceService: invoiceService)
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
            let entry = self.createCommissionEntry(
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

    /// Creates an account statement entry for a commission credit note.
    /// - Parameters:
    ///   - invoice: The credit note invoice
    ///   - runningBalance: The running balance (updated in place)
    ///   - adjustedDate: If provided, overrides `invoice.createdAt` for the
    ///     entry's `occurredAt`. Used to place the commission row after the
    ///     trade's last settlement entry in chronological order.
    static func createCommissionEntry(
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
            referenceDocumentId: nil,
            referenceDocumentNumber: invoice.invoiceNumber,
            metadata: metadata,
            balanceAfter: runningBalance
        )
    }

    static func fetchInvoices(
        for user: User,
        invoiceService: any InvoiceServiceProtocol
    ) -> [Invoice] {
        let possibleCustomerNumbers = [
            user.id,
            user.customerNumber
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
