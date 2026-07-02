import SwiftUI

// MARK: - Trader Collection Bill (SSOT Klartext vom Backend)

/// Zeigt `Document.accountingSummaryText` — gleiche Quelle wie Admin-Portal / `traderCollectionBillBelegSnapshot`.
struct TraderCollectionBillBelegSnapshotView: View {
    let snapshotText: String
    let document: Document
    let trade: TradeOverviewItem
    let fullTrade: Trade?
    let services: AppServices

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(16)) {
                self.headerSection
                self.belegTextSection
                self.fallbackLinkSection
            }
            .padding(ResponsiveDesign.spacing(16))
        }
        .background(DocumentDesignSystem.documentBackground)
        .navigationTitle(self.document.traderBelegNavigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AppTheme.screenBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            Text("Beleg (Buchhaltung)")
                .font(ResponsiveDesign.headlineFont())
                .foregroundColor(DocumentDesignSystem.textColor)

            if let number = document.accountingDocumentNumber ?? document.documentNumber, !number.isEmpty {
                Text(number)
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(DocumentDesignSystem.textColorSecondary)
            }

            Text("Trade #\(self.trade.formattedTradeNumber)")
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(DocumentDesignSystem.textColorSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .documentSection(level: 2)
    }

    private var belegTextSection: some View {
        Text(self.snapshotText)
            .font(ResponsiveDesign.bodyFont())
            .foregroundColor(DocumentDesignSystem.textColor)
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled)
            .documentSection(level: 3)
    }

    private var fallbackLinkSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            Text("Optional")
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(DocumentDesignSystem.textColorSecondary)

            NavigationLink {
                CollectionBillViewWrapper(
                    trade: self.trade,
                    document: self.document,
                    fullTrade: self.fullTrade,
                    isInvoiceComparisonMode: true,
                    belegSnapshotText: self.snapshotText
                )
            } label: {
                Label("Abrechnung (Detail)", systemImage: "doc.text.magnifyingglass")
                    .font(ResponsiveDesign.bodyFont())
            }
            .foregroundColor(AppTheme.accentLightBlue)

            Text("Strukturierte Detailansicht aus Server-Metadaten (GoB). Rechnung nur als Fallback.")
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(DocumentDesignSystem.textColorSecondary)
        }
        .documentSection(level: 2)
    }
}
