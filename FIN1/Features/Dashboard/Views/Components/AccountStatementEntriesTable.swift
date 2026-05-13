import SwiftUI

struct AccountStatementEntriesTable<TopContent: View>: View {
    private let entries: [AccountStatementEntry]
    private let dividerColor: Color
    private let showDocumentReferenceLinks: Bool
    private let topContent: TopContent?
    private let onEntryTap: ((AccountStatementEntry) -> Void)?

    init(
        entries: [AccountStatementEntry],
        dividerColor: Color = Color.white.opacity(0.08),
        showDocumentReferenceLinks: Bool = true,
        onEntryTap: ((AccountStatementEntry) -> Void)? = nil,
        @ViewBuilder topContent: () -> TopContent
    ) {
        self.entries = entries
        self.dividerColor = dividerColor
        self.showDocumentReferenceLinks = showDocumentReferenceLinks
        self.onEntryTap = onEntryTap
        self.topContent = topContent()
    }

    init(
        entries: [AccountStatementEntry],
        dividerColor: Color = Color.white.opacity(0.08),
        showDocumentReferenceLinks: Bool = true,
        onEntryTap: ((AccountStatementEntry) -> Void)? = nil
    ) where TopContent == EmptyView {
        self.entries = entries
        self.dividerColor = dividerColor
        self.showDocumentReferenceLinks = showDocumentReferenceLinks
        self.onEntryTap = onEntryTap
        self.topContent = nil
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            VStack(spacing: ResponsiveDesign.spacing(0)) {
                if let topContent {
                    topContent
                }

                self.tableHeader

                ForEach(Array(self.entries.enumerated()), id: \.element.id) { index, entry in
                    self.tableRow(entry)
                    if index < self.entries.count - 1 {
                        Divider()
                            .background(self.dividerColor)
                    }
                }
            }
            .frame(minWidth: AccountStatementTableLayout.totalTableWidth, alignment: .leading)
            .background(AppTheme.sectionBackground.opacity(0.25))
            .cornerRadius(ResponsiveDesign.spacing(12))
            .overlay(
                RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(12))
                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
            )
        }
        .scrollTargetBehavior(.viewAligned)
    }

    private var tableHeader: some View {
        HStack(spacing: AccountStatementTableLayout.columnSpacing) {
            self.stackedHeaderColumn(title: "Posting", subtitle: "date")
                .frame(width: AccountStatementTableLayout.postingDateColumnWidth, alignment: .leading)

            self.stackedHeaderColumn(title: "Value", subtitle: "date")
                .frame(width: AccountStatementTableLayout.valueDateColumnWidth, alignment: .leading)

            Text("Description")
                .frame(width: AccountStatementTableLayout.descriptionColumnWidth, alignment: .leading)

            Text("Withdrawals")
                .frame(width: AccountStatementTableLayout.amountColumnWidth, alignment: .trailing)

            Text("Deposits")
                .frame(width: AccountStatementTableLayout.amountColumnWidth, alignment: .trailing)

            Text("Balance")
                .frame(width: AccountStatementTableLayout.amountColumnWidth, alignment: .trailing)
        }
        .font(ResponsiveDesign.captionFont())
        .fontWeight(.medium)
        .foregroundColor(AppTheme.fontColor.opacity(0.7))
        .padding(.horizontal, AccountStatementTableLayout.tableHorizontalPadding)
        .padding(.vertical, ResponsiveDesign.spacing(6))
        .background(AppTheme.sectionBackground.opacity(0.4))
    }

    private func tableRow(_ entry: AccountStatementEntry) -> some View {
        HStack(spacing: AccountStatementTableLayout.columnSpacing) {
            self.postingDateColumn(for: entry)
            self.valueDateColumn(for: entry)

            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(2)) {
                Text(entry.descriptionTitle)
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor)

                if let subtitle = entry.descriptionSubtitle {
                    Text(subtitle)
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.7))
                        .multilineTextAlignment(.leading)
                }

                if self.showDocumentReferenceLinks,
                   entry.hasDocumentReference,
                   let docNo = entry.resolvedReferenceDocumentNumber,
                   !docNo.isEmpty {
                    Text("Belegnr.: \(docNo)")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.accentLightBlue)
                        .underline()
                        .multilineTextAlignment(.leading)
                }
            }
            .frame(width: AccountStatementTableLayout.descriptionColumnWidth, alignment: .leading)

            Text(self.withdrawalText(for: entry))
                .frame(width: AccountStatementTableLayout.amountColumnWidth, alignment: .trailing)
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.accentRed)

            HStack(spacing: ResponsiveDesign.spacing(4)) {
                Spacer()
                Text(self.depositText(for: entry))
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.accentGreen)

                // Show info icon for profit distribution with calculation breakdown
                if entry.category == .profitDistribution,
                   let principalReturnStr = entry.metadata["principalReturn"],
                   let grossProfitStr = entry.metadata["grossProfit"],
                   let principalReturn = Double(principalReturnStr),
                   let grossProfit = Double(grossProfitStr) {
                    ProfitDistributionInfoIcon(
                        principalReturn: principalReturn,
                        grossProfit: grossProfit,
                        totalAmount: entry.amount
                    )
                }
            }
            .frame(width: AccountStatementTableLayout.amountColumnWidth, alignment: .trailing)

            Text(self.balanceText(for: entry))
                .frame(width: AccountStatementTableLayout.amountColumnWidth, alignment: .trailing)
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor)

            if self.showDocumentReferenceLinks, entry.hasDocumentReference {
                Image(systemName: "chevron.right")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.6))
            }
        }
        .padding(.horizontal, AccountStatementTableLayout.tableHorizontalPadding)
        .padding(.vertical, ResponsiveDesign.spacing(6))
        .contentShape(Rectangle())
        .onTapGesture {
            guard self.showDocumentReferenceLinks, entry.hasDocumentReference else { return }
            self.onEntryTap?(entry)
        }
    }

    private func postingDateColumn(for entry: AccountStatementEntry) -> some View {
        self.dateColumnView(
            topLine: self.formattedDayMonth(entry.postingDate),
            bottomLine: self.formattedYear(entry.postingDate)
        )
        .frame(width: AccountStatementTableLayout.postingDateColumnWidth, alignment: .leading)
    }

    private func valueDateColumn(for entry: AccountStatementEntry) -> some View {
        self.dateColumnView(
            topLine: self.formattedDayMonth(entry.valueDateOrPosting),
            bottomLine: self.formattedYear(entry.valueDateOrPosting)
        )
        .frame(width: AccountStatementTableLayout.valueDateColumnWidth, alignment: .leading)
    }

    private func dateColumnView(topLine: String, bottomLine: String) -> some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(2)) {
            Text(topLine)
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor)

            Text(bottomLine)
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.8))
        }
    }

    private func stackedHeaderColumn(title: String, subtitle: String) -> some View {
        Text("\(title)\n\(subtitle)")
            .font(ResponsiveDesign.captionFont())
            .fontWeight(.medium)
            .foregroundColor(AppTheme.fontColor.opacity(0.7))
            .multilineTextAlignment(.leading)
            .lineSpacing(ResponsiveDesign.spacing(2))
    }

    private func withdrawalText(for entry: AccountStatementEntry) -> String {
        guard entry.direction == .debit else { return "—" }
        return entry.amount.formattedAsLocalizedCurrency()
    }

    private func depositText(for entry: AccountStatementEntry) -> String {
        guard entry.direction == .credit else { return "—" }
        return entry.amount.formattedAsLocalizedCurrency()
    }

    private func balanceText(for entry: AccountStatementEntry) -> String {
        guard let balance = entry.balanceAfter else { return "—" }
        return balance.formattedAsLocalizedCurrency()
    }

    private func formattedDayMonth(_ date: Date) -> String {
        let formatter = AccountStatementTableLayout.dayMonthFormatter
        return formatter.string(from: date)
    }

    private func formattedYear(_ date: Date) -> String {
        let formatter = AccountStatementTableLayout.yearFormatter
        return formatter.string(from: date)
    }
}

