import SwiftUI

// MARK: - Section Components

/// Displays the ongoing trades section
struct OngoingTradesSection: View {
    let titleStripeIndex: Int
    let ongoingTrades: [TradeOverviewItem]

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(0)) {
            self.sectionTitleBlock
                .stripedListSection(stripeIndex: self.titleStripeIndex)

            if !self.ongoingTrades.isEmpty {
                self.tradeCards
            }
        }
    }

    @ViewBuilder
    private var sectionTitleBlock: some View {
        if self.ongoingTrades.isEmpty {
            VStack(spacing: ResponsiveDesign.spacing(16)) {
                Image(systemName: "clock")
                    .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize() * 2.4))
                    .foregroundColor(AppTheme.fontColor.opacity(0.5))

                Text("Keine laufenden Trades")
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.7))

                Text("Aktuell sind keine Trades aktiv")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.5))
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, ResponsiveDesign.spacing(3))
            .frame(maxWidth: .infinity)
        } else {
            Text("Laufende Trades")
                .font(ResponsiveDesign.headlineFont())
                .foregroundColor(AppTheme.accentOrange)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var tradeCards: some View {
        LazyVStack(spacing: ResponsiveDesign.spacing(12)) {
            ForEach(self.ongoingTrades) { trade in
                OngoingTradeCard(trade: trade)
            }
        }
        .padding(.horizontal, ResponsiveDesign.mainHorizontalPadding())
        .padding(.vertical, ResponsiveDesign.spacing(4))
    }
}

/// Displays the completed trades section
struct CompletedTradesSection: View {
    let titleStripeIndex: Int
    let completedTrades: [TradeOverviewItem]
    let makeTableRows: ([TradeOverviewItem]) -> [TradeTableRowData]
    let columnWidths: ColumnWidths?
    let commissionPercentage: String
    @Binding var selectedTimePeriod: TradeTimePeriod
    @Binding var showCustomizeDetails: Bool
    let onTimePeriodChanged: (TradeTimePeriod) -> Void
    @Environment(\.appServices) private var services

    @State private var isExpanded = false
    @State private var currentPage = 0
    @State private var sortOrder: ListSortOrder = .newestFirst

    private let pageSize = ClientSideListPagination.defaultPageSize

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(0)) {
            self.sectionTitleBlock
                .stripedListSection(stripeIndex: self.titleStripeIndex)

            if self.isExpanded, !self.displayTrades.isEmpty {
                self.tableContent

                if self.usesPagination {
                    ListPaginationBar(
                        page: self.currentPage,
                        pageSize: self.pageSize,
                        total: self.displayTrades.count,
                        itemLabel: "Trades",
                        onPageChange: { self.currentPage = $0 }
                    )
                }
            }
        }
        .onChange(of: self.selectedTimePeriod) { _, _ in self.resetPagination() }
        .onChange(of: self.sortOrder) { _, _ in self.resetPagination() }
        .onChange(of: self.displayTrades.count) { _, newCount in
            self.clampPage(for: newCount)
        }
    }

    private var displayTrades: [TradeOverviewItem] {
        self.completedTrades.sorted { first, second in
            self.sortOrder == .newestFirst ? first.endDate > second.endDate : first.endDate < second.endDate
        }
    }

    private var pagedTrades: [TradeOverviewItem] {
        if self.usesPagination {
            return ClientSideListPagination.slice(self.displayTrades, page: self.currentPage, pageSize: self.pageSize)
        }
        return self.displayTrades
    }

    private var usesPagination: Bool {
        ClientSideListPagination.shouldPaginate(total: self.displayTrades.count)
    }

    private var sectionTitleBlock: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            CollapsibleListSectionHeader(
                title: "Abgeschlossene Trades",
                itemCount: self.displayTrades.count,
                isExpanded: self.$isExpanded
            )

            if self.isExpanded {
                self.filtersBlock

                if self.displayTrades.isEmpty {
                    self.emptyState
                } else if self.usesPagination {
                    Text("\(self.displayTrades.count) Trades (gefiltert)")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.tertiaryText)
                }
            }
        }
    }

    private var filtersBlock: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            TradesOverviewHeaderView(
                selectedTimePeriod: self.$selectedTimePeriod,
                showCustomizeDetails: self.$showCustomizeDetails,
                onTimePeriodChanged: self.onTimePeriodChanged
            )

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

    @ViewBuilder
    private var tableContent: some View {
        if let columnWidths = columnWidths {
            TradesTable(
                trades: self.makeTableRows(self.pagedTrades),
                columnWidths: columnWidths,
                commissionPercentage: self.commissionPercentage,
                services: self.services
            )
            .padding(.horizontal, ResponsiveDesign.mainHorizontalPadding())
            .padding(.vertical, ResponsiveDesign.spacing(4))
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
        VStack(spacing: ResponsiveDesign.spacing(16)) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize() * 2.4))
                .foregroundColor(AppTheme.fontColor.opacity(0.5))

            Text("Keine abgeschlossenen Trades")
                .font(ResponsiveDesign.headlineFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))

            Text("Aktuell sind keine Trades abgeschlossen")
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.5))
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, ResponsiveDesign.spacing(32))
        .frame(maxWidth: .infinity)
    }
}

/// Card component for displaying ongoing trades
struct OngoingTradeCard: View {
    let trade: TradeOverviewItem
    @Environment(\.appServices) private var services

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
                    Text("Trade Nr.")
                        .font(ResponsiveDesign.captionFont())
                        .fontWeight(.thin)
                        .foregroundColor(AppTheme.secondaryText)

                    Text(self.trade.displayTradeNumber)
                        .font(ResponsiveDesign.headlineFont())
                        .foregroundColor(AppTheme.fontColor)
                }

                Spacer()

                Text(self.trade.statusText)
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.accentOrange)
                    .padding(.horizontal, ResponsiveDesign.spacing(8))
                    .padding(.vertical, ResponsiveDesign.spacing(4))
                    .background(AppTheme.accentOrange.opacity(0.2))
                    .cornerRadius(ResponsiveDesign.spacing(8))
            }

            // P&L and ROI removed for ongoing trades since only buy orders are done
            // These metrics are only relevant after sell orders are completed
        }
        .padding(ResponsiveDesign.spacing(16))
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
        .onTapGesture {
            self.trade.onDetailsTapped()
        }
    }
}
