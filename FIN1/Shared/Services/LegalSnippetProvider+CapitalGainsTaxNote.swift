import Foundation

extension LegalSnippetProvider {
    /// Loads the Abgeltungsteuer document notice for invoices, collection bills, and credit notes.
    func loadCapitalGainsTaxNote(
        mode: TaxCollectionMode,
        side: DocumentTaxNoteTexts.CapitalGainsSide,
        language: TermsOfServiceDataProvider.Language = .german,
        documentType: LegalDocumentType = .terms,
        taxRatePlaceholder: String = CalculationConstants.TaxRates.capitalGainsTaxWithSoli
    ) async -> String {
        await self.text(
            for: DocumentTaxNoteTexts.legalSnippetKey(mode: mode, side: side),
            language: language,
            documentType: documentType,
            defaultText: DocumentTaxNoteTexts.capitalGainsBody(mode: mode, side: side),
            placeholders: ["TAX_RATE": taxRatePlaceholder]
        )
    }
}
