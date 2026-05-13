import SwiftUI

// MARK: - Investment Summary View
/// Displays investment summary with totals following MVVM architecture
struct InvestmentSummaryView: View {
    @ObservedObject private var viewModel: InvestmentSummaryViewModel
    @State private var showAppServiceChargeInfo = false
    let remainingBalance: Double
    let currentBalance: Double
    @Environment(\.themeManager) private var themeManager

    init(viewModel: InvestmentSummaryViewModel, remainingBalance: Double = 0, currentBalance: Double = 0) {
        self.viewModel = viewModel
        self.remainingBalance = remainingBalance
        self.currentBalance = currentBalance
    }

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(12)) {
            Text("Investment Summary")
                .font(ResponsiveDesign.headlineFont())
                .foregroundColor(AppTheme.fontColor)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: ResponsiveDesign.spacing(8)) {
                HStack {
                    Text("Total Investment:")
                        .font(ResponsiveDesign.bodyFont())
                        .fontWeight(.semibold)
                    Spacer()
                    Text(self.viewModel.formattedTotalInvestment)
                        .font(ResponsiveDesign.bodyFont())
                        .fontWeight(.bold)
                        .foregroundColor(AppTheme.accentGreen)
                }

                HStack {
                    Text("Number of Investments:")
                    Spacer()
                    Text(self.viewModel.numberOfInvestmentsText)
                        .fontWeight(.medium)
                }

                HStack {
                    Text("Amount per Investment:")
                    Spacer()
                    Text(self.viewModel.formattedAmountPerInvestment)
                        .fontWeight(.medium)
                }

                Divider()

                HStack {
                    HStack(spacing: ResponsiveDesign.spacing(2)) {
                        Text("App Service Charge (\(self.viewModel.configurationService.appServiceChargePercentage)):")
                        Button(action: {
                            self.showAppServiceChargeInfo = true
                        }) {
                            Image(systemName: "info.circle.fill")
                                .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize() * 0.7))
                                .foregroundColor(AppTheme.accentLightBlue.opacity(0.7))
                        }
                    }
                    Spacer()
                    Text(self.viewModel.formattedAppServiceCharge)
                        .fontWeight(.medium)
                }

                if self.currentBalance > 0 {
                    Divider()

                    HStack {
                        Text("Current Balance:")
                            .font(ResponsiveDesign.bodyFont())
                            .fontWeight(.semibold)
                        Spacer()
                        Text(self.currentBalance.formattedAsLocalizedCurrency())
                            .font(ResponsiveDesign.bodyFont())
                            .fontWeight(.medium)
                    }

                    HStack {
                        Text("Remaining Balance:")
                            .font(ResponsiveDesign.bodyFont())
                            .fontWeight(.semibold)
                        Spacer()
                        Text(self.remainingBalance.formattedAsLocalizedCurrency())
                            .font(ResponsiveDesign.bodyFont())
                            .fontWeight(.bold)
                            .foregroundColor(
                                self.remainingBalance >= CalculationConstants.Account.minimumCashReserve ? AppTheme.accentGreen : AppTheme.accentRed
                            )
                    }
                }
            }
            .font(ResponsiveDesign.bodyFont())
            .foregroundColor(AppTheme.fontColor)
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(16))
        .sheet(isPresented: self.$showAppServiceChargeInfo) {
            AppServiceChargeInfoSheet()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - Preview
#Preview {
    InvestmentSummaryView(
        viewModel: InvestmentSummaryViewModel(
            amountPerInvestment: 200.00,
            numberOfInvestments: 5,
            totalInvestmentAmount: 1_000.00,
            configurationService: ConfigurationService(userService: UserService())
        )
    )
    .padding()
    .background(AppTheme.screenBackground)
}

// MARK: - App Service Charge Info Sheet
private struct AppServiceChargeInfoSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.themeManager) private var themeManager

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(16)) {
                    Text("App Service Charge (\(CalculationConstants.ServiceCharges.appServiceChargePercentage))")
                        .font(ResponsiveDesign.headlineFont())
                        .fontWeight(.bold)
                        .foregroundColor(AppTheme.fontColor)

                    (Text("By clicking the button\n") +
                        Text("Create chargeable Investment")
                        .italic() +
                        Text(
                            ",\nyou immediately trigger payment of the service charge.\n\nEven if you delete relevant investments afterwards, the payment will remain valid."
                        ))
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(AppTheme.fontColor)
                }
                .padding(ResponsiveDesign.horizontalPadding())
                .padding(.top, ResponsiveDesign.spacing(4))
                .padding(.bottom, ResponsiveDesign.spacing(16))
            }
            .background(AppTheme.screenBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        self.dismiss()
                    }
                    .foregroundColor(AppTheme.accentLightBlue)
                }
            }
        }
    }
}
