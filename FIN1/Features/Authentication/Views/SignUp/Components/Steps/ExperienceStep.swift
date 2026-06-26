import SwiftUI

struct ExperienceStep: View {
    // Stocks
    @Binding var stocksTransactionsCount: StocksTransactionCount?
    @Binding var stocksInvestmentAmount: InvestmentAmount?

    // Investment funds, ETFs
    @Binding var etfsTransactionsCount: ETFsTransactionCount?
    @Binding var etfsInvestmentAmount: InvestmentAmount?

    // Certificates and derivatives
    @Binding var derivativesTransactionsCount: DerivativesTransactionCount?
    @Binding var derivativesInvestmentAmount: DerivativesInvestmentAmount?
    @Binding var derivativesHoldingPeriod: HoldingPeriod?

    // Other assets
    @Binding var otherAssets: [String: Bool]

    private var hasSelectedOtherAsset: Bool {
        self.otherAssets.values.contains(true)
    }

    private var showsStocksFollowUpQuestions: Bool {
        guard let count = self.stocksTransactionsCount else { return false }
        return count != StocksTransactionCount.none
    }

    private var showsEtfsFollowUpQuestions: Bool {
        guard let count = self.etfsTransactionsCount else { return false }
        return count != ETFsTransactionCount.none
    }

    private var showsDerivativesFollowUpQuestions: Bool {
        guard let count = self.derivativesTransactionsCount else { return false }
        return count != DerivativesTransactionCount.none
    }

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

                OptionalCustomPicker(
                    title: "How many of these types of investments did you make last year?",
                    selection: self.$stocksTransactionsCount
                )

                if self.showsStocksFollowUpQuestions {
                    OptionalCustomPicker(
                        title: "How much did you invest?",
                        selection: self.$stocksInvestmentAmount
                    )
                }
            }
            .signUpListSection(stripeIndex: 1)
            .onChange(of: self.stocksTransactionsCount) { _, newValue in
                if newValue == StocksTransactionCount.none {
                    self.stocksInvestmentAmount = nil
                }
            }

            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(16)) {
                Text("b) Investment funds, ETFs")
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(AppTheme.fontColor)
                    .frame(maxWidth: .infinity, alignment: .leading)

                OptionalCustomPicker(
                    title: "How many of these types of investments did you make last year?",
                    selection: self.$etfsTransactionsCount
                )

                if self.showsEtfsFollowUpQuestions {
                    OptionalCustomPicker(
                        title: "How much did you invest?",
                        selection: self.$etfsInvestmentAmount
                    )
                }
            }
            .signUpListSection(stripeIndex: 2)
            .onChange(of: self.etfsTransactionsCount) { _, newValue in
                if newValue == ETFsTransactionCount.none {
                    self.etfsInvestmentAmount = nil
                }
            }

            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(16)) {
                Text("c) Certificates and derivatives")
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(AppTheme.fontColor)
                    .frame(maxWidth: .infinity, alignment: .leading)

                OptionalCustomPicker(
                    title: "How many of these types of investments did you make last year?",
                    selection: self.$derivativesTransactionsCount
                )

                if self.showsDerivativesFollowUpQuestions {
                    OptionalCustomPicker(
                        title: "How much did you invest?",
                        selection: self.$derivativesInvestmentAmount
                    )

                    OptionalCustomPicker(
                        title: "How long did you generally hold your positions?",
                        selection: self.$derivativesHoldingPeriod
                    )
                }
            }
            .signUpListSection(stripeIndex: 3)
            .onChange(of: self.derivativesTransactionsCount) { _, newValue in
                if newValue == DerivativesTransactionCount.none {
                    self.derivativesInvestmentAmount = nil
                    self.derivativesHoldingPeriod = nil
                }
            }

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
                                if newValue {
                                    self.otherAssets["Real estate"] = false
                                    self.otherAssets["Gold, silver"] = false
                                }
                            }
                        )
                    )
                }

                if !self.hasSelectedOtherAsset {
                    Text(SignUpStepSelectionPrompt.otherAssets)
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.6))
                }
            }
            .signUpListSection(stripeIndex: 4)
        }
    }
}

#Preview {
    ExperienceStep(
        stocksTransactionsCount: .constant(nil),
        stocksInvestmentAmount: .constant(nil),
        etfsTransactionsCount: .constant(nil),
        etfsInvestmentAmount: .constant(nil),
        derivativesTransactionsCount: .constant(nil),
        derivativesInvestmentAmount: .constant(nil),
        derivativesHoldingPeriod: .constant(nil),
        otherAssets: .constant([
            "Real estate": false,
            "Gold, silver": false,
            "No": false
        ])
    )
    .background(AppTheme.screenBackground)
}
