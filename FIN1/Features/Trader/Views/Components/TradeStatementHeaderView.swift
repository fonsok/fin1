import SwiftUI

// MARK: - Trade Statement Header View
/// Displays the header section with account information
struct TradeStatementHeaderView: View {
    let depotNumber: String
    let depotHolder: String
    let tradeNumber: Int

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            // Title removed - already shown in DocumentHeaderView
            // Text("Sammelabrechnung\n(Wertpapierkauf/-verkauf)")

            // Trade Number
            HStack {
                Text("Trade Nr.:")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(DocumentDesignSystem.textColorSecondary)
                Spacer()
                Text(String(format: "%03d", tradeNumber))
                    .font(ResponsiveDesign.bodyFont())
                    .fontWeight(.medium)
                    .foregroundColor(DocumentDesignSystem.textColor)
            }

            // Account Information
            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
                HStack {
                    Text("Ihre Depotnummer:")
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(DocumentDesignSystem.textColorSecondary)
                    Spacer()
                    Text(depotNumber)
                        .font(ResponsiveDesign.bodyFont())
                        .fontWeight(.medium)
                        .foregroundColor(DocumentDesignSystem.textColor)
                }

                // Depotinhaber removed - already shown in DocumentHeaderView with address
            }
        }
        .documentSection(level: 2)
    }
}

// MARK: - Preview
#if DEBUG
struct TradeStatementHeaderView_Previews: PreviewProvider {
    static var previews: some View {
        TradeStatementHeaderView(
            depotNumber: "104801",
            depotHolder: "Max Mustermann",
            tradeNumber: 1
        )
        .padding()
    }
}
#endif
