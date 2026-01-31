import SwiftUI
import Foundation

// MARK: - Data Table Adapter

/// Adapter to convert TradeOverviewItem to DataTable-compatible format
struct TradeTableRowData: Identifiable {
    let id: String
    let tradeNumber: String
    let tradeStart: String
    let tradeEnde: String
    let gewinnVerlust: String
    let provision: String
    let details: String
    let isActive: Bool
    let profitLoss: Double
    let grossProfit: Double
    let totalFees: Double
    let tradeId: String? // Trade ID for commission breakdown lookup
    let onDetailsTapped: () -> Void

    init(from trade: TradeOverviewItem, displayNumber: Int? = nil) {
        self.id = trade.id.uuidString
        // Use display number if provided (for sequential numbering in filtered views),
        // otherwise use the stored trade number with 3-digit formatting (001, 002, 003...)
        if let displayNumber = displayNumber {
            self.tradeNumber = String(format: "%03d", displayNumber)
        } else {
            self.tradeNumber = String(format: "%03d", trade.tradeNumber)
        }

        // Trade Start Date
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        let startDateString = formatter.string(from: trade.startDate)
        // Split date into two lines: "dd.MM." and "yyyy"
        let startComponents = startDateString.components(separatedBy: ".")
        if startComponents.count == 3 {
            self.tradeStart = "\(startComponents[0]).\(startComponents[1]).\n\(startComponents[2])"
        } else {
            self.tradeStart = startDateString
        }

        // Trade End Date
        if trade.isActive {
            self.tradeEnde = "aktiv"
        } else {
            let endDateString = formatter.string(from: trade.endDate)
            // Split date into two lines: "dd.MM." and "yyyy"
            let endComponents = endDateString.components(separatedBy: ".")
            if endComponents.count == 3 {
                self.tradeEnde = "\(endComponents[0]).\(endComponents[1]).\n\(endComponents[2])"
            } else {
                self.tradeEnde = endDateString
            }
        }

        if trade.isActive {
            self.gewinnVerlust = trade.statusText
        } else {
            let currencyText = trade.profitLoss.formatted(.currency(code: "EUR"))
            let percentageText = trade.returnPercentage.formattedAsROIPercentage() + " "
            self.gewinnVerlust = "\(currencyText)\n\(percentageText)"
        }

        if trade.isActive {
            self.provision = trade.statusDetail
        } else {
            self.provision = trade.commission == 0 ? "-" : trade.commission.formatted(.currency(code: "EUR"))
        }

        self.details = trade.isActive ? "message" : "arrow.down.circle"
        self.isActive = trade.isActive
        self.profitLoss = trade.profitLoss
        self.grossProfit = trade.grossProfit
        self.totalFees = trade.totalFees
        self.tradeId = trade.tradeId
        self.onDetailsTapped = trade.onDetailsTapped
    }
}

// MARK: - Column Width Calculation

/// Holds the calculated widths for each column
struct ColumnWidths {
    let tradeNumber: CGFloat
    let tradeStart: CGFloat
    let tradeEnde: CGFloat
    let gewinnVerlust: CGFloat
    let provision: CGFloat
    let details: CGFloat
}

