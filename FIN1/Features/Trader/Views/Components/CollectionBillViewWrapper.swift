import SwiftUI

// MARK: - Collection Bill View Wrapper
/// Wrapper that properly manages ViewModel lifecycle with @StateObject
struct CollectionBillViewWrapper: View {
    let trade: TradeOverviewItem
    let document: Document?
    /// When the bill is opened before `TradeLifecycleService` has this trade in memory (Parse fetch in document flow).
    let fullTrade: Trade?
    /// True when opened from official Beleg snapshot — detail view for structured comparison.
    let isInvoiceComparisonMode: Bool
    let belegSnapshotText: String?
    @StateObject private var viewModel: TradeStatementViewModel
    @Environment(\.appServices) private var services

    init(
        trade: TradeOverviewItem,
        document: Document? = nil,
        fullTrade: Trade? = nil,
        isInvoiceComparisonMode: Bool = false,
        belegSnapshotText: String? = nil
    ) {
        self.trade = trade
        self.document = document
        self.fullTrade = fullTrade
        self.isInvoiceComparisonMode = isInvoiceComparisonMode
        self.belegSnapshotText = belegSnapshotText
        self._viewModel = StateObject(wrappedValue: TradeStatementViewModel(trade: trade))
    }

    private var comparisonNavigationTitle: String? {
        guard self.isInvoiceComparisonMode, let document else { return nil }
        return "\(document.traderBelegNavigationTitle) (Detail)"
    }

    private var statementPresentationScope: TradeStatementPresentationScope {
        guard let document else { return .fullTrade }
        switch document.traderBelegExecutionSide {
        case .buy:
            return .buyLegOnly
        case .sell:
            return .sellLegOnly(matchingBelegNumber: document.accountingDocumentNumber)
        case .none:
            return .fullTrade
        }
    }

    var body: some View {
        TradeStatementView(
            viewModel: self.viewModel,
            showCustomBackButton: true,
            isInvoiceComparisonMode: self.isInvoiceComparisonMode,
            comparisonNavigationTitle: self.comparisonNavigationTitle
        )
        .task {
            let belegNumber = self.document?.accountingDocumentNumber
                ?? self.document?.documentNumber
            self.viewModel.documentNumber = belegNumber

            if self.isInvoiceComparisonMode {
                let metadata = await self.resolveBelegMetadata()
                if let metadata, metadata.isUsableForDisplay {
                    self.viewModel.attachBelegMetadataSSOT(
                        tradeService: self.services.tradeLifecycleService,
                        metadata: metadata,
                        prefetchedFullTrade: self.fullTrade,
                        belegNumber: belegNumber,
                        sourceCollectionBillDocument: self.document,
                        snapshotTextForDrift: self.belegSnapshotText
                    )
                    return
                }
                if self.services.configurationService.blocksLocalInvoiceGeneration {
                    self.viewModel.attachBelegMetadataUnavailable(
                        tradeService: self.services.tradeLifecycleService,
                        belegNumber: belegNumber
                    )
                    return
                }
            }

            if let fullTrade = self.fullTrade {
                try? await self.services.invoiceService.loadInvoices(for: fullTrade.traderId)
                if !self.isInvoiceComparisonMode,
                   !self.services.configurationService.blocksLocalInvoiceGeneration {
                    await self.services.invoiceService.generateInvoicesForCompletedTrades([fullTrade])
                }
            } else if let uid = self.document?.userId, !uid.isEmpty {
                try? await self.services.invoiceService.loadInvoices(for: uid)
            }
            self.viewModel.attach(
                invoiceService: self.services.invoiceService,
                tradeService: self.services.tradeLifecycleService,
                prefetchedFullTrade: self.fullTrade,
                presentationScope: self.statementPresentationScope,
                sourceCollectionBillDocument: self.document,
                sourceBelegSnapshotText: self.belegSnapshotText,
                blocksInvoiceSynthesis: self.services.configurationService.blocksLocalInvoiceGeneration
            )
            self.viewModel.refreshDisplayData()
        }
    }

    private func resolveBelegMetadata() async -> TraderCollectionBillBelegMetadata? {
        if let meta = self.document?.traderCollectionBillMetadata, meta.isUsableForDisplay {
            return meta
        }
        guard let objectId = self.document?.id else { return nil }
        do {
            let enriched = try await self.services.documentService.fetchTraderBelegDetailEnriched(objectId: objectId)
            if let meta = enriched.traderCollectionBillMetadata, meta.isUsableForDisplay {
                return meta
            }
        } catch {
            print("⚠️ CollectionBillViewWrapper: metadata enrichment failed: \(error.localizedDescription)")
        }
        return nil
    }
}
