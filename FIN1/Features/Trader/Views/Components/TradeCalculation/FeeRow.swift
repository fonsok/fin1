import SwiftUI

// MARK: - Fee Row
struct FeeRow: View {
    let fee: FeeDetail

    var body: some View {
        HStack {
            Text("- \(self.fee.name)")
                .tradeCalculationFeeTaxStyle()
            Spacer()
            Text("")
            Spacer()
            Text("")
            Spacer()
            Text(self.fee.amount.formatted(.currency(code: "EUR")))
                .tradeCalculationFeeTaxStyle()
        }
        .padding(.vertical, ResponsiveDesign.spacing(2))
        .padding(.horizontal, ResponsiveDesign.spacing(12))
    }
}
