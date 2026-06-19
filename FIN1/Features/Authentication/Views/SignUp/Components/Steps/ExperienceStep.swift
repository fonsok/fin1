import SwiftUI

// Import Forms components
// Note: These components are now in the Forms subfolder

struct ExperienceStep: View {
    // Stocks
    @Binding var stocksTransactionsCount: StocksTransactionCount
    @Binding var stocksInvestmentAmount: InvestmentAmount
    
    // Investment funds, ETFs
    @Binding var etfsTransactionsCount: ETFsTransactionCount
    @Binding var etfsInvestmentAmount: InvestmentAmount
    
    // Certificates and derivatives
    @Binding var derivativesTransactionsCount: DerivativesTransactionCount
    @Binding var derivativesInvestmentAmount: DerivativesInvestmentAmount
    @Binding var derivativesHoldingPeriod: HoldingPeriod
    
    // Other assets
    @Binding var otherAssets: [String: Bool]
    
    var body: some View {
        SignUpStepList {
            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
                Text("Investment experience")
                    .font(ResponsiveDesign.headlineFont())
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.fontColor)

                Text("Experience with various financial products")
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(AppTheme.fontColor)

                Text("The following questions relate to your experience over the past year")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.8))
            }
            .signUpListSection(stripeIndex: 0)

            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(16)) {
                Text("a) Stocks")
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(AppTheme.fontColor)
                    .frame(maxWidth: .infinity, alignment: .leading)

                CustomPicker(
                    title: "How many of these types of investments did you make last year?",
                    selection: self.$stocksTransactionsCount
                )

                CustomPicker(
                    title: "How much did you invest?",
                    selection: self.$stocksInvestmentAmount
                )
            }
            .signUpListSection(stripeIndex: 1)

            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(16)) {
                Text("b) Investment funds, ETFs")
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(AppTheme.fontColor)
                    .frame(maxWidth: .infinity, alignment: .leading)

                CustomPicker(
                    title: "How many of these types of investments did you make last year?",
                    selection: self.$etfsTransactionsCount
                )

                CustomPicker(
                    title: "How much did you invest?",
                    selection: self.$etfsInvestmentAmount
                )
            }
            .signUpListSection(stripeIndex: 2)

            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(16)) {
                Text("c) Certificates and derivatives")
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(AppTheme.fontColor)
                    .frame(maxWidth: .infinity, alignment: .leading)

                CustomPicker(
                    title: "How many of these types of investments did you make last year?",
                    selection: self.$derivativesTransactionsCount
                )

                CustomPicker(
                    title: "How much did you invest?",
                    selection: self.$derivativesInvestmentAmount
                )

                CustomPicker(
                    title: "How long did you generally hold your positions?",
                    selection: self.$derivativesHoldingPeriod
                )
            }
            .signUpListSection(stripeIndex: 3)

            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(16)) {
                Text("d) Have you invested in the following assets?")
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(AppTheme.fontColor)
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: ResponsiveDesign.spacing(8)) {
                    OtherAssetsOption(
                        title: "Real estate",
                        isSelected: Binding(
                            get: { self.otherAssets["Real estate"] ?? false },
                            set: { newValue in
                                self.otherAssets["Real estate"] = newValue
                                // If this is selected, uncheck "No"
                                if newValue {
                                    self.otherAssets["No"] = false
                                }
                            }
                        )
                    )

                    OtherAssetsOption(
                        title: "Gold, silver",
                        isSelected: Binding(
                            get: { self.otherAssets["Gold, silver"] ?? false },
                            set: { newValue in
                                self.otherAssets["Gold, silver"] = newValue
                                // If this is selected, uncheck "No"
                                if newValue {
                                    self.otherAssets["No"] = false
                                }
                            }
                        )
                    )

                    OtherAssetsOption(
                        title: "No",
                        isSelected: Binding(
                            get: { self.otherAssets["No"] ?? false },
                            set: { newValue in
                                self.otherAssets["No"] = newValue
                                // If "No" is selected, uncheck all others
                                if newValue {
                                    self.otherAssets["Real estate"] = false
                                    self.otherAssets["Gold, silver"] = false
                                }
                            }
                        )
                    )
                }
            }
            .signUpListSection(stripeIndex: 4)
        }
    }
}

#Preview {
    ExperienceStep(
        stocksTransactionsCount: .constant(.none),
        stocksInvestmentAmount: .constant(.hundredToTenThousand),
        etfsTransactionsCount: .constant(.none),
        etfsInvestmentAmount: .constant(.hundredToTenThousand),
        derivativesTransactionsCount: .constant(.none),
        derivativesInvestmentAmount: .constant(.zeroToThousand),
        derivativesHoldingPeriod: .constant(.minutesToHours),
        otherAssets: .constant([
            "Real estate": false,
            "Gold, silver": false,
            "No": false
        ])
    )
    .background(AppTheme.screenBackground)
}
