import Foundation
import SwiftUI

// MARK: - Collection Bill By Number ViewModel

/// ViewModel for loading a trade by trade number and creating the TradeStatementViewModel
/// Extracts service logic from CollectionBillByNumberViewWrapper per MVVM principles
@MainActor
final class CollectionBillByNumberViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published private(set) var tradeStatementViewModel: TradeStatementViewModel?
    @Published private(set) var isLoading = true
    @Published private(set) var errorMessage: String?

    // MARK: - Dependencies

    let tradeNumber: Int
    private let tradeLifecycleService: any TradeLifecycleServiceProtocol
    private let tradingStatisticsService: any TradingStatisticsServiceProtocol
    private let invoiceService: any InvoiceServiceProtocol
    private let userService: (any UserServiceProtocol)?

    // MARK: - Current Trader ID
    /// Returns the current trader's ID from the user service
    private var currentTraderId: String? {
        userService?.currentUser?.id
    }

    // MARK: - Initialization

    init(
        tradeNumber: Int,
        tradeLifecycleService: any TradeLifecycleServiceProtocol,
        tradingStatisticsService: any TradingStatisticsServiceProtocol,
        invoiceService: any InvoiceServiceProtocol,
        userService: (any UserServiceProtocol)? = nil
    ) {
        self.tradeNumber = tradeNumber
        self.tradeLifecycleService = tradeLifecycleService
        self.tradingStatisticsService = tradingStatisticsService
        self.invoiceService = invoiceService
        self.userService = userService
    }

    /// Convenience initializer using AppServices
    convenience init(tradeNumber: Int, services: AppServices) {
        self.init(
            tradeNumber: tradeNumber,
            tradeLifecycleService: services.tradeLifecycleService,
            tradingStatisticsService: services.tradingStatisticsService,
            invoiceService: services.invoiceService,
            userService: services.userService
        )
    }

    // MARK: - Public Methods

    func loadTrade() async {
        print("🔍 CollectionBillByNumberViewModel: Looking for trade #\(tradeNumber)")

        // Find the trade by trade number from the trade service
        // CRITICAL: Filter by current trader ID to ensure trade isolation
        let allTrades = tradeLifecycleService.completedTrades
        let completedTrades: [Trade]
        if let traderId = currentTraderId {
            completedTrades = allTrades.filter { $0.traderId == traderId }
            print("🔍 Found \(completedTrades.count) completed trades for current trader (of \(allTrades.count) total)")
        } else {
            completedTrades = []
            print("⚠️ CollectionBillByNumberViewModel: No current trader ID - cannot find trades")
        }

        // Debug: Print all trade numbers and IDs
        for trade in completedTrades {
            print("   - Trade #\(trade.tradeNumber) (ID: \(trade.id), Status: \(trade.status.rawValue))")
        }

        if let foundTrade = completedTrades.first(where: { $0.tradeNumber == tradeNumber }) {
            print("✅ Found trade: ID=\(foundTrade.id), Number=\(foundTrade.tradeNumber)")

            // Convert Trade to TradeOverviewItem
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

            print("✅ Created TradeOverviewItem with tradeId: \(tradeOverview.tradeId ?? "NIL")")

            let viewModel = TradeStatementViewModel(trade: tradeOverview)
            viewModel.attach(invoiceService: invoiceService, tradeService: tradeLifecycleService)

            tradeStatementViewModel = viewModel
            isLoading = false
        } else {
            print("❌ Trade #\(tradeNumber) not found in completed trades")
            // List available trade numbers for debugging
            let availableNumbers = completedTrades.map { $0.tradeNumber }
            print("📋 Available trade numbers: \(availableNumbers)")
            errorMessage = "Trade #\(tradeNumber) not found"
            isLoading = false
        }
    }

    func refreshDisplayData() {
        tradeStatementViewModel?.refreshDisplayData()
    }
}











