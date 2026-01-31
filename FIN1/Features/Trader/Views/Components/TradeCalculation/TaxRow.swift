import SwiftUI

// MARK: - Tax Row
struct TaxRow: View {
    let name: String
    let base: Double
    let rate: String
    let amount: Double

    var body: some View {
        HStack {
            Text(name)
                .tradeCalculationFeeTaxStyle()
            Spacer()
            Text(base.formatted(.number.precision(.fractionLength(2))))
                .tradeCalculationFeeTaxStyle()
            Spacer()
            Text(rate)
                .tradeCalculationFeeTaxStyle()
            Spacer()
            Text(amount.formatted(.currency(code: "EUR")))
                .tradeCalculationFeeTaxStyle()
        }
        .padding(.vertical, ResponsiveDesign.spacing(4))
        .padding(.horizontal, ResponsiveDesign.spacing(12))
    }
}
