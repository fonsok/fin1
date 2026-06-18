import SwiftUI

/// Per-trader group under Reserved/Active: prefer Parse username, else `Investment.traderName` (avoids literal "---" when trader cache misses).
private enum InvestmentsTraderDisplay {
    static func usernameLine(
        traderDataService: any TraderDataServiceProtocol,
        firstRow: InvestmentRow
    ) -> String {
        firstRow.investment.displayTraderUsername(using: traderDataService)
    }
}

/// One trader block: header + open investments table in the shared table shell (Reserved/Active).
private struct InvestmentsOpenTableTraderGroup: View {
    let traderUsername: String
    let traderInvestments: [InvestmentRow]
    @Binding var columnWidths: [String: CGFloat]
    let onDeleteInvestment: (InvestmentRow) -> Void
    let onShowStatusInfo: () -> Void
    var onShowAmountInfo: ((InvestmentRow) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
            InvestmentsTraderGroupHeader(
                username: self.traderUsername,
                investmentCount: self.traderInvestments.count
            )
            .padding(.top, ResponsiveDesign.spacing(4))
            .padding(.horizontal, ResponsiveDesign.mainHorizontalPadding())

            OpenInvestmentsTable(
                pools: self.traderInvestments,
                columnWidths: self.$columnWidths,
                totalAmount: self.traderTotalAmount,
                totalProfit: self.traderTotalProfit,
                totalReturn: self.traderTotalReturn,
                onDeleteInvestment: self.onDeleteInvestment,
                onShowStatusInfo: self.onShowStatusInfo,
                onShowAmountInfo: self.onShowAmountInfo
            )
            .investmentsTableShell()
        }
    }

    private var traderTotalAmount: Double {
        self.traderInvestments.reduce(0) { $0 + $1.amount }
    }

    private var traderTotalProfit: Double? {
        let profits = self.traderInvestments.compactMap { $0.profit }
        return profits.isEmpty ? nil : profits.reduce(0, +)
    }

    private var traderTotalReturn: Double? {
        guard let traderTotalProfit = self.traderTotalProfit else { return nil }
        return self.traderTotalAmount > 0 ? (traderTotalProfit / self.traderTotalAmount) * 100 : nil
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
    let titleStripeIndex: Int
    let reservedInvestmentRows: [InvestmentRow]
    let sortedTraderNames: [String]
    let groupedInvestments: [String: [InvestmentRow]]
    let totalReservedAmount: Double
    let traderDataService: any TraderDataServiceProtocol
    @Binding var columnWidths: [String: CGFloat]
    let onDeleteInvestment: (InvestmentRow) -> Void
    let onShowStatusInfo: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            self.sectionTitleBlock
                .stripedListSection(stripeIndex: self.titleStripeIndex)

            if !self.reservedInvestmentRows.isEmpty {
                self.tableContent
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var sectionTitleBlock: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
            HStack(alignment: .firstTextBaseline) {
                Text("Reserved Investments")
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(AppTheme.fontColor)

                Spacer()

                if !self.reservedInvestmentRows.isEmpty {
                    Text("Σ \(self.totalReservedAmount.formattedAsLocalizedCurrency())")
                        .font(ResponsiveDesign.headlineFont())
                        .foregroundColor(AppTheme.secondaryText)
                }
            }

            Text("Allocated to upcoming trades — can be cancelled")
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.secondaryText)

            if self.reservedInvestmentRows.isEmpty {
                Text("No reserved investments")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.tertiaryText)
                    .padding(.vertical, ResponsiveDesign.spacing(8))
            }
        }
    }

    private var tableContent: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
            ForEach(self.sortedTraderNames, id: \.self) { traderName in
                let traderInvestments = self.groupedInvestments[traderName] ?? []
                if let firstInvestment = traderInvestments.first {
                    let traderUsername = InvestmentsTraderDisplay.usernameLine(
                        traderDataService: self.traderDataService,
                        firstRow: firstInvestment
                    )
                    InvestmentsOpenTableTraderGroup(
                        traderUsername: traderUsername,
                        traderInvestments: traderInvestments,
                        columnWidths: self.$columnWidths,
                        onDeleteInvestment: self.onDeleteInvestment,
                        onShowStatusInfo: self.onShowStatusInfo
                    )
                }
            }
        }
    }
}

