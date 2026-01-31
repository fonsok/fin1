import SwiftUI

// MARK: - Transaction Row
struct TransactionRow: View {
    let transaction: TransactionDetails
    let label: String?

    init(transaction: TransactionDetails, label: String? = nil) {
        self.transaction = transaction
        self.label = label ?? transaction.type.displayName
    }

    var body: some View {
        HStack {
            Text(label ?? transaction.type.displayName)
                .tradeCalculationBoldStyle()
            Spacer()
            Text(String(format: "%.0f", transaction.quantity))
                .tradeCalculationValueStyle()
            Spacer()
            Text(transaction.price.formatted(.number.precision(.fractionLength(2))))
                .tradeCalculationValueStyle()
            Spacer()
            Text(transaction.amount.formatted(.currency(code: "EUR")))
                .tradeCalculationValueStyle()
        }
        .padding(.vertical, ResponsiveDesign.spacing(4))
        .padding(.horizontal, ResponsiveDesign.spacing(12))
    }
}
