import SwiftUI

// MARK: - CSR Trade Detail Sheet
/// Read-only detail view for CSR to view customer trade information

struct CSRTradeDetailSheet: View {
    let trade: CustomerTradeSummary
    let customerName: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ResponsiveDesign.spacing(16)) {
                    headerSection
                    tradeInfoSection
                    financialSection
                    statusSection
                    timelineSection
                }
                .padding(.horizontal, ResponsiveDesign.horizontalPadding())
                .padding(.vertical, ResponsiveDesign.spacing(16))
            }
            .background(AppTheme.screenBackground.ignoresSafeArea())
            .navigationTitle("Trade Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Schließen") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.accentLightBlue)
                }
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: ResponsiveDesign.spacing(12)) {
            // Trade number badge
            Text(trade.tradeNumber)
                .font(ResponsiveDesign.captionFont())
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.accentLightBlue)
                .padding(.horizontal, ResponsiveDesign.spacing(12))
                .padding(.vertical, ResponsiveDesign.spacing(6))
                .background(AppTheme.accentLightBlue.opacity(0.15))
                .cornerRadius(ResponsiveDesign.spacing(6))

            // Trader name
            Text("Trader: \(customerName)")
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.8))

            // Symbol and direction
            HStack(spacing: ResponsiveDesign.spacing(8)) {
                Text(trade.symbol)
                    .font(ResponsiveDesign.titleFont())
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.fontColor)

                Text("•")
                    .foregroundColor(AppTheme.fontColor.opacity(0.5))

                Text(trade.direction)
                    .font(ResponsiveDesign.bodyFont())
                    .fontWeight(.medium)
                    .foregroundColor(trade.direction.lowercased() == "buy" ? AppTheme.accentGreen : AppTheme.accentRed)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    // MARK: - Trade Info Section

    private var tradeInfoSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(16)) {
            Text("Trade-Informationen")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.fontColor)

            // Symbol
            CSRDetailRow(
                icon: "chart.bar.fill",
                label: "Symbol",
                value: trade.symbol,
                valueColor: AppTheme.fontColor
            )

            Divider()

            // Direction
            CSRDetailRow(
                icon: trade.direction.lowercased() == "buy" ? "arrow.up.circle.fill" : "arrow.down.circle.fill",
                label: "Richtung",
                value: trade.direction == "Buy" ? "Kauf" : "Verkauf",
                valueColor: trade.direction.lowercased() == "buy" ? AppTheme.accentGreen : AppTheme.accentRed
            )

            Divider()

            // Quantity
            CSRDetailRow(
                icon: "number.circle.fill",
                label: "Stückzahl",
                value: "\(trade.quantity)",
                valueColor: AppTheme.fontColor
            )
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    // MARK: - Financial Section

    private var financialSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(16)) {
            Text("Finanzen")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.fontColor)

            // Entry price
            CSRDetailRow(
                icon: "eurosign.circle.fill",
                label: "Einstiegspreis",
                value: trade.entryPrice.formattedAsLocalizedCurrency(),
                valueColor: AppTheme.fontColor
            )

            Divider()

            // Total investment
            let totalInvestment = trade.entryPrice * Double(trade.quantity)
            CSRDetailRow(
                icon: "banknote.fill",
                label: "Gesamtinvestition",
                value: totalInvestment.formattedAsLocalizedCurrency(),
                valueColor: AppTheme.fontColor
            )

            if let currentPrice = trade.currentPrice {
                Divider()

                // Current price
                CSRDetailRow(
                    icon: "chart.line.uptrend.xyaxis",
                    label: "Aktueller Preis",
                    value: currentPrice.formattedAsLocalizedCurrency(),
                    valueColor: AppTheme.fontColor
                )

                // Current value
                let currentValue = currentPrice * Double(trade.quantity)
                Divider()

                CSRDetailRow(
                    icon: "creditcard.fill",
                    label: "Aktueller Wert",
                    value: currentValue.formattedAsLocalizedCurrency(),
                    valueColor: AppTheme.fontColor
                )
            }

            if let profitLoss = trade.profitLoss {
                Divider()

                // Profit/Loss
                CSRDetailRow(
                    icon: profitLoss >= 0 ? "arrow.up.right.circle.fill" : "arrow.down.right.circle.fill",
                    label: "Gewinn/Verlust",
                    value: profitLoss.formattedAsLocalizedCurrency(),
                    valueColor: profitLoss >= 0 ? AppTheme.accentGreen : AppTheme.accentRed
                )

                // Return percentage
                let returnPercentage = (profitLoss / totalInvestment) * 100
                Divider()

                CSRDetailRow(
                    icon: "percent",
                    label: "Rendite",
                    value: String(format: "%+.2f%%", returnPercentage),
                    valueColor: returnPercentage >= 0 ? AppTheme.accentGreen : AppTheme.accentRed
                )
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    // MARK: - Status Section

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(16)) {
            Text("Status")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.fontColor)

            HStack {
                Text("Aktueller Status")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.7))

                Spacer()

                CSStatusBadge(
                    text: statusDisplayText,
                    color: statusColor
                )
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    // MARK: - Timeline Section

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(16)) {
            Text("Zeitverlauf")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.fontColor)

            // Created date
            CSRDetailRow(
                icon: "calendar.badge.plus",
                label: "Erstellt am",
                value: trade.createdAt.formatted(date: .long, time: .shortened),
                valueColor: AppTheme.fontColor
            )

            // Days since creation
            let daysSinceCreation = Calendar.current.dateComponents([.day], from: trade.createdAt, to: Date()).day ?? 0
            Divider()

            CSRDetailRow(
                icon: "clock.fill",
                label: isCompleted ? "Laufzeit" : "Laufzeit bisher",
                value: "\(daysSinceCreation) Tage",
                valueColor: AppTheme.fontColor
            )
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    // MARK: - Helpers

    private var isCompleted: Bool {
        trade.status.lowercased() == "completed" || trade.status.lowercased() == "closed"
    }

    private var statusDisplayText: String {
        switch trade.status.lowercased() {
        case "open": return "Offen"
        case "active": return "Aktiv"
        case "completed": return "Abgeschlossen"
        case "closed": return "Geschlossen"
        case "cancelled": return "Storniert"
        default: return trade.status.capitalized
        }
    }

    private var statusColor: Color {
        switch trade.status.lowercased() {
        case "open": return AppTheme.accentLightBlue
        case "active": return AppTheme.accentOrange
        case "completed", "closed": return AppTheme.accentGreen
        case "cancelled": return AppTheme.accentRed
        default: return AppTheme.fontColor.opacity(0.7)
        }
    }
}
