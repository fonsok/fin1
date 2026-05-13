import SwiftUI

// MARK: - CSR Investment Detail Sheet
/// Read-only detail view for CSR to view customer investment information

struct CSRInvestmentDetailSheet: View {
    let investment: CustomerInvestmentSummary
    let customerName: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ResponsiveDesign.spacing(16)) {
                    self.headerSection
                    self.financialSection
                    self.statusSection
                    self.timelineSection
                }
                .padding(.horizontal, ResponsiveDesign.horizontalPadding())
                .padding(.vertical, ResponsiveDesign.spacing(16))
            }
            .background(AppTheme.screenBackground.ignoresSafeArea())
            .navigationTitle("Investment Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Schließen") {
                        self.dismiss()
                    }
                    .foregroundColor(AppTheme.accentLightBlue)
                }
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: ResponsiveDesign.spacing(12)) {
            // Investment number badge
            Text(self.investment.investmentNumber)
                .font(ResponsiveDesign.captionFont())
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.accentLightBlue)
                .padding(.horizontal, ResponsiveDesign.spacing(12))
                .padding(.vertical, ResponsiveDesign.spacing(6))
                .background(AppTheme.accentLightBlue.opacity(0.15))
                .cornerRadius(ResponsiveDesign.spacing(6))

            // Customer name
            Text("Investor: \(self.customerName)")
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.8))

            // Trader name
            HStack(spacing: ResponsiveDesign.spacing(8)) {
                Image(systemName: "person.fill")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.accentLightBlue)

                Text("Trader: \(self.investment.traderName)")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor)
            }
        }
        .frame(maxWidth: .infinity)
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

            // Investment amount
            CSRDetailRow(
                icon: "eurosign.circle.fill",
                label: "Investitionsbetrag",
                value: self.investment.amount.formattedAsLocalizedCurrency(),
                valueColor: AppTheme.fontColor
            )

            Divider()

            // Current value
            CSRDetailRow(
                icon: "chart.line.uptrend.xyaxis",
                label: "Aktueller Wert",
                value: self.investment.currentValue.formattedAsLocalizedCurrency(),
                valueColor: AppTheme.fontColor
            )

            Divider()

            // Return percentage
            if let returnPercentage = investment.returnPercentage {
                let returnColor = returnPercentage >= 0 ? AppTheme.accentGreen : AppTheme.accentRed
                CSRDetailRow(
                    icon: returnPercentage >= 0 ? "arrow.up.right" : "arrow.down.right",
                    label: "Return (%)",
                    value: String(format: "%+.2f%%", returnPercentage),
                    valueColor: returnColor
                )
            } else {
                CSRDetailRow(
                    icon: "clock",
                    label: "Return (%)",
                    value: "pending",
                    valueColor: AppTheme.fontColor.opacity(0.7)
                )
            }

            Divider()

            // Profit/Loss
            let profitLoss = self.investment.currentValue - self.investment.amount
            CSRDetailRow(
                icon: "plusminus.circle.fill",
                label: "Return (€)",
                value: profitLoss.formattedAsLocalizedCurrency(),
                valueColor: profitLoss >= 0 ? AppTheme.accentGreen : AppTheme.accentRed
            )
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
                    text: self.statusDisplayText,
                    color: self.statusColor
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
                value: self.investment.createdAt.formatted(date: .long, time: .shortened),
                valueColor: AppTheme.fontColor
            )

            if let completedAt = investment.completedAt {
                Divider()

                CSRDetailRow(
                    icon: "checkmark.circle.fill",
                    label: "Abgeschlossen am",
                    value: completedAt.formatted(date: .long, time: .shortened),
                    valueColor: AppTheme.accentGreen
                )

                // Duration
                let duration = completedAt.timeIntervalSince(self.investment.createdAt)
                let days = Int(duration / 86_400)
                Divider()

                CSRDetailRow(
                    icon: "clock.fill",
                    label: "Laufzeit",
                    value: "\(days) Tage",
                    valueColor: AppTheme.fontColor
                )
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    // MARK: - Helpers

    private var statusDisplayText: String {
        switch self.investment.status.lowercased() {
        case "active": return "Aktiv"
        case "submitted": return "Eingereicht"
        case "completed": return "Abgeschlossen"
        case "cancelled": return "Storniert"
        default: return self.investment.status.capitalized
        }
    }

    private var statusColor: Color {
        switch self.investment.status.lowercased() {
        case "active": return AppTheme.accentOrange
        case "submitted": return AppTheme.accentLightBlue
        case "completed": return AppTheme.accentGreen
        case "cancelled": return AppTheme.accentRed
        default: return AppTheme.fontColor.opacity(0.7)
        }
    }
}

// MARK: - CSR Detail Row

struct CSRDetailRow: View {
    let icon: String
    let label: String
    let value: String
    let valueColor: Color

    var body: some View {
        HStack(spacing: ResponsiveDesign.spacing(12)) {
            Image(systemName: self.icon)
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.accentLightBlue)
                .frame(width: ResponsiveDesign.spacing(24))

            Text(self.label)
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))

            Spacer()

            Text(self.value)
                .font(ResponsiveDesign.bodyFont())
                .fontWeight(.medium)
                .foregroundColor(self.valueColor)
        }
    }
}
