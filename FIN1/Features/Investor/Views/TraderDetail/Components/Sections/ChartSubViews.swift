import SwiftUI

// MARK: - Chart Y-Axis View
struct ChartYAxisView: View {
    let labels: [Double]
    let hasLogScale: Bool
    let chartHeight: CGFloat
    let yAxisRange: (min: Double, max: Double)

    var body: some View {
        ZStack(alignment: .topLeading) {
            if self.hasLogScale {
                Text("Log")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.5))
                    .position(x: ResponsiveDesign.spacing(20), y: ResponsiveDesign.spacing(8))
            }
            Text("P")
                .font(ResponsiveDesign.captionFont())
                .fontWeight(.bold)
                .foregroundColor(AppTheme.accentGreen)
                .position(x: ResponsiveDesign.spacing(8), y: ResponsiveDesign.spacing(28))
            ForEach(self.labels, id: \.self) { value in
                Text(self.formatLabel(value))
                    .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.spacing(9)))
                    .foregroundColor(AppTheme.fontColor.opacity(0.6))
                    .position(x: ResponsiveDesign.spacing(30), y: self.yPositionForValue(value))
            }
            Text("L")
                .font(ResponsiveDesign.captionFont())
                .fontWeight(.bold)
                .foregroundColor(AppTheme.accentRed)
                .position(x: ResponsiveDesign.spacing(8), y: self.chartHeight - ResponsiveDesign.spacing(20))
            Path { path in
                path.move(to: CGPoint(x: ResponsiveDesign.spacing(48), y: 0))
                path.addLine(to: CGPoint(x: ResponsiveDesign.spacing(48), y: self.chartHeight))
            }
            .stroke(AppTheme.fontColor.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
        }
    }

    private func yPositionForValue(_ value: Double) -> CGFloat {
        ChartPositionCalculator.calculateYPosition(value: value, yAxisRange: self.yAxisRange, chartHeight: self.chartHeight)
    }

    private func formatLabel(_ value: Double) -> String {
        value == 0 ? "0 %" : "\(Int(value)) %"
    }
}

// MARK: - Chart Grid Lines View
struct ChartGridLinesView: View {
    let labels: [Double]
    let chartHeight: CGFloat
    let chartWidth: CGFloat
    let yAxisRange: (min: Double, max: Double)

    var body: some View {
        ZStack {
            ForEach(self.labels, id: \.self) { value in
                let yPos = self.yPositionForValue(value)
                let isZeroLine = value == 0
                Path { path in
                    path.move(to: CGPoint(x: 0, y: yPos))
                    path.addLine(to: CGPoint(x: self.chartWidth, y: yPos))
                }
                .stroke(
                    isZeroLine ? AppTheme.fontColor.opacity(0.5) : AppTheme.fontColor.opacity(0.1),
                    style: StrokeStyle(lineWidth: isZeroLine ? 1.5 : 0.5, dash: isZeroLine ? [] : [4, 4])
                )
            }
        }
    }

    private func yPositionForValue(_ value: Double) -> CGFloat {
        ChartPositionCalculator.calculateYPosition(value: value, yAxisRange: self.yAxisRange, chartHeight: self.chartHeight)
    }
}

// MARK: - Chart X-Axis View
struct ChartXAxisView: View {
    let monthGroups: [MonthChartGroup]
    let totalTrades: Int
    let contentWidth: CGFloat
    let barWidth: CGFloat
    let barSpacing: CGFloat

    var body: some View {
        let padding: CGFloat = ResponsiveDesign.spacing(8)
        let totalBarSpace = self.barWidth + self.barSpacing

        HStack(alignment: .bottom, spacing: ResponsiveDesign.spacing(0)) {
            Spacer().frame(width: padding)

            ForEach(Array(self.monthGroups.enumerated()), id: \.element.month) { index, group in
                let monthWidth = CGFloat(group.trades.count) * totalBarSpace
                VStack(spacing: ResponsiveDesign.spacing(2)) {
                    if index > 0 {
                        Rectangle()
                            .fill(AppTheme.fontColor.opacity(0.1))
                            .frame(width: 1, height: ResponsiveDesign.spacing(8))
                    }
                    Text(group.month)
                        .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.spacing(9)))
                        .foregroundColor(AppTheme.fontColor.opacity(0.9))
                        .lineLimit(1)
                        .frame(width: monthWidth, alignment: .leading)
                        .multilineTextAlignment(.leading)
                }
                .frame(width: monthWidth, alignment: .leading)
            }
        }
        .frame(width: self.contentWidth, alignment: .leading)
        .padding(.top, ResponsiveDesign.spacing(4))
    }
}

