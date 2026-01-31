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
        ScrollView {
            VStack(spacing: ResponsiveDesign.spacing(24)) {
                // Main Title
                Text("Investment experience")
                    .font(ResponsiveDesign.headlineFont())
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.fontColor)
                    .multilineTextAlignment(.center)
                
                // Part 1 Title
              /*  Text("Part 1")
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(AppTheme.fontColor)
                    .frame(maxWidth: .infinity, alignment: .leading) */
                
                Text("Experience with various financial products")
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(AppTheme.fontColor.opacity(1.0))
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text("The following questions relate to your experience over the past year")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.8))
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                                // Section A: Stocks
                VStack(alignment: .leading, spacing: 16) {
                    Text("a) Stocks")
                        .font(ResponsiveDesign.headlineFont())
                        .foregroundColor(AppTheme.fontColor)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    CustomPicker(
                        title: "How many of these types of investments did you make last year?",
                        selection: $stocksTransactionsCount
                    )

                    CustomPicker(
                        title: "How much did you invest?",
                        selection: $stocksInvestmentAmount
                    )
                }
                .padding()
                .background(AppTheme.sectionBackground)
                .cornerRadius(ResponsiveDesign.spacing(16))
                
                                // Section B: Investment funds, ETFs
                VStack(alignment: .leading, spacing: 16) {
                    Text("b) Investment funds, ETFs")
                        .font(ResponsiveDesign.headlineFont())
                        .foregroundColor(AppTheme.fontColor)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    CustomPicker(
                        title: "How many of these types of investments did you make last year?",
                        selection: $etfsTransactionsCount
                    )

                    CustomPicker(
                        title: "How much did you invest?",
                        selection: $etfsInvestmentAmount
                    )
                }
                .padding()
                .background(AppTheme.sectionBackground)
                .cornerRadius(ResponsiveDesign.spacing(16))
                
                                // Section C: Certificates and derivatives
                VStack(alignment: .leading, spacing: 16) {
                    Text("c) Certificates and derivatives")
                        .font(ResponsiveDesign.headlineFont())
                        .foregroundColor(AppTheme.fontColor)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    CustomPicker(
                        title: "How many of these types of investments did you make last year?",
                        selection: $derivativesTransactionsCount
                    )

                    CustomPicker(
                        title: "How much did you invest?",
                        selection: $derivativesInvestmentAmount
                    )

                    CustomPicker(
                        title: "How long did you generally hold your positions?",
                        selection: $derivativesHoldingPeriod
                    )
                }
                .padding()
                .background(AppTheme.sectionBackground)
                .cornerRadius(ResponsiveDesign.spacing(16))
                
                                // Section D: Other assets
                VStack(alignment: .leading, spacing: 16) {
                    Text("d) Have you invested in the following assets?")
                        .font(ResponsiveDesign.headlineFont())
                        .foregroundColor(AppTheme.fontColor)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(spacing: ResponsiveDesign.spacing(8)) {
                        OtherAssetsOption(
                            title: "Real estate",
                            isSelected: Binding(
                                get: { otherAssets["Real estate"] ?? false },
                                set: { newValue in
                                    otherAssets["Real estate"] = newValue
                                    // If this is selected, uncheck "No"
                                    if newValue {
                                        otherAssets["No"] = false
                                    }
                                }
                            )
                        )

                        OtherAssetsOption(
                            title: "Gold, silver",
                            isSelected: Binding(
                                get: { otherAssets["Gold, silver"] ?? false },
                                set: { newValue in
                                    otherAssets["Gold, silver"] = newValue
                                    // If this is selected, uncheck "No"
                                    if newValue {
                                        otherAssets["No"] = false
                                    }
                                }
                            )
                        )

                        OtherAssetsOption(
                            title: "No",
                            isSelected: Binding(
                                get: { otherAssets["No"] ?? false },
                                set: { newValue in
                                    otherAssets["No"] = newValue
                                    // If "No" is selected, uncheck all others
                                    if newValue {
                                        otherAssets["Real estate"] = false
                                        otherAssets["Gold, silver"] = false
                                    }
                                }
                            )
                        )
                    }
                }
                .padding()
                .background(AppTheme.sectionBackground)
                .cornerRadius(ResponsiveDesign.spacing(16))
            }
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
