import SwiftUI

// MARK: - Invoice Notes Section
/// Displays tax and legal notes for the invoice
/// Uses DocumentNotesSection for DRY compliance
struct InvoiceNotesSection: View {
    let invoice: Invoice

    var body: some View {
        DocumentNotesSection(
            accountNumber: invoice.customerInfo.depotNumber,
            taxNote: invoice.taxNote,
            legalNote: invoice.legalNote
        )
    }
}

// MARK: - Preview
#Preview {
    InvoiceNotesSection(invoice: Invoice.sampleInvoice())
        .responsivePadding()
}