// MARK: - Chart Bars View
struct ChartBarsView: View {
    let trades: [ChartTradeItem]
    let chartHeight: CGFloat
    let chartWidth: CGFloat
    let barWidth: CGFloat
    let yAxisRange: (min: Double, max: Double)

    var body: some View {
        let padding: CGFloat = ResponsiveDesign.spacing(8)
        let barSpacing: CGFloat = ResponsiveDesign.spacing(8)
        let totalBarSpace = self.barWidth + barSpacing

        HStack(alignment: .top, spacing: barSpacing) {
            ForEach(self.trades) { item in
                SingleBarView(
                    item: item,
                    chartHeight: self.chartHeight,
                    barWidth: self.barWidth,
                    totalSpace: totalBarSpace,
                    yAxisRange: self.yAxisRange
                )
                .frame(width: totalBarSpace)
            }
        }
        .padding(.horizontal, padding)
        .frame(minWidth: self.chartWidth, alignment: .leading)
    }
}

// MARK: - Single Bar View
struct SingleBarView: View {
    let item: ChartTradeItem
    let chartHeight: CGFloat
    let barWidth: CGFloat
    let totalSpace: CGFloat
    let yAxisRange: (min: Double, max: Double)

    private var zeroY: CGFloat { self.yPositionForValue(0) }
    private var valueY: CGFloat { self.yPositionForValue(self.item.tradeReturn.roi) }
    private var barHeight: CGFloat { max(abs(self.zeroY - self.valueY), 2) }
    private var isPositive: Bool { self.item.tradeReturn.roi >= 0 }

    var body: some View {
        GeometryReader { _ in
            ZStack {
                self.barStack
                if !self.item.tradeReturn.isActive && self.item.tradeReturn.roi != 0 {
                    self.roiLabel
                }
                if self.item.tradeReturn.isActive {
                    self.activeTradeLabel
                }
            }
        }
        .frame(width: self.totalSpace, height: self.chartHeight)
    }

    private var barStack: some View {
        VStack(spacing: ResponsiveDesign.spacing(0)) {
            if self.isPositive {
                Spacer().frame(height: self.valueY)
                BarRectangle(
                    isActive: self.item.tradeReturn.isActive,
                    isPositive: self.isPositive,
                    width: self.barWidth
                )
                .frame(height: self.barHeight)
                Spacer().frame(height: self.chartHeight - self.zeroY)
            } else {
                Spacer().frame(height: self.zeroY)
                BarRectangle(
                    isActive: self.item.tradeReturn.isActive,
                    isPositive: self.isPositive,
                    width: self.barWidth
                )
                .frame(height: self.barHeight)
                Spacer()
            }
        }
        .frame(width: self.barWidth, height: self.chartHeight)
    }

    private var roiLabel: some View {
        let labelY = self.isPositive
            ? self.valueY - ResponsiveDesign.spacing(12)
            : self.valueY + self.barHeight + ResponsiveDesign.spacing(12)
        return Text(self.item.tradeReturn.roi.formattedAsROIPercentage())
            .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.spacing(7)))
            .foregroundColor(self.isPositive ? AppTheme.accentGreen : AppTheme.accentRed)
            .rotationEffect(.degrees(-90))
            .fixedSize()
            .position(
                x: self.totalSpace / 2,
                y: max(ResponsiveDesign.spacing(15), min(labelY, self.chartHeight - ResponsiveDesign.spacing(15)))
            )
    }

    private var activeTradeLabel: some View {
        VStack(spacing: ResponsiveDesign.spacing(1)) {
            Text("activ")
                .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.spacing(6)))
            Text("Trade")
                .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.spacing(6)))
        }
        .foregroundColor(AppTheme.fontColor.opacity(0.6))
        .position(x: self.totalSpace / 2, y: self.zeroY - ResponsiveDesign.spacing(15))
    }

    private func yPositionForValue(_ value: Double) -> CGFloat {
        ChartPositionCalculator.calculateYPosition(value: value, yAxisRange: self.yAxisRange, chartHeight: self.chartHeight)
    }
}

// MARK: - Bar Rectangle
struct BarRectangle: View {
    let isActive: Bool
    let isPositive: Bool
    let width: CGFloat

    var body: some View {
        Rectangle()
            .fill(
                self.isActive
                    ? AppTheme.inputFieldBackground.opacity(0.6)
                    : (self.isPositive ? AppTheme.accentGreen : AppTheme.accentRed)
            )
            .frame(width: self.width)
    }
}

// MARK: - Chart Empty View
struct ChartEmptyView: View {
    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(12)) {
            Image(systemName: "chart.bar")
                .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize() * 2))
                .foregroundColor(AppTheme.fontColor.opacity(0.4))
            Text("No trade data available")
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.6))
        }
        .frame(maxWidth: .infinity, minHeight: ResponsiveDesign.spacing(200))
    }
}











