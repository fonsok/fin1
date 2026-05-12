import SwiftUI

// MARK: - Trader Performance Bar Chart
/// A vertical bar chart displaying trader ROI performance per trade
struct TraderPerformanceBarChart: View {
    let chartData: ChartDisplayData
    private let barWidth: CGFloat = 4
    @State private var rotationAngle: Double = 0

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(0)) {
            if chartData.allTrades.isEmpty {
                ChartEmptyView()
            } else {
                chartContent
                    .rotationEffect(.degrees(rotationAngle), anchor: .center)
                    .frame(minHeight: ResponsiveDesign.spacing(200))

                rotationButton
            }
        }
        .frame(maxWidth: .infinity)
        .padding(ResponsiveDesign.spacing(12))
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    private var chartContent: some View {
        GeometryReader { geometry in
            let yAxisWidth: CGFloat = ResponsiveDesign.spacing(50)
            let xAxisHeight: CGFloat = ResponsiveDesign.spacing(32)
            let availableWidth = geometry.size.width - yAxisWidth
            let chartHeight = geometry.size.height - xAxisHeight

            let barSpacing: CGFloat = ResponsiveDesign.spacing(8)
            let barWidthWithSpacing = barWidth + barSpacing
            let sidePadding: CGFloat = ResponsiveDesign.spacing(8)
            let endPadding: CGFloat = ResponsiveDesign.spacing(32)
            let minContentWidth = max(
                availableWidth,
                CGFloat(chartData.allTrades.count) * barWidthWithSpacing + (sidePadding * 2) + endPadding
            )

            HStack(alignment: .top, spacing: ResponsiveDesign.spacing(0)) {
                ChartYAxisView(
                    labels: chartData.yAxisLabels,
                    hasLogScale: chartData.hasLogScaleValues,
                    chartHeight: chartHeight,
                    yAxisRange: chartData.yAxisRange
                )
                .frame(width: yAxisWidth, height: chartHeight)

                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: true) {
                        HStack(spacing: ResponsiveDesign.spacing(0)) {
                            VStack(spacing: ResponsiveDesign.spacing(0)) {
                                ZStack(alignment: .leading) {
                                    ChartGridLinesView(
                                        labels: chartData.yAxisLabels,
                                        chartHeight: chartHeight,
                                        chartWidth: minContentWidth,
                                        yAxisRange: chartData.yAxisRange
                                    )
                                    ChartBarsView(
                                        trades: chartData.allTrades,
                                        chartHeight: chartHeight,
                                        chartWidth: minContentWidth,
                                        barWidth: barWidth,
                                        yAxisRange: chartData.yAxisRange
                                    )
                                }
                                .frame(width: minContentWidth, height: chartHeight)
                                .clipped()

                                ChartXAxisView(
                                    monthGroups: chartData.monthGroups,
                                    totalTrades: chartData.allTrades.count,
                                    contentWidth: minContentWidth,
                                    barWidth: barWidth,
                                    barSpacing: barSpacing
                                )
                                .frame(width: minContentWidth, height: xAxisHeight)
                            }

                            Spacer()
                                .frame(width: endPadding)
                                .id("chartEnd")
                        }
                    }
                    .frame(width: availableWidth)
                    .onChange(of: rotationAngle) { _, newAngle in
                        if newAngle == -90 {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    proxy.scrollTo("chartEnd", anchor: .trailing)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var rotationButton: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.3)) {
                rotationAngle = rotationAngle == 0 ? -90 : 0
            }
        }) {
            Image(systemName: rotationAngle == 0 ? "arrow.counterclockwise" : "arrow.clockwise")
                .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize()))
                .foregroundColor(AppTheme.accentLightBlue)
                .padding(ResponsiveDesign.spacing(8))
        }
        .padding(.top, ResponsiveDesign.spacing(8))
    }
}

// MARK: - Preview
#Preview {
    let weeks = [
        WeekTradeData(
            week: 48,
            month: "December",
            year: 2025,
            date: Date(),
            tradeReturns: [
                TradeReturnData(roi: 112.5, isActive: false, tradeNumber: 1234567890),
                TradeReturnData(roi: -25.3, isActive: false, tradeNumber: 2),
                TradeReturnData(roi: 0, isActive: true, tradeNumber: 3)
            ]
        ),
        WeekTradeData(
            week: 47,
            month: "November",
            year: 2025,
            date: Calendar.current.date(byAdding: .weekOfYear, value: -1, to: Date()) ?? Date(),
            tradeReturns: [TradeReturnData(roi: 45.2, isActive: false, tradeNumber: 4)]
        )
    ]
    TraderPerformanceBarChart(chartData: ChartDisplayData(weeks: weeks))
        .frame(height: 280)
        .padding()
        .background(AppTheme.screenBackground)
}
