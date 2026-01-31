import SwiftUI

// MARK: - Trade Statement Reference Section
/// Displays reference information and legal disclaimer
struct TradeStatementReferenceSection: View {
    let taxReportTransactionNumber: String
    let accountNumber: String
    let legalDisclaimer: String

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(16)) {
            // Reference Information
            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
                Text("Der Differenzbetrag zwischen ∑ Ergebnis vor Steuern und dem auf Ihrem Konto überwiesenen Betrag resultiert aus dem Steuerabzug. Dies wird gemäß den gesetzlichen Vorgaben durchgeführt und transparent in Ihren Kontoauszügen sowie Steuerunterlagen ausgewiesen.\nSteuerpflicht besteht nur, wenn der Verkaufserlös die Anschaffungskosten übersteigt. Die Berechnung basiert auf dem Prinzip der Verrechnung der Kauf- und Verkaufskosten (First-in-First-out oder Durchschnittskostenermittlung).\nDetails dazu finden Sie im Steuerreport unter der Transaktion-Nr.:")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(DocumentDesignSystem.textColorSecondary)

                Text(taxReportTransactionNumber)
                    .font(ResponsiveDesign.bodyFont())
                    .fontWeight(.medium)
                    .foregroundColor(DocumentDesignSystem.textColor)

                Text("Die Verrechnung der Endbeträge erfolgt über Ihr Konto Nr.:")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(DocumentDesignSystem.textColorSecondary)
                    .padding(.top, ResponsiveDesign.spacing(4))

                Text(accountNumber)
                    .font(ResponsiveDesign.bodyFont())
                    .fontWeight(.medium)
                    .foregroundColor(DocumentDesignSystem.textColor)
            }
            .documentSection(level: 4)

            // Legal Disclaimer
            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
                Text(legalDisclaimer)
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(DocumentDesignSystem.textColorSecondary)
                    .multilineTextAlignment(.leading)

                // Additional disclaimer text
                Text("Diese Mitteilung ist maschinell erstellt und wird nicht unterschrieben.\nFür weitergehende Fragen wenden Sie sich bitte an Ihr Fin1-Service-Team.")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(DocumentDesignSystem.textColorSecondary)
                    .multilineTextAlignment(.leading)
                    .padding(.top, ResponsiveDesign.spacing(8))
            }
            .documentSection(level: 4)
        }
    }
}

// MARK: - Preview
#if DEBUG
struct TradeStatementReferenceSection_Previews: PreviewProvider {
    static var previews: some View {
        TradeStatementReferenceSection(
            taxReportTransactionNumber: "288/1",
            accountNumber: "DE89 3704 0044 0532 0130 00",
            legalDisclaimer: "Dieses Dokument dient als Beleg für Ihre Wertpapiergeschäfte..."
        )
        .padding()
    }
}
#endif