/// Helper to calculate dynamic column widths based on content
struct ColumnWidthCalculator {
    static func calculate(for trades: [TradeTableRowData]) -> ColumnWidths {
        // Use responsive font sizes
        let font = UIFont.preferredFont(forTextStyle: ResponsiveDesign.isCompactDevice() ? .caption1 : .subheadline)
        let cellFont = UIFont.preferredFont(forTextStyle: ResponsiveDesign.isCompactDevice() ? .caption1 : .subheadline)
        let captionFont = UIFont.preferredFont(forTextStyle: .caption1)

        // Calculate max width for each column based on header and cell content
        var maxTradeNumberWidth = "Trade\nNr.".width(usingFont: font)
        var maxTradeStartWidth = "Trade\nBeginn".width(usingFont: font)
        var maxTradeEndeWidth = "Trade\nEnde".width(usingFont: font)
        var maxGvWidth = "Profit".width(usingFont: font)
        // Calculate max width for commission column header (with percentage)
        // Use a placeholder that includes typical percentage format
        let commissionHeaderPlaceholder = "Commission (10%)"
        var maxCommissionWidth = commissionHeaderPlaceholder.width(usingFont: font)
        let detailsWidth: CGFloat = 30 // Icon width is relatively fixed

        for trade in trades {
            maxTradeNumberWidth = max(maxTradeNumberWidth, trade.tradeNumber.width(usingFont: cellFont))

            // For Trade Start, calculate width for each line separately
            if trade.tradeStart.contains("\n") {
                let lines = trade.tradeStart.components(separatedBy: "\n")
                for line in lines {
                    maxTradeStartWidth = max(maxTradeStartWidth, line.width(usingFont: cellFont))
                }
            } else {
                maxTradeStartWidth = max(maxTradeStartWidth, trade.tradeStart.width(usingFont: cellFont))
            }

            // For Trade Ende, calculate width for each line separately
            if trade.tradeEnde.contains("\n") {
                let lines = trade.tradeEnde.components(separatedBy: "\n")
                for line in lines {
                    maxTradeEndeWidth = max(maxTradeEndeWidth, line.width(usingFont: cellFont))
                }
            } else {
                maxTradeEndeWidth = max(maxTradeEndeWidth, trade.tradeEnde.width(usingFont: cellFont))
            }

            if trade.isActive {
                maxGvWidth = max(maxGvWidth, trade.gewinnVerlust.width(usingFont: cellFont))
            } else {
                let lines = trade.gewinnVerlust.components(separatedBy: "\n")
                if lines.count >= 2 {
                    let currencyWidth = lines[0].width(usingFont: cellFont)
                    let percentageWidth = lines[1].width(usingFont: captionFont)
                    maxGvWidth = max(maxGvWidth, currencyWidth, percentageWidth)
                }
            }
            maxCommissionWidth = max(maxCommissionWidth, trade.provision.width(usingFont: cellFont))
        }

        // Use responsive padding for breathing room
        let padding: CGFloat = ResponsiveDesign.spacing(8)

        return ColumnWidths(
            tradeNumber: maxTradeNumberWidth + padding,
            tradeStart: maxTradeStartWidth + padding,
            tradeEnde: maxTradeEndeWidth + padding,
            gewinnVerlust: maxGvWidth + padding,
            provision: maxCommissionWidth + padding,
            details: detailsWidth + padding
        )
    }
}

// Helper extension to calculate string width
extension String {
    func width(usingFont font: UIFont) -> CGFloat {
        let fontAttributes = [NSAttributedString.Key.font: font]
        let size = self.size(withAttributes: fontAttributes)
        return ceil(size.width)
    }
}

// MARK: - Dynamic Trades Table Component

struct TradesTable: View {
    let trades: [TradeTableRowData]
    let columnWidths: ColumnWidths
    let commissionPercentage: String
    let services: AppServices // Pass services for commission breakdown

    var body: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 0) {
                // Table Header
                TradesTableHeader(columnWidths: columnWidths, commissionPercentage: commissionPercentage)

                // Table Rows
                ForEach(Array(trades.enumerated()), id: \.element.id) { index, trade in
                    TradesTableRow(trade: trade, index: index, columnWidths: columnWidths, services: services)
                }
            }
        }
    }
}

struct TradesTableHeader: View {
    let columnWidths: ColumnWidths
    let commissionPercentage: String

    var body: some View {
        HStack(spacing: ResponsiveDesign.spacing(8)) {
            Text("Trade\nNr.")
                .frame(width: columnWidths.tradeNumber, alignment: .leading)
            Text("Trade\nBeginn")
                .frame(width: columnWidths.tradeStart, alignment: .leading)
            Text("Trade\nEnde")
                .frame(width: columnWidths.tradeEnde, alignment: .leading)
            Text("Profit")
                .frame(width: columnWidths.gewinnVerlust, alignment: .leading)
            Text("Commission\n(\(commissionPercentage))")
                .frame(width: columnWidths.provision, alignment: .leading)
            Text("i")
                .frame(width: columnWidths.details, alignment: .center)
        }
        .font(ResponsiveDesign.bodyFont())
        .fontWeight(.regular)
        .foregroundColor(Color(red: 0.019, green: 0.070, blue: 0.129))
        .multilineTextAlignment(.leading)
        .lineLimit(nil)
        .padding(.vertical, ResponsiveDesign.spacing(4))
        .padding(.horizontal, ResponsiveDesign.spacing(16))
        .background(AppTheme.inputFieldBackground)
        .cornerRadius(ResponsiveDesign.spacing(8))
    }
}

struct TradesTableRow: View {
    let trade: TradeTableRowData
    let index: Int
    let columnWidths: ColumnWidths
    let services: AppServices
    @State private var showProfitInfo = false
    @State private var showCommissionInfo = false

