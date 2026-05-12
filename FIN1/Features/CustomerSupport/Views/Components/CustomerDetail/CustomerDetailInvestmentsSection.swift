import SwiftUI

/// Investments section for customer detail (investor role).
struct CustomerDetailInvestmentsSection: View {
    @ObservedObject var viewModel: CustomerSupportDashboardViewModel
    var onSelectInvestment: (CustomerInvestmentSummary) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            HStack {
                Text("Investments")
                    .font(ResponsiveDesign.headlineFont())
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.fontColor)

                Spacer()

                Menu {
                    ForEach(InvestmentTimePeriod.allCases, id: \.self) { period in
                        Button {
                            viewModel.selectedInvestmentTimePeriod = period
                        } label: {
                            HStack {
                                Text(period.displayName)
                                if viewModel.selectedInvestmentTimePeriod == period {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: ResponsiveDesign.spacing(4)) {
                        Text(viewModel.selectedInvestmentTimePeriod.displayName)
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(AppTheme.accentLightBlue)

                        Image(systemName: "chevron.up.chevron.down")
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(AppTheme.accentLightBlue)
                    }
                    .padding(.horizontal, ResponsiveDesign.spacing(8))
                    .padding(.vertical, ResponsiveDesign.spacing(4))
                    .background(AppTheme.accentLightBlue.opacity(0.1))
                    .cornerRadius(ResponsiveDesign.spacing(6))
                }
            }

            let openInvestments = viewModel.filteredInvestmentsByTimePeriod.filter { investment in
                investment.status.lowercased() == "active" || investment.status.lowercased() == "submitted"
            }
            let completedInvestments = viewModel.filteredInvestmentsByTimePeriod.filter { investment in
                investment.status.lowercased() == "completed" || investment.status.lowercased() == "cancelled"
            }

            if viewModel.filteredInvestmentsByTimePeriod.isEmpty {
                Text("Keine Investments vorhanden")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.7))
                    .padding()
            } else {
                if !openInvestments.isEmpty {
                    Text("Laufende Investments")
                        .font(ResponsiveDesign.captionFont())
                        .fontWeight(.medium)
                        .foregroundColor(AppTheme.fontColor.opacity(0.7))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, ResponsiveDesign.spacing(4))

                    ForEach(openInvestments) { investment in
                        InvestmentSummaryCard(investment: investment) {
                            onSelectInvestment(investment)
                        }
                    }
                }

                if !completedInvestments.isEmpty {
                    if !openInvestments.isEmpty {
                        Divider()
                            .padding(.vertical, ResponsiveDesign.spacing(8))
                    }

                    Text("Abgeschlossene Investments")
                        .font(ResponsiveDesign.captionFont())
                        .fontWeight(.medium)
                        .foregroundColor(AppTheme.fontColor.opacity(0.7))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    ForEach(completedInvestments) { investment in
                        InvestmentSummaryCard(investment: investment) {
                            onSelectInvestment(investment)
                        }
                    }
                }

                if openInvestments.isEmpty && completedInvestments.isEmpty && !viewModel.filteredInvestmentsByTimePeriod.isEmpty {
                    Text("Keine Investments im ausgewählten Zeitraum")
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.7))
                        .padding()
                }
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }
}
