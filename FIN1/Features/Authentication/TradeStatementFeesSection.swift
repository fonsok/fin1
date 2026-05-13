import SwiftUI

// MARK: - Trade Statement Fees Section
/// Displays the fees breakdown
struct TradeStatementFeesSection: View {
    let feeItems: [FeeItem]

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            Text("* Enthalten sind folgende Gebühren")
                .font(ResponsiveDesign.bodyFont())
                .fontWeight(.medium)
                .foregroundColor(AppTheme.fontColor.opacity(0.8))

            VStack(spacing: ResponsiveDesign.spacing(4)) {
                ForEach(self.feeItems, id: \.name) { fee in
                    HStack {
                        Text(fee.name)
                            .font(ResponsiveDesign.bodyFont())
                            .foregroundColor(AppTheme.fontColor.opacity(0.8))
                        Spacer()
                        Text(fee.amount)
                            .font(ResponsiveDesign.bodyFont())
                    }
                }
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }
}

// MARK: - Preview
#if DEBUG
struct TradeStatementFeesSection_Previews: PreviewProvider {
    static var previews: some View {
        let sampleFees = [
            FeeItem(name: "Ordergebühr", amount: "5,90 EUR"),
            FeeItem(name: "Börsengebühr", amount: "0,00 EUR")
        ]

        TradeStatementFeesSection(feeItems: sampleFees)
            .padding()
    }
}
#endif
