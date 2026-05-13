import SwiftUI

// MARK: - Invoice Notes Section
/// Displays tax and legal notes for the invoice
/// Uses DocumentNotesSection for DRY compliance
struct InvoiceNotesSection: View {
    let invoice: Invoice

    var body: some View {
        DocumentNotesSection(
            accountNumber: self.invoice.customerInfo.depotNumber,
            taxNote: self.invoice.taxNote,
            legalNote: self.invoice.legalNote
        )
    }
}

// MARK: - Preview
#Preview {
    InvoiceNotesSection(invoice: Invoice.sampleInvoice())
        .responsivePadding()
}
