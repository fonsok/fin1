import Foundation
import SwiftUI
import UIKit

// MARK: - Collection Bill Document ViewModel

/// ViewModel for resolving and loading Collection Bill documents
/// Extracts service logic from CollectionBillDocumentView per MVVM principles
@MainActor
final class CollectionBillDocumentViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published private(set) var trade: TradeOverviewItem?
    @Published private(set) var investment: Investment?
    @Published private(set) var investorPreviewImage: UIImage?
    @Published private(set) var investorPDFData: Data?
    @Published private(set) var isLoading = true
    @Published private(set) var errorMessage: String?
    @Published private(set) var fallbackToDocumentViewer = false

    // MARK: - Dependencies

    let document: Document
    private let tradeLifecycleService: any TradeLifecycleServiceProtocol
    private let tradingStatisticsService: any TradingStatisticsServiceProtocol
    private let investmentService: any InvestmentServiceProtocol
    private let poolTradeParticipationService: any PoolTradeParticipationServiceProtocol
    private let invoiceService: any InvoiceServiceProtocol
    private let configurationService: any ConfigurationServiceProtocol
    private let settlementAPIService: (any SettlementAPIServiceProtocol)?

    // MARK: - Initialization

    init(
        document: Document,
        tradeLifecycleService: any TradeLifecycleServiceProtocol,
        tradingStatisticsService: any TradingStatisticsServiceProtocol,
        investmentService: any InvestmentServiceProtocol,
        poolTradeParticipationService: any PoolTradeParticipationServiceProtocol,
        invoiceService: any InvoiceServiceProtocol,
        configurationService: any ConfigurationServiceProtocol,
        settlementAPIService: (any SettlementAPIServiceProtocol)? = nil
    ) {
        self.document = document
        self.tradeLifecycleService = tradeLifecycleService
        self.tradingStatisticsService = tradingStatisticsService
        self.investmentService = investmentService
        self.poolTradeParticipationService = poolTradeParticipationService
        self.invoiceService = invoiceService
        self.configurationService = configurationService
        self.settlementAPIService = settlementAPIService
    }

    /// Convenience initializer using AppServices
    convenience init(document: Document, services: AppServices) {
        self.init(
            document: document,
            tradeLifecycleService: services.tradeLifecycleService,
            tradingStatisticsService: services.tradingStatisticsService,
            investmentService: services.investmentService,
            poolTradeParticipationService: services.poolTradeParticipationService,
            invoiceService: services.invoiceService,
            configurationService: services.configurationService,
            settlementAPIService: services.settlementAPIService
        )
    }

    // MARK: - Service Accessors for View

    func createInvestorStatementViewModel() -> InvestorInvestmentStatementViewModel? {
        guard let investment = investment else { return nil }
        let viewModel = InvestorInvestmentStatementViewModel(
            investment: investment,
            poolTradeParticipationService: poolTradeParticipationService,
            tradeService: tradeLifecycleService,
            invoiceService: invoiceService,
            configurationService: configurationService,
            settlementAPIService: settlementAPIService
        )
        viewModel.documentNumber = document.accountingDocumentNumber
        return viewModel
    }

    // MARK: - Public Methods

    func loadTargetFromDocument() async {
        print("🔍 CollectionBillDocumentViewModel: Loading target from document '\(document.name)'")

        var resolved = false

        switch document.type {
        case .traderCollectionBill:
            resolved = await resolveTradeTarget()
        case .investorCollectionBill:
            resolved = await resolveInvestmentTarget()
            if !resolved {
                await generateInvestorPreviewFallback()
                return
            }
        default:
            resolved = false
        }

        if !resolved {
            print("❌ CollectionBillDocumentViewModel: Failed to resolve document target for '\(document.name)'")
            errorMessage = "Could not extract trade or investment information from document metadata"
            fallbackToDocumentViewer = true
            isLoading = false
        }
    }

    // MARK: - Trade Loading

    private func resolveTradeTarget() async -> Bool {
        let completedTrades = tradeLifecycleService.completedTrades

        if let tradeId = document.tradeId,
           let foundById = completedTrades.first(where: { $0.id == tradeId }) {
            await publishTrade(foundById)
            return true
        }

        if let tradeNumber = extractTradeNumberFromDocumentName(document.name),
           let foundByNumber = completedTrades.first(where: { $0.tradeNumber == tradeNumber }) {
            await publishTrade(foundByNumber)
            return true
        }

        print("❌ CollectionBillDocumentViewModel: Unable to resolve trade information for document '\(document.name)'")
        return false
    }

    private func publishTrade(_ foundTrade: Trade) async {
        print("✅ CollectionBillDocumentViewModel: Found trade: ID=\(foundTrade.id), Number=\(foundTrade.tradeNumber)")

        let grossProfit = tradingStatisticsService.calculateGrossProfit(for: foundTrade)
        let totalFees = tradingStatisticsService.calculateTotalFees(for: foundTrade)

        let tradeOverview = TradeOverviewItem(
            tradeId: foundTrade.id,
            tradeNumber: foundTrade.tradeNumber,
            startDate: foundTrade.createdAt,
            endDate: foundTrade.completedAt ?? foundTrade.updatedAt,
            profitLoss: foundTrade.currentPnL ?? 0,
            returnPercentage: 0,
            commission: 0,
            isActive: foundTrade.isActive,
            statusText: foundTrade.status.rawValue,
            statusDetail: "",
            onDetailsTapped: {},
            grossProfit: grossProfit,
            totalFees: totalFees
        )

        trade = tradeOverview
        isLoading = false
    }

    // MARK: - Investment Loading

    private func loadInvestment(withId investmentId: String) async -> Bool {
        print("🔍 CollectionBillDocumentViewModel: Resolving investment '\(investmentId)' for user '\(document.userId)'")

        // Prefer investments for the specific investor first
        let investorInvestments = investmentService.getInvestments(for: document.userId)
        let allInvestments = investmentService.investments

        let resolvedInvestment = investorInvestments.first(where: { $0.id == investmentId }) ??
            allInvestments.first(where: { $0.id == investmentId })

        guard let foundInvestment = resolvedInvestment else {
            print("❌ Investment '\(investmentId)' not found for user '\(document.userId)'")
            errorMessage = "Investment \(investmentId) not found"
            isLoading = false
            return false
        }

        print("✅ Found investment: ID=\(foundInvestment.id), Investor=\(foundInvestment.investorId)")

        investment = foundInvestment
        isLoading = false

        return true
    }

    private func resolveInvestmentTarget() async -> Bool {
        if let investmentId = document.investmentId {
            return await loadInvestment(withId: investmentId)
        }

        if let parsedId = extractInvestmentIdFromDocumentName(document.name) {
            return await loadInvestment(withId: parsedId)
        }

        print("❌ CollectionBillDocumentViewModel: Unable to resolve investment id for document '\(document.name)'")
        return false
    }

    private func generateInvestorPreviewFallback() async {
        print("ℹ️ CollectionBillDocumentViewModel: Generating investor preview fallback for '\(document.name)'")
        let previewImage = InvestorCollectionBillPDFGenerator.generatePreviewImage(for: document)
        let pdfData = InvestorCollectionBillPDFGenerator.generatePDFData(for: document)

        investorPreviewImage = previewImage
        investorPDFData = pdfData
        isLoading = false
    }

    // MARK: - Name Parsing Helpers

    private func extractTradeNumberFromDocumentName(_ name: String) -> Int? {
        // Extract trade number from "CollectionBill_Trade1_20251024_Z2CBXA7T.pdf" format
        let pattern = #"Trade(\d+)"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: name, range: NSRange(name.startIndex..., in: name)),
           let range = Range(match.range(at: 1), in: name) {
            return Int(String(name[range]))
        }
        return nil
    }

    private func extractInvestmentIdFromDocumentName(_ name: String) -> String? {
        // Extract investment ID from "CollectionBill_Investment{InvestmentId}_{YYYYMMDD}_{Hash8}.pdf"
        let pattern = #"Investment([^_]+)"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: name, range: NSRange(name.startIndex..., in: name)),
           let range = Range(match.range(at: 1), in: name) {
            return String(name[range])
        }
        return nil
    }
}
