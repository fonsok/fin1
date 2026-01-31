import SwiftUI

// MARK: - Credit Note Commission Table View
/// Displays the commission breakdown table for a credit note
/// Extracted from TraderCreditNoteDetailView to reduce file size
struct CreditNoteCommissionTableView: View {
    let items: [CreditNoteBreakdownItem]
    let totalCommission: Double
    let commissionRateFormatted: String

    var body: some View {
        VStack(spacing: 0) {
            tableHeader
            tableRows
            totalRow
        }
        .cornerRadius(ResponsiveDesign.spacing(8))
        .overlay(
            RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(8))
                .stroke(AppTheme.fontColor.opacity(0.1), lineWidth: 1)
        )
    }

    // MARK: - Table Header
    private var tableHeader: some View {
        HStack(spacing: ResponsiveDesign.spacing(8)) {
            Text("Investor")
                .font(ResponsiveDesign.bodyFont())
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.inputFieldText)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("Gross profit")
                .font(ResponsiveDesign.captionFont())
                .fontWeight(.regular)
                .foregroundColor(AppTheme.inputFieldText)
                .frame(width: 90, alignment: .trailing)

            Text("× \(commissionRateFormatted)")
                .font(ResponsiveDesign.captionFont())
                .fontWeight(.regular)
                .foregroundColor(AppTheme.inputFieldText)
                .frame(width: 55, alignment: .center)

            Text("Commission")
                .font(ResponsiveDesign.captionFont())
                .fontWeight(.regular)
                .foregroundColor(AppTheme.inputFieldText)
                .frame(width: 80, alignment: .trailing)
        }
        .padding(.horizontal, ResponsiveDesign.spacing(12))
        .padding(.vertical, ResponsiveDesign.spacing(10))
        .background(AppTheme.inputFieldBackground)
    }

    // MARK: - Table Rows
    private var tableRows: some View {
        ForEach(items) { item in
            HStack(spacing: ResponsiveDesign.spacing(8)) {
                Text(item.investorName)
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(formatCurrency(item.grossProfit))
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor)
                    .frame(width: 90, alignment: .trailing)

                Text("=")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.6))
                    .frame(width: 55, alignment: .center)

                Text(formatCurrency(item.commission))
                    .font(ResponsiveDesign.bodyFont())
                    .fontWeight(.regular)
                    .foregroundColor(AppTheme.fontColor)
                    .frame(width: 80, alignment: .trailing)
            }
            .padding(.horizontal, ResponsiveDesign.spacing(12))
            .padding(.vertical, ResponsiveDesign.spacing(8))
            .background(AppTheme.sectionBackground)
        }
    }

    // MARK: - Total Row
    private var totalRow: some View {
        HStack(spacing: ResponsiveDesign.spacing(8)) {
            Text("Total:")
                .font(ResponsiveDesign.bodyFont())
                .fontWeight(.regular)
                .foregroundColor(AppTheme.inputFieldText)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()
                .frame(width: 90)

            Spacer()
                .frame(width: 55)

            Text(formatCurrency(totalCommission))
                .font(ResponsiveDesign.bodyFont())
                .fontWeight(.regular)
                .foregroundColor(AppTheme.inputFieldText)
                .frame(width: 80, alignment: .trailing)
        }
        .padding(.horizontal, ResponsiveDesign.spacing(12))
        .padding(.vertical, ResponsiveDesign.spacing(10))
        .background(AppTheme.inputFieldBackground.opacity(0.7))
    }

    // MARK: - Formatting
    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        formatter.locale = Locale(identifier: "de_DE")
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? "€0,00"
    }
}