struct InvestmentsActiveSectionView: View {
    let titleStripeIndex: Int
    let activeInvestmentRows: [InvestmentRow]
    let sortedTraderNames: [String]
    let groupedInvestments: [String: [InvestmentRow]]
    let traderDataService: any TraderDataServiceProtocol
    @Binding var columnWidths: [String: CGFloat]
    let onDeleteInvestment: (InvestmentRow) -> Void
    let onShowStatusInfo: () -> Void
    let onShowAmountInfo: (InvestmentRow) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            self.sectionTitleBlock
                .stripedListSection(stripeIndex: self.titleStripeIndex)

            if !self.activeInvestmentRows.isEmpty {
                self.tableContent
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var sectionTitleBlock: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
            Text("Active Investments")
                .font(ResponsiveDesign.headlineFont())
                .foregroundColor(AppTheme.fontColor)

            Text("Deployed in active trading — locked until trade completes")
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.secondaryText)

            if self.activeInvestmentRows.isEmpty {
                Text("No active investments")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.tertiaryText)
                    .padding(.vertical, ResponsiveDesign.spacing(8))
            }
        }
    }

    private var tableContent: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
            ForEach(self.sortedTraderNames, id: \.self) { traderName in
                let traderInvestments = self.groupedInvestments[traderName] ?? []
                if let firstInvestment = traderInvestments.first {
                    let traderUsername = InvestmentsTraderDisplay.usernameLine(
                        traderDataService: self.traderDataService,
                        firstRow: firstInvestment
                    )
                    InvestmentsOpenTableTraderGroup(
                        traderUsername: traderUsername,
                        traderInvestments: traderInvestments,
                        columnWidths: self.$columnWidths,
                        onDeleteInvestment: self.onDeleteInvestment,
                        onShowStatusInfo: self.onShowStatusInfo,
                        onShowAmountInfo: self.onShowAmountInfo
                    )
                }
            }
        }
    }
}

struct InvestmentsCompletedSectionView: View {
    let titleStripeIndex: Int
    @Environment(\.appServices) private var services
    @Binding var selectedTimePeriod: InvestmentTimePeriod
    let allCompletedCount: Int
    let completedInvestmentsByTimePeriod: [Investment]
    let completedInvestmentDocRefs: [String: (docNumber: String?, invoiceNumber: String?)]
    let traderDataService: any TraderDataServiceProtocol
    let completedInvestmentSummaries: [String: InvestorInvestmentStatementSummary]
    let completedCanonicalSummaries: [String: ServerInvestmentCanonicalSummary]
    let onTimePeriodChanged: (InvestmentTimePeriod) -> Void
    let onShowDetails: (Investment) -> Void

    @State private var isExpanded = false
    @State private var currentPage = 0
    @State private var sortOrder: ListSortOrder = .newestFirst
    @State private var outcomeFilter: CompletedInvestmentOutcomeFilter = .all

    private let pageSize = ClientSideListPagination.defaultPageSize

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            self.sectionTitleBlock
                .stripedListSection(stripeIndex: self.titleStripeIndex)

