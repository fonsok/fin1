import SwiftUI

// MARK: - Investment Form View
/// Handles investment amount input and strategy selection
struct InvestmentFormView: View {
    @Binding var investmentAmount: String
    @Binding var selectedInvestmentSelection: InvestmentSelectionStrategy
    @Binding var numberOfInvestments: Int
    @StateObject private var viewModel: InvestmentFormViewModel
    @Environment(\.themeManager) private var themeManager

    init(investmentAmount: Binding<String>, selectedInvestmentSelection: Binding<InvestmentSelectionStrategy>, numberOfInvestments: Binding<Int>) {
        self._investmentAmount = investmentAmount
        self._selectedInvestmentSelection = selectedInvestmentSelection
        self._numberOfInvestments = numberOfInvestments
        self._viewModel = StateObject(wrappedValue: InvestmentFormViewModel(
            updateInvestmentAmount: { investmentAmount.wrappedValue = $0 },
            getInvestmentAmount: { investmentAmount.wrappedValue }
        ))
    }

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(16)) {
            // Investment Amount
            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
                Text("Investment Amount")
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(AppTheme.fontColor)

                HStack {
                    TextField("nur ganzzahliger Betrag", text: $viewModel.displayAmount)
                        .keyboardType(.numberPad)
                        .font(ResponsiveDesign.headlineFont())
                        .foregroundColor(AppTheme.inputFieldText)
                        .padding()
                        .background(AppTheme.inputFieldBackground)
                        .cornerRadius(ResponsiveDesign.spacing(12))
                        .onChange(of: viewModel.displayAmount) { _, newValue in
                            viewModel.formatAndValidateInput(newValue)
                        }
                        .onAppear {
                            viewModel.updateDisplayFromAmount()
                        }
                        .accessibilityIdentifier("InvestmentAmountField")

                    Text("€")
                        .font(ResponsiveDesign.headlineFont())
                        .foregroundColor(AppTheme.fontColor)
                }

                // Platform Service Charge Info
                if viewModel.hasValidAmount {
                    VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
                        Text("A platform service charge of \(CalculationConstants.ServiceCharges.platformServiceChargePercentage) applies: \(viewModel.formattedPlatformServiceCharge)")
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(AppTheme.secondaryText)

                        Text("This charge will be deducted from your account immediately.")
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(AppTheme.secondaryText)
                    }
                    .padding(.top, ResponsiveDesign.spacing(4))
                } else {
                    Text("A platform service charge of \(CalculationConstants.ServiceCharges.platformServiceChargePercentage) applies and will be deducted from your account immediately.")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.secondaryText)
                        .padding(.top, ResponsiveDesign.spacing(4))
                }
            }

            // Investment Strategy Info
            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
                Text("Investment Strategy")
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(AppTheme.fontColor)

                Text("Invest across multiple future investments")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.secondaryText)
            }

            // Number of Investments
            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
                Text("Number of Investments")
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(AppTheme.fontColor)

                HStack {
                    Text("1")
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(AppTheme.secondaryText)

                    Slider(value: Binding(
                        get: { Double(numberOfInvestments) },
                        set: { numberOfInvestments = Int($0) }
                    ), in: 1...10, step: 1)
                    .accentColor(AppTheme.accentGreen)
                    .accessibilityIdentifier("InvestmentCountSlider")

                    Text("10")
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(AppTheme.secondaryText)
                }

                Text("\(numberOfInvestments) investment\(numberOfInvestments == 1 ? "" : "s")")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.accentGreen)
                    .fontWeight(.medium)
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(16))
    }

}

// MARK: - Preview
#Preview {
    InvestmentFormView(
        investmentAmount: .constant(
            String(Int(CalculationConstants.Investment.defaultAmount))
        ),
        selectedInvestmentSelection: .constant(.multipleInvestments),
        numberOfInvestments: .constant(1)
    )
    .padding()
    .background(AppTheme.screenBackground)
}
