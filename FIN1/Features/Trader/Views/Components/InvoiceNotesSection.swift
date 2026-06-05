import SwiftUI

// MARK: - Invoice Notes Section
/// Displays tax and legal notes for the invoice
/// Uses DocumentNotesSection for DRY compliance
struct InvoiceNotesSection: View {
    let invoice: Invoice
    @Environment(\.appServices) private var appServices

    private var resolvedTaxNote: String? {
        switch self.invoice.type {
        case .appServiceCharge, .commissionInvoice:
            return self.invoice.taxNote
        case .securitiesSettlement, .tradingFee, .creditNote:
            let mode = self.appServices.configurationService.taxCollectionMode
            let side = DocumentTaxNoteTexts.capitalGainsSide(for: self.invoice.transactionType)
            return DocumentTaxNoteTexts.capitalGainsBody(mode: mode, side: side)
        case .accountStatement:
            return self.invoice.taxNote
        }
    }

    var body: some View {
        DocumentNotesSection(
            accountNumber: self.invoice.customerInfo.depotNumber,
            taxNote: self.resolvedTaxNote,
            legalNote: self.invoice.legalNote
        )
    }
}

// MARK: - Preview
#Preview {
    InvoiceNotesSection(invoice: Invoice.sampleInvoice())
        .responsivePadding()
}
