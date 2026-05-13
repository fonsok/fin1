import SwiftUI

// MARK: - Investment Selection View
/// Displays investment allocation preview based on selected strategy
struct InvestmentSelectionView: View {
    let selectedInvestmentSelection: InvestmentSelectionStrategy
    let numberOfInvestments: Int
    let amountPerInvestment: Double

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(8)) {
            Text("Investment Allocation Preview")
                .font(ResponsiveDesign.headlineFont())
                .foregroundColor(AppTheme.fontColor)
                .frame(maxWidth: .infinity, alignment: .leading)

            MultipleInvestmentsPreview(numberOfInvestments: self.numberOfInvestments, amountPerInvestment: self.amountPerInvestment)
        }
        .padding(.horizontal, ResponsiveDesign.spacing(16))
        .padding(.vertical, ResponsiveDesign.spacing(8))
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(16))
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: ResponsiveDesign.spacing(16)) {
        InvestmentSelectionView(
            selectedInvestmentSelection: .multipleInvestments,
            numberOfInvestments: 5,
            amountPerInvestment: 200.00
        )
    }
    .responsivePadding()
    .background(AppTheme.screenBackground)
}
