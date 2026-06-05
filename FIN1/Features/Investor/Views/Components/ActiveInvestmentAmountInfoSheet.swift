import SwiftUI

/// Erklärt, wie der in der Tabelle "Active Investments" angezeigte Betrag (Total Buy / Gesamtkaufkosten)
/// aus dem reservierten Nominal und dem Residual (Rest aus der Stückzahl-Rundung) entsteht.
/// SSOT: gebuchter RSV→TRD/AVA-Split bzw. Collection-Bill-Metadaten — die exakten Belegzeilen stehen
/// im Kontoauszug bzw. unter „Beleg / Rechnung" in derselben Tabellenzeile.
struct ActiveInvestmentAmountInfoSheet: View {
    let row: InvestmentRow
    @Environment(\.dismiss) private var dismiss

    private var nominal: Double {
        self.row.investment.amount
    }

    private var poolTradingAmount: Double? {
        guard let value = row.investment.poolTradingAmount, value > 0.005 else { return nil }
        return value
    }

    private var residual: Double? {
        guard let booked = poolTradingAmount else { return nil }
        return max(0, self.nominal - booked)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(16)) {
                    Text("Wie kommt der Betrag zustande?")
                        .font(ResponsiveDesign.headlineFont())
                        .fontWeight(.bold)
                        .foregroundColor(AppTheme.fontColor)

                    Text(
                        "Der in der Tabelle angezeigte Betrag entspricht den gebuchten Gesamtkaufkosten "
                            + "(Total Buy Cost) des aktivierten Investments — also dem Anteil des reservierten "
                            + "Nominals, der tatsächlich in den Trade geflossen ist. Der Rest aus der Stückzahl-"
                            + "Rundung (Residual) bleibt zunächst auf dem Konto und wird mit dem Settlement zurück­"
                            + "gebucht."
                    )
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor)

                    self.breakdownTable

                    VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(6)) {
                        Text("Wo finde ich die Buchung?")
                            .font(ResponsiveDesign.bodyFont())
                            .fontWeight(.semibold)
                            .foregroundColor(AppTheme.fontColor)

                        Text(
                            "Die exakten Belegzeilen (RSV → TRD / AVA) findest du im Kontoauszug. "
                                + "In dieser Tabelle ist der zugehörige Beleg über die Spalte \"Beleg / Rechnung\" "
                                + "verlinkt."
                        )
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(AppTheme.secondaryText)
                    }
                    .padding(ResponsiveDesign.spacing(12))
                    .background(AppTheme.sectionBackground)
                    .cornerRadius(ResponsiveDesign.spacing(8))

                    if self.poolTradingAmount == nil {
                        Text(
                            "Hinweis: Die Gesamtkaufkosten werden mit der Aktivierung des Trades gebucht. "
                                + "Bis dahin zeigt die Tabelle das reservierte Nominal."
                        )
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.7))
                        .italic()
                    }
                }
                .padding(ResponsiveDesign.horizontalPadding())
                .padding(.top, ResponsiveDesign.spacing(4))
                .padding(.bottom, ResponsiveDesign.spacing(16))
            }
            .background(AppTheme.screenBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fertig") {
                        self.dismiss()
                    }
                    .foregroundColor(AppTheme.accentLightBlue)
                }
            }
        }
    }

    // MARK: - Breakdown Table

    private var breakdownTable: some View {
        VStack(spacing: ResponsiveDesign.spacing(0)) {
            self.headerRow

            Divider()

            self.tableRow(
                label: "Reserviertes Nominal",
                value: self.nominal.formattedAsLocalizedCurrency(),
                isBold: false
            )

            Divider()

            if let residual {
                self.tableRow(
                    label: "− Residual (Rest aus Stückzahl-Rundung)",
                    value: residual.formattedAsLocalizedCurrency(),
                    isBold: false
                )

                Divider()
            } else {
                self.tableRow(
                    label: "− Residual",
                    value: "—",
                    isBold: false
                )

                Divider()
            }

            self.tableRow(
                label: "= Gesamtkaufkosten (Total Buy)",
                value: (self.poolTradingAmount ?? self.nominal).formattedAsLocalizedCurrency(),
                isBold: true
            )
        }
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(8))
    }

    private var headerRow: some View {
        HStack {
            Text("Position")
                .font(ResponsiveDesign.captionFont())
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.fontColor.opacity(0.7))
            Spacer()
            Text("Betrag")
                .font(ResponsiveDesign.captionFont())
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.fontColor.opacity(0.7))
        }
        .padding(.horizontal, ResponsiveDesign.spacing(12))
        .padding(.vertical, ResponsiveDesign.spacing(8))
        .background(AppTheme.inputFieldBackground.opacity(0.5))
    }

    private func tableRow(label: String, value: String, isBold: Bool) -> some View {
        HStack {
            Text(label)
                .font(ResponsiveDesign.bodyFont())
                .fontWeight(isBold ? .semibold : .regular)
                .foregroundColor(AppTheme.fontColor)
            Spacer()
            Text(value)
                .font(ResponsiveDesign.bodyFont())
                .fontWeight(isBold ? .semibold : .regular)
                .foregroundColor(AppTheme.fontColor)
        }
        .padding(.horizontal, ResponsiveDesign.spacing(12))
        .padding(.vertical, ResponsiveDesign.spacing(10))
    }
}