            if self.isExpanded, !self.displayItems.isEmpty {
                CompletedInvestmentsTable(
                    investments: self.pagedItems,
                    investmentDocRefs: self.completedInvestmentDocRefs,
                    traderDataService: self.traderDataService,
                    investmentSummaries: self.completedInvestmentSummaries,
                    canonicalSummaries: self.completedCanonicalSummaries,
                    monetaryServerOnly: self.services.configurationService.investorMonetaryServerOnly,
                    onShowDetails: self.onShowDetails
                )
                .investmentsTableShell()

                if self.usesPagination {
                    ListPaginationBar(
                        page: self.currentPage,
                        pageSize: self.pageSize,
                        total: self.displayItems.count,
                        itemLabel: "Investments",
                        onPageChange: { self.currentPage = $0 }
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onChange(of: self.selectedTimePeriod) { _, _ in self.resetPagination() }
        .onChange(of: self.sortOrder) { _, _ in self.resetPagination() }
        .onChange(of: self.outcomeFilter) { _, _ in self.resetPagination() }
        .onChange(of: self.displayItems.count) { _, newCount in
            self.clampPage(for: newCount)
        }
    }

    private var displayItems: [Investment] {
        var items = self.completedInvestmentsByTimePeriod
        switch self.outcomeFilter {
        case .all:
            break
        case .completedOnly:
            items = items.filter { $0.status == .completed }
        case .cancelledOnly:
            items = items.filter { $0.status == .cancelled }
        }

        return items.sorted { first, second in
            let firstDate = first.completedAt ?? first.updatedAt
            let secondDate = second.completedAt ?? second.updatedAt
            return self.sortOrder == .newestFirst ? firstDate > secondDate : firstDate < secondDate
        }
    }

    private var pagedItems: [Investment] {
        if self.usesPagination {
            return ClientSideListPagination.slice(self.displayItems, page: self.currentPage, pageSize: self.pageSize)
        }
        return self.displayItems
    }

    private var usesPagination: Bool {
        ClientSideListPagination.shouldPaginate(total: self.displayItems.count)
    }

    private var sectionTitleBlock: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            CollapsibleListSectionHeader(
                title: "Completed Investments",
                itemCount: self.displayItems.count,
                isExpanded: self.$isExpanded
            )

            if self.isExpanded {
                self.filtersBlock

                if self.displayItems.isEmpty {
                    self.emptyState
                } else if self.usesPagination {
                    Text("\(self.displayItems.count) Investments (gefiltert)")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.tertiaryText)
                }
            }
        }
    }

    private var filtersBlock: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            ListSectionFilterMenu(
                label: "Zeitraum",
                value: self.selectedTimePeriod.displayName,
                options: InvestmentTimePeriod.allCases.map { ($0.displayName, $0.displayName) }.map { (id: $0.0, title: $0.1) }
            ) { selectedName in
                guard let period = InvestmentTimePeriod.allCases.first(where: { $0.displayName == selectedName }) else { return }
                self.selectedTimePeriod = period
                self.onTimePeriodChanged(period)
            }

            ListSectionFilterMenu(
                label: "Status",
                value: self.outcomeFilter.displayName,
                options: CompletedInvestmentOutcomeFilter.allCases.map { (id: $0.rawValue, title: $0.displayName) }
            ) { selectedId in
                guard let filter = CompletedInvestmentOutcomeFilter(rawValue: selectedId) else { return }
                self.outcomeFilter = filter
            }

            ListSectionFilterMenu(
                label: "Sortierung",
                value: self.sortOrder.displayName,
                options: ListSortOrder.allCases.map { (id: $0.rawValue, title: $0.displayName) }
            ) { selectedId in
                guard let order = ListSortOrder(rawValue: selectedId) else { return }
                self.sortOrder = order
            }
        }
    }

    private func resetPagination() {
        self.currentPage = 0
    }

    private func clampPage(for total: Int) {
        let maxPage = ClientSideListPagination.totalPages(total: total, pageSize: self.pageSize) - 1
        if self.currentPage > maxPage {
            self.currentPage = max(0, maxPage)
        }
    }

    private var emptyState: some View {
        VStack(spacing: ResponsiveDesign.spacing(8)) {
            if self.allCompletedCount == 0 {
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

                    Text("Total completed: \(self.allCompletedCount)")
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(AppTheme.tertiaryText)

                    Text("Try selecting a different time period")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.quaternaryText)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, ResponsiveDesign.spacing(16))
    }
}
