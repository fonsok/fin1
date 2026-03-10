import SwiftUI

/// Trades section for customer detail (trader role).
struct CustomerDetailTradesSection: View {
    @ObservedObject var viewModel: CustomerSupportDashboardViewModel
    var onSelectTrade: (CustomerTradeSummary) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            HStack {
                Text("Trades")
                    .font(ResponsiveDesign.headlineFont())
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.fontColor)

                Spacer()

                Menu {
                    ForEach(InvestmentTimePeriod.allCases, id: \.self) { period in
                        Button {
                            viewModel.selectedTradeTimePeriod = period
                        } label: {
                            HStack {
                                Text(period.displayName)
                                if viewModel.selectedTradeTimePeriod == period {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: ResponsiveDesign.spacing(4)) {
                        Text(viewModel.selectedTradeTimePeriod.displayName)
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

            if viewModel.filteredTradesByTimePeriod.isEmpty {
                Text("Keine Trades vorhanden")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.7))
                    .padding()
            } else {
                if !viewModel.ongoingTrades.isEmpty {
                    Text("Laufende Trades")
                        .font(ResponsiveDesign.captionFont())
                        .fontWeight(.medium)
                        .foregroundColor(AppTheme.fontColor.opacity(0.7))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, ResponsiveDesign.spacing(4))

                    ForEach(viewModel.ongoingTrades) { trade in
                        TradeSummaryCard(trade: trade) {
                            onSelectTrade(trade)
                        }
                    }
                }

                if !viewModel.completedTrades.isEmpty {
                    if !viewModel.ongoingTrades.isEmpty {
                        Divider()
                            .padding(.vertical, ResponsiveDesign.spacing(8))
                    }

                    Text("Abgeschlossene Trades")
                        .font(ResponsiveDesign.captionFont())
                        .fontWeight(.medium)
                        .foregroundColor(AppTheme.fontColor.opacity(0.7))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    ForEach(viewModel.completedTrades) { trade in
                        TradeSummaryCard(trade: trade) {
                            onSelectTrade(trade)
                        }
                    }
                }

                if viewModel.ongoingTrades.isEmpty && viewModel.completedTrades.isEmpty && !viewModel.filteredTradesByTimePeriod.isEmpty {
                    Text("Keine Trades im ausgewählten Zeitraum")
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
