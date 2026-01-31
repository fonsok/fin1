import SwiftUI

// MARK: - Subtotal Row
struct SubtotalRow: View {
    let amount: Double
    let label: String

    var body: some View {
        HStack {
            Text(label)
                .tradeCalculationMediumStyle()
            Spacer()
            Text("")
            Spacer()
            Text("")
            Spacer()
            Text(amount.formatted(.currency(code: "EUR")))
                .tradeCalculationMediumStyle()
        }
        .padding(.vertical, ResponsiveDesign.spacing(4))
        .padding(.horizontal, ResponsiveDesign.spacing(12))
        .background(AppTheme.inputFieldBackground.opacity(0.3))
    }
}
