import SwiftUI

// MARK: - Admin Summary Report View
/// Displays aggregated summary of completed investments and trades from account statements
struct AdminSummaryReportView: View {
    @StateObject private var viewModel: AdminSummaryReportViewModel
    @Environment(\.appServices) private var services

    init(services: AppServices) {
        _viewModel = StateObject(wrappedValue: AdminSummaryReportViewModel(services: services))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: ResponsiveDesign.spacing(16)) {
                // Filters Section
                self.filtersSection

                // Summary Cards
                self.summaryCardsSection

                // Investments Section
                self.investmentsSection

                // Trades Section
                self.tradesSection
            }
            .padding()
        }
        .background(AppTheme.screenBackground.ignoresSafeArea())
        .navigationTitle("Summary Report")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button {
                    self.viewModel.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh report")
            }
        }
        .task {
            self.viewModel.load()
        }
    }

    // MARK: - Filters Section

    private var filtersSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            Text("Filters")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.fontColor)

            Picker("Date Range", selection: self.$viewModel.selectedDateRange) {
                ForEach(DateRangeFilter.allCases) { range in
                    Text(range.displayName).tag(range)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: self.viewModel.selectedDateRange) { _, _ in
                self.viewModel.refresh()
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    // MARK: - Summary Cards Section

    private var summaryCardsSection: some View {
        VStack(spacing: ResponsiveDesign.spacing(12)) {
            Text("Summary")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.fontColor)
                .frame(maxWidth: .infinity, alignment: .leading)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: ResponsiveDesign.spacing(12)) {
                SummaryCard(
                    title: "Total Investments",
                    value: "\(self.viewModel.summary.totalInvestments)",
                    icon: "chart.bar.fill",
                    color: AppTheme.accentGreen
                )

                SummaryCard(
                    title: "Total Trades",
                    value: "\(self.viewModel.summary.totalTrades)",
                    icon: "arrow.triangle.2.circlepath",
                    color: AppTheme.accentLightBlue
                )

                SummaryCard(
                    title: "Total Invested",
                    value: self.viewModel.summary.totalInvestedAmount.formattedAsLocalizedCurrency(),
                    icon: "eurosign.circle.fill",
                    color: AppTheme.accentOrange
                )

                SummaryCard(
                    title: "Total Current Value",
                    value: self.viewModel.summary.totalCurrentValue.formattedAsLocalizedCurrency(),
                    icon: "chart.line.uptrend.xyaxis",
                    color: AppTheme.accentGreen
                )

                SummaryCard(
                    title: "Total Gross Profit (€)",
                    value: self.viewModel.summary.totalGrossProfit.formattedAsLocalizedCurrency(),
                    icon: "arrow.up.circle.fill",
                    color: self.viewModel.summary.totalGrossProfit >= 0 ? AppTheme.accentGreen : AppTheme.accentRed
                )

                SummaryCard(
                    title: "Total Commission",
                    value: self.viewModel.summary.totalCommission.formattedAsLocalizedCurrency(),
                    icon: "percent",
                    color: AppTheme.accentOrange
                )

                SummaryCard(
                    title: "Total Trade Volume",
                    value: self.viewModel.summary.totalTradeVolume.formattedAsLocalizedCurrency(),
                    icon: "arrow.left.arrow.right.circle.fill",
                    color: AppTheme.accentLightBlue
                )

                SummaryCard(
                    title: "Total Trade Profit",
                    value: self.viewModel.summary.totalTradeProfit.formattedAsLocalizedCurrency(),
                    icon: "chart.pie.fill",
                    color: self.viewModel.summary.totalTradeProfit >= 0 ? AppTheme.accentGreen : AppTheme.accentRed
                )
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    // MARK: - Investments Section

    private var investmentsSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            Text("Completed Investments")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.fontColor)

            if self.viewModel.summary.investments.isEmpty {
                Text("No completed investments found for the selected filters.")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.7))
                    .padding()
            } else {
                LazyVStack(spacing: ResponsiveDesign.spacing(8)) {
                    ForEach(self.viewModel.summary.investments) { investment in
                        InvestmentSummaryRow(investment: investment)
                    }
                }
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    // MARK: - Trades Section

    private var tradesSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            Text("Completed Trades")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.fontColor)

            if self.viewModel.summary.trades.isEmpty {
                Text("No completed trades found for the selected filters.")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.7))
                    .padding()
            } else {
                LazyVStack(spacing: ResponsiveDesign.spacing(8)) {
                    ForEach(self.viewModel.summary.trades) { trade in
                        TradeSummaryRow(trade: trade)
                    }
                }
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }
}

