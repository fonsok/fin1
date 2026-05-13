import SwiftUI

// MARK: - Trader Performance Section
/// Main view for displaying trader performance data with table and chart modes
struct TraderPerformanceSection: View {
    let trader: MockTrader
    @StateObject private var viewModel: TraderPerformanceViewModel

    init(trader: MockTrader) {
        self.trader = trader
        self._viewModel = StateObject(wrappedValue: TraderPerformanceViewModel(trader: trader))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(16)) {
            self.performanceHeader
            self.performanceContent
        }
        .padding(ResponsiveDesign.spacing(16))
        .frame(maxWidth: .infinity)
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(16))
        .overlay(
            RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(16))
                .stroke(AppTheme.fontColor.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }

    // MARK: - Header
    private var performanceHeader: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            self.titleAndToggle
            self.timePeriodSelector
        }
    }

    private var titleAndToggle: some View {
        HStack {
            Text("Performance")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.medium)
                .foregroundColor(AppTheme.fontColor)

            Spacer()

            self.viewModeToggle
        }
    }

    private var viewModeToggle: some View {
        HStack(spacing: ResponsiveDesign.spacing(12)) {
            Button(action: { self.viewModel.updateViewMode(.chart) }, label: {
                Image(systemName: "chart.bar")
                    .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize()))
                    .foregroundColor(self.viewModel.viewMode == .chart ? AppTheme.accentLightBlue : AppTheme.fontColor.opacity(0.6))
            })

            Button(action: { self.viewModel.updateViewMode(.table) }, label: {
                Image(systemName: "square.grid.2x2")
                    .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize()))
                    .foregroundColor(self.viewModel.viewMode == .table ? AppTheme.accentLightBlue : AppTheme.fontColor.opacity(0.6))
            })
        }
    }

    private var timePeriodSelector: some View {
        GeometryReader { geometry in
            Menu {
                ForEach(TraderPerformanceViewModel.TimePeriodOption.allCases, id: \.self) { option in
                    Button(action: { self.viewModel.updateTimePeriod(option) }, label: {
                        HStack {
                            Text(option.rawValue)
                            if self.viewModel.selectedTimePeriod == option {
                                Image(systemName: "checkmark")
                            }
                        }
                    })
                }
            } label: {
                HStack {
                    Text(self.viewModel.selectedTimePeriod.rawValue)
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(AppTheme.inputText)

                    Spacer()

                    Image(systemName: "chevron.up.chevron.down")
                        .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize() * 0.8))
                        .foregroundColor(AppTheme.inputText.opacity(0.8))
                }
                .padding(ResponsiveDesign.spacing(12))
                .background(AppTheme.inputFieldBackground)
                .cornerRadius(ResponsiveDesign.spacing(8))
            }
            .frame(maxWidth: geometry.size.width * 0.5)
        }
        .frame(height: ResponsiveDesign.spacing(44))
    }

    // MARK: - Content
    @ViewBuilder
    private var performanceContent: some View {
        if self.viewModel.viewMode == .table {
            self.performanceTable
        } else {
            self.performanceChart
        }
    }

    private var performanceChart: some View {
        TraderPerformanceBarChart(chartData: self.viewModel.chartDisplayData)
            .frame(maxWidth: .infinity, minHeight: ResponsiveDesign.spacing(200))
    }

    // MARK: - Performance Table
    private var performanceTable: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(0)) {
            if !self.viewModel.hasTrades {
                self.emptyState
            } else {
                self.tableContent
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: ResponsiveDesign.spacing(12)) {
            Text("No trades available for the selected period")
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.6))

            Text("Total trades: \(self.viewModel.totalTradesCount)")
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.4))
        }
        .frame(maxWidth: .infinity, minHeight: ResponsiveDesign.spacing(100))
        .padding(ResponsiveDesign.spacing(40))
    }

    private var tableContent: some View {
        GeometryReader { geometry in
            ScrollView(.vertical, showsIndicators: true) {
                ScrollView(.horizontal, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(0)) {
                        self.tableHeader(availableWidth: geometry.size.width)

                        Divider()
                            .background(AppTheme.fontColor.opacity(0.2))

                        Color.clear
                            .frame(height: ResponsiveDesign.spacing(1))

                        ZStack(alignment: .top) {
                            AppTheme.inputFieldBackground.opacity(0.5)
                                .frame(height: ResponsiveDesign.spacing(30))
                                .offset(y: -ResponsiveDesign.spacing(30))

                            TraderPerformanceTableContent(weeks: self.viewModel.groupedWeeks, currentYear: self.viewModel.currentYear)
                                .frame(minHeight: ResponsiveDesign.spacing(100))
                        }
                        .clipped()
                        .contentShape(Rectangle())
                    }
                    .frame(minWidth: geometry.size.width - ResponsiveDesign.spacing(32))
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: ResponsiveDesign.spacing(400))
    }

    // MARK: - Table Header
    private func tableHeader(availableWidth: CGFloat) -> some View {
        HStack(alignment: .center, spacing: ResponsiveDesign.spacing(0)) {
            Text(String(format: "%d", self.viewModel.currentYear))
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.inputFieldText)
                .frame(width: ResponsiveDesign.spacing(50), alignment: .leading)
                .padding(.horizontal, 2)

            Text("KW")
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.inputFieldText)
                .frame(width: ResponsiveDesign.spacing(40), alignment: .center)

            Text("Return per Trade (%)")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.regular)
                .foregroundColor(AppTheme.inputFieldText)
                .padding(.leading, ResponsiveDesign.spacing(16))
                .padding(.trailing, ResponsiveDesign.spacing(16))

            Spacer(minLength: ResponsiveDesign.spacing(200))
        }
        .frame(height: ResponsiveDesign.spacing(32))
        .frame(minWidth: availableWidth - ResponsiveDesign.spacing(32))
        .padding(.vertical, ResponsiveDesign.spacing(12))
        .background(AppTheme.inputFieldBackground)
    }
}

#Preview {
    TraderPerformanceSection(trader: mockTraders[0])
        .padding()
        .background(AppTheme.screenBackground)
}
