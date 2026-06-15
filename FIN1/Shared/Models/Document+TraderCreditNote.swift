import Foundation

// MARK: - Trader credit note (CN-) presentation helpers

extension Document {

    /// User-facing trade number for a trader commission credit note (Parse `tradeNumber`, invoice, filename).
    var resolvedTraderCreditNoteTradeNumber: Int? {
        if let tradeNumber { return tradeNumber }
        if let invoiceNumber = invoiceData?.tradeNumber { return invoiceNumber }
        return Self.parseTradeNumberFromCreditNoteName(self.name)
    }

    /// e.g. `Trade #001`
    var traderCreditNoteTradeReferenceLabel: String? {
        guard let number = resolvedTraderCreditNoteTradeNumber else { return nil }
        return String(format: "Trade #%03d", number)
    }

    var traderCreditNoteNavigationTitle: String {
        if let reference = traderCreditNoteTradeReferenceLabel {
            return "Gutschrift (\(reference))"
        }
        return "Gutschrift"
    }

    /// Notifications → Documents subtitle (always includes trade when known).
    var traderCreditNoteInboxSubtitle: String {
        if let reference = traderCreditNoteTradeReferenceLabel {
            return "Gutschrift Provision · \(reference)"
        }
        return "Gutschrift Provision"
    }

    static func parseTradeNumberFromCreditNoteName(_ name: String) -> Int? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let patterns = [
            #"CreditNote_Trade(\d+)"#,
            #"CollectionBill_Trade(\d+)"#,
            #"Trade[_\s#]*(\d+)"#,
            #"Gutschrift\s+Trade\s*#?(\d+)"#,
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
                  let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
                  match.numberOfRanges > 1,
                  let range = Range(match.range(at: 1), in: trimmed),
                  let number = Int(trimmed[range]) else {
                continue
            }
            return number
        }
        return nil
    }
}
