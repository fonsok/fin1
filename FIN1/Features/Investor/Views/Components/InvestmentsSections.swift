import SwiftUI

/// Per-trader group under Reserved/Active: prefer Parse username, else `Investment.traderName` (avoids literal "---" when trader cache misses).
private enum InvestmentsTraderDisplay {
    static func usernameLine(
        traderDataService: any TraderDataServiceProtocol,
        firstRow: InvestmentRow
    ) -> String {
        if let trader = traderDataService.getTrader(by: firstRow.investment.traderId) {
            let trimmed = trader.username.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        let fromInvestment = firstRow.investment.traderName.trimmingCharacters(in: .whitespacesAndNewlines)
        return fromInvestment.isEmpty ? "—" : fromInvestment
    }
}

struct InvestmentsHeaderSectionView: View {
    let currentUser: User?

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
            Text("Investments")
                .font(ResponsiveDesign.titleFont())
                .foregroundColor(AppTheme.fontColor)

            if let user = currentUser {
                Text("Kunden-Nr.: \(user.customerNumber)")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.secondaryText)

                Text("Kontoinhaber: \(user.fullName)")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.secondaryText)
            } else {
                Text("Kunden-Nr.: ...")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.secondaryText)

                Text("Kontoinhaber: ...")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, ResponsiveDesign.horizontalPadding())
        .padding(.top, ResponsiveDesign.spacing(8))
        .padding(.bottom, ResponsiveDesign.spacing(4))
    }
}

struct InvestmentsSectionSeparatorView: View {
    var body: some View {
        Rectangle()
            .fill(AppTheme.systemSeparator)
            .frame(height: 1)
            .padding(.horizontal, ResponsiveDesign.horizontalPadding())
            .padding(.vertical, ResponsiveDesign.spacing(4))
    }
}

struct InvestmentsReservedSectionView: View {
    let reservedInvestmentRows: [InvestmentRow]
    let sortedTraderNames: [String]
    let groupedInvestments: [String: [InvestmentRow]]
    let totalReservedAmount: Double
    let traderDataService: any TraderDataServiceProtocol
    @Binding var columnWidths: [String: CGFloat]
    let onDeleteInvestment: (InvestmentRow) -> Void
    let onShowStatusInfo: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
            HStack(alignment: .firstTextBaseline) {
                Text("Reserved Investments")
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(AppTheme.fontColor)

                Spacer()

                if !reservedInvestmentRows.isEmpty {
                    Text("Σ \(totalReservedAmount.formattedAsLocalizedCurrency())")
                        .font(ResponsiveDesign.headlineFont())
                        .foregroundColor(AppTheme.secondaryText)
                }
            }
            .padding(.horizontal, ResponsiveDesign.horizontalPadding())

            Text("Allocated to upcoming trades — can be cancelled")
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.secondaryText)
                .padding(.horizontal, ResponsiveDesign.horizontalPadding())

            if !reservedInvestmentRows.isEmpty {
                ForEach(sortedTraderNames, id: \.self) { traderName in
                    let traderInvestments = groupedInvestments[traderName] ?? []
                    if let firstInvestment = traderInvestments.first {
                        let traderUsername = InvestmentsTraderDisplay.usernameLine(
                            traderDataService: traderDataService,
                            firstRow: firstInvestment
                        )
                        traderGroupHeader(username: traderUsername, count: traderInvestments.count)
                            .padding(.top, ResponsiveDesign.spacing(4))

                        VStack(spacing: ResponsiveDesign.spacing(0)) {
                            let traderTotalAmount = traderInvestments.reduce(0) { $0 + $1.amount }
                            let traderProfits = traderInvestments.compactMap { $0.profit }
                            let traderTotalProfit = traderProfits.isEmpty ? nil : traderProfits.reduce(0, +)
                            let traderTotalReturn = traderTotalProfit.map { profit in
                                traderTotalAmount > 0 ? (profit / traderTotalAmount) * 100 : nil
                            } ?? nil

                            OpenInvestmentsTable(
                                pools: traderInvestments,
                                columnWidths: $columnWidths,
                                totalAmount: traderTotalAmount,
                                totalProfit: traderTotalProfit,
                                totalReturn: traderTotalReturn,
                                onDeleteInvestment: onDeleteInvestment,
                                onShowStatusInfo: onShowStatusInfo
                            )
                        }
                        .background(AppTheme.sectionBackground)
                        .padding(.horizontal, ResponsiveDesign.horizontalPadding())
                        .padding(.vertical, ResponsiveDesign.spacing(4))
                    }
                }
            } else {
                Text("No reserved investments")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.tertiaryText)
                    .padding(.horizontal, ResponsiveDesign.horizontalPadding())
                    .padding(.vertical, ResponsiveDesign.spacing(8))
            }
        }
        .padding(.top, ResponsiveDesign.spacing(4))
    }

    private func traderGroupHeader(username: String, count: Int) -> some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(2)) {
            Text("\"\(username)\"")
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor)
                .padding(.horizontal, ResponsiveDesign.horizontalPadding())

            Text("\(count) investment\(count == 1 ? "" : "s")")
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.secondaryText)
                .padding(.horizontal, ResponsiveDesign.horizontalPadding())
        }
    }
}

struct InvestmentsActiveSectionView: View {
    let activeInvestmentRows: [InvestmentRow]
    let sortedTraderNames: [String]
    let groupedInvestments: [String: [InvestmentRow]]
    let traderDataService: any TraderDataServiceProtocol
    @Binding var columnWidths: [String: CGFloat]
    let onDeleteInvestment: (InvestmentRow) -> Void
    let onShowStatusInfo: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
            Text("Active Investments")
                .font(ResponsiveDesign.headlineFont())
                .foregroundColor(AppTheme.fontColor)
                .padding(.horizontal, ResponsiveDesign.horizontalPadding())