    var body: some View {
        HStack(spacing: ResponsiveDesign.spacing(8)) {
            // Trade Number
            Text(trade.tradeNumber)
                .frame(width: columnWidths.tradeNumber, alignment: .leading)

            // Trade Start Date
            Text(trade.tradeStart)
                .foregroundColor(AppTheme.fontColor.opacity(0.8))
                .frame(width: columnWidths.tradeStart, alignment: .leading)
                .lineLimit(nil)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            // Trade End Date or Status
            Text(trade.tradeEnde)
                .foregroundColor(trade.isActive ? AppTheme.accentOrange : AppTheme.fontColor.opacity(0.8))
                .frame(width: columnWidths.tradeEnde, alignment: .leading)
                .lineLimit(nil)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            // P/L with info icon moved to percentage row
            VStack(alignment: .leading, spacing: 2) {
                if trade.isActive {
                    Text(trade.gewinnVerlust)
                        .foregroundColor(AppTheme.accentLightBlue)
                } else {
                    let lines = trade.gewinnVerlust.components(separatedBy: "\n")
                    if lines.count >= 2 {
                        Text(lines[0]) // Currency amount - now has full width without icon
                            .fontWeight(.medium)
                            .foregroundColor(trade.profitLoss >= 0 ? AppTheme.accentGreen : AppTheme.accentRed)

                        HStack(spacing: ResponsiveDesign.spacing(2)) {
                            Text(lines[1]) // Percentage
                                .font(ResponsiveDesign.captionFont())
                                .foregroundColor(trade.profitLoss >= 0 ? AppTheme.accentGreen : AppTheme.accentRed)

                            // Info icon moved to percentage row to avoid truncation
                            Button(action: {
                                showProfitInfo = true
                            }, label: {
                                Image(systemName: "info.circle")
                                    .font(.system(size: ResponsiveDesign.iconSize() * 0.7))
                                    .foregroundColor(AppTheme.accentLightBlue.opacity(0.7))
                            })
                        }
                    }
                }
            }
            .frame(width: columnWidths.gewinnVerlust, alignment: .leading)

            // Commission with info icon
            if trade.isActive {
                Text(trade.provision)
                    .frame(width: columnWidths.provision, alignment: .leading)
            } else {
                HStack(spacing: ResponsiveDesign.spacing(2)) {
                    Text(trade.provision)

                    // Info icon for commission breakdown (only show if commission > 0)
                    if trade.provision != "-" {
                        Button(action: {
                            showCommissionInfo = true
                        }, label: {
                            Image(systemName: "info.circle")
                                .font(.system(size: ResponsiveDesign.iconSize() * 0.7))
                                .foregroundColor(AppTheme.accentLightBlue.opacity(0.7))
                        })
                    }
                }
                .frame(width: columnWidths.provision, alignment: .leading)
            }

            // Details action
            Button(action: trade.onDetailsTapped, label: {
                Image(systemName: trade.details == "message" ? "shippingbox" : trade.details == "arrow.down.circle" ? "doc.text" : trade.details)
                    .foregroundColor(AppTheme.accentLightBlue)
            })
            .frame(width: columnWidths.details, alignment: .center)
        }
        .font(ResponsiveDesign.bodyFont())
        .foregroundColor(AppTheme.fontColor.opacity(0.8))
        .padding(.horizontal, ResponsiveDesign.spacing(16))
        .padding(.vertical, ResponsiveDesign.spacing(12))
        .background(backgroundColor)
        .cornerRadius(ResponsiveDesign.spacing(8))
        .sheet(isPresented: $showProfitInfo) {
            ProfitInfoSheet()
        }
        .sheet(isPresented: $showCommissionInfo) {
            if let tradeId = trade.tradeId {
                CommissionBreakdownSheet(
                    tradeId: tradeId,
                    services: services
                )
            }
        }
    }

    private var backgroundColor: Color {
        return index % 2 == 0 ? AppTheme.sectionBackground : AppTheme.sectionBackground.opacity(0.8)
    }

}

// MARK: - Profit Info Sheet
struct ProfitInfoSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(20)) {
            Text("Ergebnis vor Steuern")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.medium)
                .foregroundColor(AppTheme.fontColor)
                .multilineTextAlignment(.center)
                .padding(.top, ResponsiveDesign.spacing(20))

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.sectionBackground)
        .presentationDetents([.height(200)])
        .presentationDragIndicator(.visible)
    }
}
