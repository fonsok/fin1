import SwiftUI

// MARK: - Investment Document & Invoice Reference View (MVVM: nur Darstellung)
/// Zeigt Belegnummer (Verrechnung) und Rechnungsnummer; Daten kommen aus ViewModel, keine Service-Aufrufe in der View.
struct InvestmentDocRefView: View {
    let verrechnungNumber: String?
    let rechnungNumber: String?

    var body: some View {
        if verrechnungNumber != nil || rechnungNumber != nil {
            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(2)) {
                if let docNumber = verrechnungNumber {
                    Text("Verrechnung: \(docNumber)")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.fontColor)
                        .lineLimit(1)
                }
                if let invoiceNumber = rechnungNumber {
                    Text("Rechnung: \(invoiceNumber)")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.fontColor)
                        .lineLimit(1)
                }
            }
        } else {
            Text("—")
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.6))
        }
    }
}