            Text("Deployed in active trading — locked until trade completes")
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.secondaryText)
                .padding(.horizontal, ResponsiveDesign.horizontalPadding())

            if !activeInvestmentRows.isEmpty {
                ForEach(sortedTraderNames, id: \.self) { traderName in
                    let traderInvestments = groupedInvestments[traderName] ?? []
                    if let firstInvestment = traderInvestments.first {
                        let traderUsername = InvestmentsTraderDisplay.usernameLine(
                            traderDataService: traderDataService,
                            firstRow: firstInvestment
                        )
                        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(2)) {
                            Text("\"\(traderUsername)\"")
                                .font(ResponsiveDesign.bodyFont())
                                .foregroundColor(AppTheme.fontColor)
                                .padding(.horizontal, ResponsiveDesign.horizontalPadding())

                            Text("\(traderInvestments.count) investment\(traderInvestments.count == 1 ? "" : "s")")
                                .font(ResponsiveDesign.captionFont())
                                .foregroundColor(AppTheme.secondaryText)
                                .padding(.horizontal, ResponsiveDesign.horizontalPadding())
                        }
                        .padding(.top, ResponsiveDesign.spacing(4))

                        VStack(spacing: ResponsiveDesign.spacing(0)) {
                            let traderTotalAmount = traderInvestments.reduce(0) { $0 + $1.amount }
                            let traderProfits = traderInvestments.compactMap { $0.profit }
                            let traderTotalProfit = traderProfits.isEmpty ? nil : traderProfits.reduce(0, +)
                            let traderTotalReturn = traderTotalProfit.map { profit in
                                traderTotalAmount > 0 ? (profit / traderTotalAmount) * 100 : nil
                            } ?? nil

                            OpenInvestmentsTable(
                                pools: traderInvestments,
                                columnWidths: $columnWidths,
                                totalAmount: traderTotalAmount,
                                totalProfit: traderTotalProfit,
                                totalReturn: traderTotalReturn,
                                onDeleteInvestment: onDeleteInvestment,
                                onShowStatusInfo: onShowStatusInfo
                            )
                        }
                        .background(AppTheme.sectionBackground)
                        .padding(.horizontal, ResponsiveDesign.horizontalPadding())
                        .padding(.vertical, ResponsiveDesign.spacing(4))
                    }
                }
            } else {
                Text("No active investments")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.tertiaryText)
                    .padding(.horizontal, ResponsiveDesign.horizontalPadding())
                    .padding(.vertical, ResponsiveDesign.spacing(8))
            }
        }
        .padding(.top, ResponsiveDesign.spacing(4))
    }
}

struct InvestmentsCompletedSectionView: View {
    @Binding var selectedTimePeriod: InvestmentTimePeriod
    let allCompletedCount: Int
    let completedInvestmentsByTimePeriod: [Investment]
    let completedInvestmentDocRefs: [String: (docNumber: String?, invoiceNumber: String?)]
    let completedTraderUsernames: [String: String]
    let completedTradeNumbers: [String: String]
    let completedInvestmentSummaries: [String: InvestorInvestmentStatementSummary]
    let completedCanonicalSummaries: [String: ServerInvestmentCanonicalSummary]
    let onTimePeriodChanged: (InvestmentTimePeriod) -> Void
    let onShowDetails: (Investment) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
            Text("Completed Investments")
                .font(ResponsiveDesign.headlineFont())
                .foregroundColor(AppTheme.fontColor)
                .padding(.horizontal, ResponsiveDesign.horizontalPadding())

            InvestmentsTimePeriodHeaderView(
                selectedTimePeriod: $selectedTimePeriod,
                onTimePeriodChanged: onTimePeriodChanged
            )

            if !completedInvestmentsByTimePeriod.isEmpty {
                CompletedInvestmentsTable(
                    investments: completedInvestmentsByTimePeriod,
                    investmentDocRefs: completedInvestmentDocRefs,
                    traderUsernames: completedTraderUsernames,
                    tradeNumbers: completedTradeNumbers,
                    investmentSummaries: completedInvestmentSummaries,
                    canonicalSummaries: completedCanonicalSummaries,
                    onShowDetails: onShowDetails
                )
            } else {
                emptyState
            }
        }
        .padding(.top, ResponsiveDesign.spacing(4))
    }

    private var emptyState: some View {
        VStack(spacing: ResponsiveDesign.spacing(8)) {
            if allCompletedCount == 0 {
                VStack(spacing: ResponsiveDesign.spacing(4)) {
                    Image(systemName: "tray")
                        .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize() * 2))
                        .foregroundColor(AppTheme.quaternaryText)

                    Text("No completed investments")
                        .font(ResponsiveDesign.headlineFont())
                        .foregroundColor(AppTheme.secondaryText)

                    Text("Investments appear here when completed or cancelled.")
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(AppTheme.tertiaryText)
                        .multilineTextAlignment(.center)
                }
            } else {
                VStack(spacing: ResponsiveDesign.spacing(4)) {
                    Text("No completed investments for selected time period")
                        .font(ResponsiveDesign.headlineFont())
                        .foregroundColor(AppTheme.secondaryText)

                    Text("Total completed: \(allCompletedCount)")
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(AppTheme.tertiaryText)

                    Text("Try selecting a different time period")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.quaternaryText)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, ResponsiveDesign.horizontalPadding())
        .padding(.vertical, ResponsiveDesign.spacing(16))
    }
}