@MainActor
enum AccountStatementTableLayout {
    static var postingDateColumnWidth: CGFloat { ResponsiveDesign.spacing(90) }
    static var valueDateColumnWidth: CGFloat { ResponsiveDesign.spacing(90) }
    static var combinedDateColumnWidth: CGFloat {
        postingDateColumnWidth + valueDateColumnWidth + columnSpacing
    }
    static var descriptionColumnWidth: CGFloat { ResponsiveDesign.spacing(220) }
    static var amountColumnWidth: CGFloat { ResponsiveDesign.spacing(110) }
    static var tableHorizontalPadding: CGFloat { ResponsiveDesign.spacing(12) }
    static var columnSpacing: CGFloat { ResponsiveDesign.spacing(12) }
    static var totalTableWidth: CGFloat {
        postingDateColumnWidth
            + valueDateColumnWidth
            + descriptionColumnWidth
            + (amountColumnWidth * 3)
            + (columnSpacing * 5)
            + (tableHorizontalPadding * 2)
    }

    static let dayMonthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "dd.MM."
        return formatter
    }()

    static let yearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy"
        return formatter
    }()
}

// MARK: - Profit Distribution Info Icon

struct ProfitDistributionInfoIcon: View {
    let principalReturn: Double
    let grossProfit: Double
    let totalAmount: Double
    @State private var showCalculation = false

    var body: some View {
        Button(action: {
            self.showCalculation.toggle()
        }) {
            Image(systemName: "info.circle")
                .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.spacing(12)))
                .foregroundColor(.blue.opacity(0.7))
        }
        .buttonStyle(PlainButtonStyle())
        .popover(isPresented: self.$showCalculation, arrowEdge: .top) {
            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
                Text("Calculation Breakdown")
                    .font(ResponsiveDesign.bodyFont())
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.fontColor)

                Divider()
                    .background(Color.white.opacity(0.2))

                VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
                    self.calculationRow(
                        label: "Principal Return",
                        amount: self.principalReturn
                    )
                    self.calculationRow(
                        label: "Gross Profit",
                        amount: self.grossProfit
                    )

                    Divider()
                        .background(Color.white.opacity(0.2))
                        .padding(.vertical, ResponsiveDesign.spacing(2))

                    self.calculationRow(
                        label: "Total Amount",
                        amount: self.totalAmount,
                        isTotal: true
                    )
                }
            }
            .padding(ResponsiveDesign.spacing(12))
            .background(AppTheme.sectionBackground)
            .cornerRadius(ResponsiveDesign.spacing(8))
            .frame(width: ResponsiveDesign.spacing(220))
        }
    }

    private func calculationRow(label: String, amount: Double, isTotal: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(isTotal ? ResponsiveDesign.bodyFont().weight(.semibold) : ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(isTotal ? 1.0 : 0.8))

            Spacer()

            Text(amount.formattedAsLocalizedCurrency())
                .font(isTotal ? ResponsiveDesign.bodyFont().weight(.semibold) : ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.accentGreen)
        }
    }
}
