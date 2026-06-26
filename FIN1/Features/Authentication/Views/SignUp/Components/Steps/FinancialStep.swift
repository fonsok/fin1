import SwiftUI

struct FinancialStep: View {
    @Binding var employmentStatus: EmploymentStatus?
    @Binding var income: String
    @Binding var incomeRange: IncomeRange?
    @Binding var incomeSources: [String: Bool]
    @Binding var otherIncomeSource: String
    @Binding var cashAndLiquidAssets: CashAndLiquidAssets?

    private var hasSelectedIncomeSource: Bool {
        self.incomeSources.values.contains(true)
    }

    var body: some View {
        SignUpFormStepList {
            Text("Financial Information")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.bold)
                .foregroundColor(AppTheme.fontColor)

            Text("Wir benötigen diese Informationen für:")
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.8))
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
                Text("• Risikobewertung für Ihre Anlagestrategie")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.8))
                Text("• Einhaltung regulatorischer Anforderungen")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.8))
                Text("• Personalisierte Beratung und Empfehlungen")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.8))
                Text("• KYC (Know Your Customer) Compliance")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.8))
            }

            OptionalCustomPicker(
                title: "Employment Status",
                selection: self.$employmentStatus
            )

            OptionalCustomPicker(
                title: "Income Range (€)",
                selection: self.$incomeRange
            )

            OptionalCustomPicker(
                title: "Cash and liquid assets (€)",
                selection: self.$cashAndLiquidAssets
            )

            Text("(Securities accounts, savings accounts, etc.)")
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 12) {
                Text("Where do you get your income from?")
                    .font(ResponsiveDesign.bodyFont())
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.fontColor)

                Text("(Your income is seen as the source of your investment with us.)")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.7))

                Text("Multiple selection possible")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.accentLightBlue)

                VStack(spacing: ResponsiveDesign.spacing(8)) {
                    IncomeSourceOption(
                        title: "Settlement",
                        isSelected: Binding(
                            get: { self.incomeSources["Settlement"] ?? false },
                            set: { self.incomeSources["Settlement"] = $0 }
                        ),
                        otherText: .constant("")
                    )
                    IncomeSourceOption(
                        title: "Inheritance",
                        isSelected: Binding(
                            get: { self.incomeSources["Inheritance"] ?? false },
                            set: { self.incomeSources["Inheritance"] = $0 }
                        ),
                        otherText: .constant("")
                    )
                    IncomeSourceOption(
                        title: "Savings",
                        isSelected: Binding(
                            get: { self.incomeSources["Savings"] ?? false },
                            set: { self.incomeSources["Savings"] = $0 }
                        ),
                        otherText: .constant("")
                    )
                    IncomeSourceOption(
                        title: "Financial contributions to family",
                        isSelected: Binding(
                            get: { self.incomeSources["Financial contributions to family"] ?? false },
                            set: { self.incomeSources["Financial contributions to family"] = $0 }
                        ),
                        otherText: .constant("")
                    )
                    IncomeSourceOption(
                        title: "Salary",
                        isSelected: Binding(
                            get: { self.incomeSources["Salary"] ?? false },
                            set: { self.incomeSources["Salary"] = $0 }
                        ),
                        otherText: .constant("")
                    )
                    IncomeSourceOption(
                        title: "Pension",
                        isSelected: Binding(
                            get: { self.incomeSources["Pension"] ?? false },
                            set: { self.incomeSources["Pension"] = $0 }
                        ),
                        otherText: .constant("")
                    )
                    IncomeSourceOption(
                        title: "Assets",
                        isSelected: Binding(
                            get: { self.incomeSources["Assets"] ?? false },
                            set: { self.incomeSources["Assets"] = $0 }
                        ),
                        otherText: .constant("")
                    )
                    IncomeSourceOption(
                        title: "Other (please specify)",
                        isSelected: Binding(
                            get: { self.incomeSources["Other (please specify)"] ?? false },
                            set: { self.incomeSources["Other (please specify)"] = $0 }
                        ),
                        otherText: self.$otherIncomeSource
                    )
                }

                if !self.hasSelectedIncomeSource {
                    Text(SignUpStepSelectionPrompt.incomeSources)
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.6))
                }
            }

            Text("We recommend that you invest no more than 5% of your assets.")
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.8))
                .multilineTextAlignment(.leading)
                .padding(.top, ResponsiveDesign.spacing(8))
        }
    }
}

#Preview {
    FinancialStep(
        employmentStatus: .constant(nil),
        income: .constant(""),
        incomeRange: .constant(nil),
        incomeSources: .constant([
            "Settlement": false,
            "Inheritance": false,
            "Savings": false,
            "Financial contributions to family": false,
            "Salary": false,
            "Pension": false,
            "Assets": false,
            "Other (please specify)": false
        ]),
        otherIncomeSource: .constant(""),
        cashAndLiquidAssets: .constant(nil)
    )
    .background(AppTheme.screenBackground)
}
