import Foundation
import SwiftUI
import UIKit

// MARK: - Collection Bill Document ViewModel

/// ViewModel for resolving and loading Collection Bill documents
/// Extracts service logic from CollectionBillDocumentView per MVVM principles
@MainActor
final class CollectionBillDocumentViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var trade: TradeOverviewItem?
    /// Full `Trade` used to build `trade` (may not be present in `TradeLifecycleService.completedTrades` yet).
    @Published var resolvedFullTrade: Trade?
    @Published var investment: Investment?
    @Published var investorPreviewImage: UIImage?
    @Published var investorPDFData: Data?
    @Published var isLoading = true
    @Published var errorMessage: String?
    @Published var fallbackToDocumentViewer = false

    // MARK: - Dependencies

    let document: Document
    /// Canonical row from local document store (full metadata after sync); same id as notification payload.
    var canonicalDocument: Document?
    let tradeLifecycleService: any TradeLifecycleServiceProtocol
    let tradingStatisticsService: any TradingStatisticsServiceProtocol
    let investmentService: any InvestmentServiceProtocol
    let poolTradeParticipationService: any PoolTradeParticipationServiceProtocol
    let documentService: any DocumentServiceProtocol
    let invoiceService: any InvoiceServiceProtocol
    let userService: any UserServiceProtocol
    let configurationService: any ConfigurationServiceProtocol
    let settlementAPIService: (any SettlementAPIServiceProtocol)?
    let parseAPIClient: (any ParseAPIClientProtocol)?

    // MARK: - Initialization

    init(
        document: Document,
        tradeLifecycleService: any TradeLifecycleServiceProtocol,
        tradingStatisticsService: any TradingStatisticsServiceProtocol,
        investmentService: any InvestmentServiceProtocol,
        poolTradeParticipationService: any PoolTradeParticipationServiceProtocol,
        documentService: any DocumentServiceProtocol,
        invoiceService: any InvoiceServiceProtocol,
        userService: any UserServiceProtocol,
        configurationService: any ConfigurationServiceProtocol,
        settlementAPIService: (any SettlementAPIServiceProtocol)? = nil,
        parseAPIClient: (any ParseAPIClientProtocol)? = nil
    ) {
        self.document = document
        self.tradeLifecycleService = tradeLifecycleService
        self.tradingStatisticsService = tradingStatisticsService
        self.investmentService = investmentService
        self.poolTradeParticipationService = poolTradeParticipationService
        self.documentService = documentService
        self.invoiceService = invoiceService
        self.userService = userService
        self.configurationService = configurationService
        self.settlementAPIService = settlementAPIService
        self.parseAPIClient = parseAPIClient
    }

    /// Convenience initializer using AppServices
    convenience init(document: Document, services: AppServices) {
        self.init(
            document: document,
            tradeLifecycleService: services.tradeLifecycleService,
            tradingStatisticsService: services.tradingStatisticsService,
            investmentService: services.investmentService,
            poolTradeParticipationService: services.poolTradeParticipationService,
            documentService: services.documentService,
            invoiceService: services.invoiceService,
            userService: services.userService,
            configurationService: services.configurationService,
            settlementAPIService: services.settlementAPIService,
            parseAPIClient: services.parseAPIClient
        )
    }
}
