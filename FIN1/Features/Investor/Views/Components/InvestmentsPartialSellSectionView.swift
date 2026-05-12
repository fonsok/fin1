import SwiftUI

struct InvestmentsPartialSellSectionView: View {
    let partialSellRows: [InvestmentRow]
    let sortedTraderNames: [String]
    let groupedInvestments: [String: [InvestmentRow]]
    let traderDataService: any TraderDataServiceProtocol
    let onSelectInvestment: (Investment) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
            Text("Teil-Sell-Realisierungen (Active Investment)")
                .font(ResponsiveDesign.headlineFont())
                .foregroundColor(AppTheme.fontColor)
                .padding(.horizontal, ResponsiveDesign.horizontalPadding())

            Text("Nur Investments, bei denen bereits mindestens ein Teil-Verkauf serverseitig verbucht wurde — nicht jede aktive Position.")
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.secondaryText)
                .padding(.horizontal, ResponsiveDesign.horizontalPadding())

            Text("Laufende Investments ohne Teil-Verkauf stehen oben unter „Active Investments“ und bleiben bis zum Trade-Abschluss aktiv.")
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.tertiaryText)
                .padding(.horizontal, ResponsiveDesign.horizontalPadding())

            if !partialSellRows.isEmpty {
                ForEach(sortedTraderNames, id: \.self) { traderName in
                    let rows = groupedInvestments[traderName] ?? []
                    if let firstInvestment = rows.first?.investment {
                        let traderUsername = traderDataService.getTrader(by: firstInvestment.traderId)?.username ?? "---"
                        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(2)) {
                            Text("\"\(traderUsername)\"")
                                .font(ResponsiveDesign.bodyFont())
                                .foregroundColor(AppTheme.fontColor)
                                .padding(.horizontal, ResponsiveDesign.horizontalPadding())

                            Text("\(rows.count) investment\(rows.count == 1 ? "" : "s") mit Teil-Sell")
                                .font(ResponsiveDesign.captionFont())
                                .foregroundColor(AppTheme.secondaryText)
                                .padding(.horizontal, ResponsiveDesign.horizontalPadding())
                        }
                        .padding(.top, ResponsiveDesign.spacing(4))

                        VStack(spacing: ResponsiveDesign.spacing(8)) {
                            ForEach(rows, id: \.id) { row in
                                Button(action: {
                                    onSelectInvestment(row.investment)
                                }, label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(2)) {
                                            Text("Inv \(row.investment.canonicalDisplayReference)")
                                                .font(ResponsiveDesign.bodyFont())
                                                .foregroundColor(AppTheme.fontColor)
                                            Text(partialSellSummaryCaption(for: row.investment))
                                                .font(ResponsiveDesign.captionFont())
                                                .foregroundColor(AppTheme.secondaryText)
                                            Text("Letzter Teil-Sell am \(formattedPartialSellDate(row.investment.lastPartialSellAt))")
                                                .font(ResponsiveDesign.captionFont())
                                                .foregroundColor(AppTheme.tertiaryText)
                                        }
                                        Spacer()
                                        VStack(alignment: .trailing, spacing: ResponsiveDesign.spacing(2)) {
                                            Text(row.investment.realizedSellAmount.formattedAsLocalizedCurrency())
                                                .font(ResponsiveDesign.bodyFont())
                                                .foregroundColor(AppTheme.accentLightBlue)
                                            Image(systemName: "chevron.right")
                                                .font(ResponsiveDesign.captionFont())
                                                .foregroundColor(AppTheme.tertiaryText)
                                        }
                                    }
                                    .padding(.horizontal, ResponsiveDesign.spacing(12))
                                    .padding(.vertical, ResponsiveDesign.spacing(8))
                                    .background(AppTheme.sectionBackground.opacity(0.7))
                                    .cornerRadius(ResponsiveDesign.spacing(8))
                                })
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, ResponsiveDesign.horizontalPadding())
                        .padding(.vertical, ResponsiveDesign.spacing(4))
                    }
                }
            } else {
                Text("Keine Teil-Sell-Realisierungen: Für deine aktiven Investments liegt noch kein verbuchter Teil-Verkauf vor.")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.tertiaryText)
                    .padding(.horizontal, ResponsiveDesign.horizontalPadding())
                    .padding(.vertical, ResponsiveDesign.spacing(8))
            }
        }
        .padding(.top, ResponsiveDesign.spacing(4))
    }

    private func formattedPartialSellDate(_ date: Date?) -> String {
        guard let date else { return "n/a" }
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    /// Zeigt Trade-Stueckfortschritt (Server) und Bruttoerloes/Einlage.
    private func partialSellSummaryCaption(for investment: Investment) -> String {
        let pct = investment.realizedSellSharePercentage.formatted(.number.precision(.fractionLength(1)))
        let sells = investment.partialSellCount
        if let tradePct = investment.tradeSellVolumeProgressPercent {
            let t = tradePct.formatted(.number.precision(.fractionLength(1)))
            return "Teil-Sells: \(sells) • Trade (Stück): \(t)% • Bruttoerlös/Einlage: \(pct)%"
        }
        return "Teil-Sells: \(sells) • Bruttoerlös/Einlage: \(pct)%"
    }
}