// MARK: - Summary Card

struct SummaryCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            HStack {
                Image(systemName: self.icon)
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(self.color)
                Spacer()
            }

            Text(self.value)
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.bold)
                .foregroundColor(AppTheme.fontColor)

            Text(self.title)
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.screenBackground)
        .cornerRadius(ResponsiveDesign.spacing(10))
    }
}

// MARK: - Investment Summary Row

struct InvestmentSummaryRow: View {
    let investment: AdminInvestmentSummary

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            HStack {
                Text("Investment #\(self.investment.investmentNumber)")
                    .font(ResponsiveDesign.bodyFont())
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.fontColor)

                Spacer()

                Text(self.investment.completedAt.formatted(date: .abbreviated, time: .omitted))
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.7))
            }

            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
                SummaryInfoRow(label: "Investor", value: self.investment.investorName)
                SummaryInfoRow(label: "Trader", value: self.investment.traderName)
                SummaryInfoRow(label: "Amount", value: self.investment.amount.formattedAsLocalizedCurrency())
                SummaryInfoRow(label: "Current Value", value: self.investment.currentValue.formattedAsLocalizedCurrency())
                SummaryInfoRow(
                    label: "Gross Profit (€)",
                    value: self.investment.grossProfit.formattedAsLocalizedCurrency(),
                    valueColor: self.investment.grossProfit >= 0 ? AppTheme.accentGreen : AppTheme.accentRed
                )
                SummaryInfoRow(
                    label: "Return (%)",
                    value: self.investment.returnPercentage.map { String(format: "%.2f%%", $0) } ?? "pending"
                )
                SummaryInfoRow(label: "Commission", value: self.investment.commission.formattedAsLocalizedCurrency())
                if !self.investment.tradeNumbers.isEmpty {
                    SummaryInfoRow(label: "Trade Numbers", value: self.investment.tradeNumbersText)
                }
            }
        }
        .padding()
        .background(AppTheme.screenBackground)
        .cornerRadius(ResponsiveDesign.spacing(10))
    }
}

// MARK: - Trade Summary Row

struct TradeSummaryRow: View {
    let trade: AdminTradeSummary

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            HStack {
                Text("Trade #\(self.trade.tradeNumberText)")
                    .font(ResponsiveDesign.bodyFont())
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.fontColor)

                Spacer()

                Text(self.trade.completedAt.formatted(date: .abbreviated, time: .omitted))
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.7))
            }

            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
                SummaryInfoRow(label: "Symbol", value: self.trade.symbol)
                SummaryInfoRow(label: "Buy Amount", value: self.trade.buyAmount.formattedAsLocalizedCurrency())
                SummaryInfoRow(label: "Sell Amount", value: self.trade.sellAmount.formattedAsLocalizedCurrency())
                SummaryInfoRow(
                    label: "Profit",
                    value: self.trade.profit.formattedAsLocalizedCurrency(),
                    valueColor: self.trade.profit >= 0 ? AppTheme.accentGreen : AppTheme.accentRed
                )
                SummaryInfoRow(label: "Investors", value: "\(self.trade.investorCount)")
            }
        }
        .padding()
        .background(AppTheme.screenBackground)
        .cornerRadius(ResponsiveDesign.spacing(10))
    }
}

// MARK: - Summary Info Row

struct SummaryInfoRow: View {
    let label: String
    let value: String
    var valueColor: Color = AppTheme.fontColor

    var body: some View {
        HStack {
            Text(self.label)
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))
            Spacer()
            Text(self.value)
                .font(ResponsiveDesign.captionFont())
                .fontWeight(.medium)
                .foregroundColor(self.valueColor)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        AdminSummaryReportView(services: .live)
    }
}

