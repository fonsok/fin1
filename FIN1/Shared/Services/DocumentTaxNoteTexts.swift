import Foundation

/// Capital-gains tax notice body texts for documents (Invoices, Collection Bills, Credit Notes).
/// Service-charge / VAT notes are unchanged — see `LegalSnippetKey.docTaxNoteServiceCharge`.
enum DocumentTaxNoteTexts {
    /// Shown under „Steuerlicher Hinweis“ when `taxCollectionMode` is `customer_self_reports`.
    static let customerSelfReportsCapitalGainsNote =
        "Allgemein: Grundsätzlich wird Abgeltungssteuer nicht an Finanzamt überwiesen."

    static var platformWithholdsSellDefault: String {
        "Beim Verkauf erfolgt die Besteuerung gemäß Abgeltungsteuer (dzt. \(CalculationConstants.TaxRates.capitalGainsTaxWithSoli)) auf den realisierten Gewinn. Die Steuer wird automatisch von der Bank einbehalten."
    }

    static var platformWithholdsBuyDefault: String {
        "Beim Kauf werden keine Steuern abgezogen. Die Besteuerung erfolgt erst beim Verkauf bzw. Gewinnrealisierung gemäß Abgeltungsteuer (dzt. \(CalculationConstants.TaxRates.capitalGainsTaxWithSoli))."
    }

    enum CapitalGainsSide {
        case buy
        case sell
    }

    static func capitalGainsBody(mode: TaxCollectionMode, side: CapitalGainsSide) -> String {
        if mode.isCustomerSelfReports {
            return self.customerSelfReportsCapitalGainsNote
        }
        switch side {
        case .buy:
            return self.platformWithholdsBuyDefault
        case .sell:
            return self.platformWithholdsSellDefault
        }
    }

    static func legalSnippetKey(mode: TaxCollectionMode, side: CapitalGainsSide) -> LegalSnippetKey {
        if mode.isCustomerSelfReports {
            return .docTaxNoteCustomerSelfReports
        }
        switch side {
        case .buy:
            return .docTaxNoteBuy
        case .sell:
            return .docTaxNoteSell
        }
    }

    static func capitalGainsSide(for transactionType: TransactionType?) -> CapitalGainsSide {
        transactionType == .buy ? .buy : .sell
    }
}
