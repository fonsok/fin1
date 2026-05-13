import SwiftUI

// Import Forms components
// Note: These components are now in the Forms subfolder

struct FinancialStep: View {
    @Binding var employmentStatus: EmploymentStatus
    @Binding var income: String
    @Binding var incomeRange: IncomeRange
    @Binding var incomeSources: [String: Bool]
    @Binding var otherIncomeSource: String
    @Binding var cashAndLiquidAssets: CashAndLiquidAssets

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(20)) {
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

            CustomPicker(
                title: "Employment Status",
                selection: self.$employmentStatus
            )

            CustomPicker(
                title: "Income Range (€)",
                selection: self.$incomeRange
            )

            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Cash and liquid assets (€)")
                        .font(ResponsiveDesign.bodyFont())
                        .fontWeight(.medium)
                        .foregroundColor(AppTheme.fontColor)

                    Text("(Securities accounts, savings accounts, etc.)")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.7))
                }

                Menu {
                    ForEach(CashAndLiquidAssets.allCases, id: \.self) { option in
                        Button(action: { self.cashAndLiquidAssets = option }, label: {
                            Text(option.displayName)
                                .foregroundColor(AppTheme.inputFieldText)
                        })
                    }
                } label: {
                    HStack {
                        Text(self.cashAndLiquidAssets.displayName)
                            .foregroundColor(AppTheme.inputFieldText)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .foregroundColor(AppTheme.inputFieldText)
                    }
                    .padding()
                    .background(AppTheme.inputFieldBackground)
                    .cornerRadius(ResponsiveDesign.spacing(12))
                }
            }

            // Income Sources Section
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
            }

            // Investment Recommendation
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
        employmentStatus: .constant(.employed),
        income: .constant(""),
        incomeRange: .constant(.middle),
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
        cashAndLiquidAssets: .constant(.lessThan10k)
    )
    .background(AppTheme.screenBackground)
}
