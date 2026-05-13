import Combine
import Foundation

// MARK: - Trade Lifecycle Service Implementation
/// Handles trade creation, completion, and management
final class TradeLifecycleService: TradeLifecycleServiceProtocol, ServiceLifecycle, @unchecked Sendable {
    static let shared = TradeLifecycleService()

    @Published var completedTrades: [Trade] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    // Track if this is the first load (app relaunch)
    private var isFirstLoad = true

    var completedTradesPublisher: AnyPublisher<[Trade], Never> {
        self.$completedTrades.eraseToAnyPublisher()
    }

    private var tradeNumberService: (any TradeNumberServiceProtocol)?
    private var tradingNotificationService: (any TradingNotificationServiceProtocol)?
    private var invoiceService: (any InvoiceServiceProtocol)?
    private var tradeAPIService: (any TradeAPIServiceProtocol)?
    private var userService: (any UserServiceProtocol)?
    private var auditLoggingService: (any AuditLoggingServiceProtocol)?

    // Notification name for API failure info overlay
    static let showAPIFailureInfoNotification = Notification.Name("TradeLifecycleService.showAPIFailureInfo")

    // MARK: - Persistence
    private let persistenceService: TradeLifecyclePersistenceService

    init(fileManager: FileManager = .default) {
        self.persistenceService = TradeLifecyclePersistenceService(fileManager: fileManager)

        // Don't load persisted trades in init() - wait for start() to try API first
        // This prevents loading old trades before we know if API is available
    }

    func attach(
        tradeNumberService: any TradeNumberServiceProtocol,
        tradingNotificationService: any TradingNotificationServiceProtocol,
        invoiceService: any InvoiceServiceProtocol,
        tradeAPIService: (any TradeAPIServiceProtocol)? = nil,
        userService: (any UserServiceProtocol)? = nil,
        auditLoggingService: (any AuditLoggingServiceProtocol)? = nil
    ) {
        self.tradeNumberService = tradeNumberService
        self.tradingNotificationService = tradingNotificationService
        self.invoiceService = invoiceService
        self.tradeAPIService = tradeAPIService
        self.userService = userService
        self.auditLoggingService = auditLoggingService
    }

    // MARK: - ServiceLifecycle
    func start() {
        // Reset first load flag on service start (app relaunch)
        self.isFirstLoad = true
        Task {
            try? await self.loadCompletedTrades()
        }
    }

    func stop() {
        // Persist trades before stopping
        self.persistenceService.persistTrades(self.completedTrades)
    }

    func reset() {
        self.completedTrades.removeAll()
        self.errorMessage = nil
        // Clear persisted trades
        self.persistenceService.clearPersistedTrades()
    }

    // MARK: - Trade Data Management

    func loadCompletedTrades() async throws {
        await MainActor.run {
            self.isLoading = true
        }

        // Load trades from Parse Server API if available
        if let tradeAPIService = tradeAPIService,
           let traderId = userService?.currentUser?.id {
            do {
                print("📡 TradeLifecycleService: Loading trades from Parse Server for trader \(traderId)")
                let fetchedTrades = try await tradeAPIService.fetchTrades(for: traderId)

                await MainActor.run {
                    // Replace existing trades with fetched trades
                    // This ensures we have the latest data from the backend
                    self.completedTrades = fetchedTrades
                    self.isLoading = false
                }

                // Drop stale on-disk trades for this trader so a later offline/API-fallback load
                // cannot resurrect rows after a DEV backend reset (persistTrades only overwrites files it writes).
                if let tid = userService?.currentUser?.id {
                    self.persistenceService.clearPersistedTradesForTrader(tid)
                }
                self.persistenceService.persistTrades(fetchedTrades)

                print("✅ TradeLifecycleService: Loaded \(fetchedTrades.count) trades from Parse Server")

                // Synchronize trade numbers from loaded trades to ensure correct numbering
                if let tradeNumberService = tradeNumberService {
                    tradeNumberService.synchronizeTradeNumbers(from: fetchedTrades)
                }

                // Verify and regenerate collection bills for completed trades
                if let tradingNotificationService = tradingNotificationService {
                    await tradingNotificationService.regenerateCollectionBills(for: fetchedTrades)
                }

                return
            } catch {
                print("⚠️ TradeLifecycleService: Failed to load trades from API: \(error)")

                // On app relaunch (first load), show info overlay, but DO NOT clear local/persisted trades.
                // Losing local history when backend is down is not acceptable.
                if self.isFirstLoad {
                    self.isFirstLoad = false
                    await MainActor.run {
                        NotificationCenter.default.post(
                            name: TradeLifecycleService.showAPIFailureInfoNotification,
                            object: nil
                        )
                    }
                }

                // Fall through to load persisted trades / keep existing trades on error
            }
        }

        // Fallback: Load persisted trades if API is unavailable or fails
        // Note: If isFirstLoad is true here, it means API service is not available at all
        // In that case, we still load persisted trades (but numbering won't be reset)
        await MainActor.run {
            // Only load persisted trades if we haven't already cleared them (i.e., not first load with API failure)
            if self.completedTrades.isEmpty {
                self.loadPersistedTradesSync()
            }

            // Synchronize trade numbers from loaded trades to ensure correct numbering
            if let tradeNumberService = tradeNumberService {
                tradeNumberService.synchronizeTradeNumbers(from: self.completedTrades)
            }

            self.isLoading = false
            self.isFirstLoad = false // Mark as no longer first load
        }

        // Verify and regenerate collection bills for completed trades
        if let tradingNotificationService = tradingNotificationService {
            await tradingNotificationService.regenerateCollectionBills(for: self.completedTrades)
        }
    }

    func refreshCompletedTrades() async throws {
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
        }

        // Try to load from API first, then fallback to persistence
        try await self.loadCompletedTrades()
    }

    // MARK: - Trade Management
    // Note: Trade is created AFTER buy order completes, not when order is placed

    func createNewTrade(buyOrder: OrderBuy) async throws -> Trade {
        // CRITICAL: Use per-trader trade numbering for proper isolation
        // Each trader has their own sequence starting from 1
        let tradeNumber = self.tradeNumberService?.generateNextTradeNumber(for: buyOrder.traderId) ?? 0
        let initialTrade = Trade.from(buyOrder: buyOrder, tradeNumber: tradeNumber)

        // Save to Parse Server if available and get updated trade (with server-assigned ID if any)
        let finalTrade: Trade
        if let tradeAPIService = tradeAPIService {
            do {
                finalTrade = try await tradeAPIService.saveTrade(initialTrade)
                print("✅ TradeLifecycleService: Trade #\(finalTrade.tradeNumber) saved to Parse Server")
            } catch {
                print("⚠️ TradeLifecycleService: Failed to save trade to Parse Server: \(error)")
                // Continue with local storage even if server save fails
                finalTrade = initialTrade
            }
        } else {
            finalTrade = initialTrade
        }

        await MainActor.run {
            self.completedTrades.append(finalTrade)
            // Persist immediately after adding trade
            self.persistenceService.persistTrades(self.completedTrades)
        }

        return finalTrade
    }

    func addSellOrderToTrade(_ tradeId: String, sellOrder: OrderSell) async throws {
        let updatedTrade: Trade? = await MainActor.run {
            if let index = completedTrades.firstIndex(where: { $0.id == tradeId }) {
                let trade = self.completedTrades[index]
                let updated = trade.with(sellOrder: sellOrder).updateStatus()
                self.completedTrades[index] = updated
                // Persist after update
                self.persistenceService.persistTrades(self.completedTrades)
                return updated
            }
            return nil
        }

        // Update on Parse Server if available
        if let trade = updatedTrade, let tradeAPIService = tradeAPIService {
            do {
                _ = try await tradeAPIService.updateTrade(trade)
                print("✅ TradeLifecycleService: Trade #\(trade.tradeNumber) updated on Parse Server (sell order added)")
            } catch {
                print("⚠️ TradeLifecycleService: Failed to update trade on Parse Server: \(error)")
            }
        }
    }

    func addPartialSellOrderToTrade(_ tradeId: String, sellOrder: OrderSell) async throws {
        let updatedTrade: Trade? = await MainActor.run {
            if let index = completedTrades.firstIndex(where: { $0.id == tradeId }) {
                let trade = self.completedTrades[index]
                let updated = trade.withPartialSellOrder(sellOrder).updateStatus()
                self.completedTrades[index] = updated
                // Persist after update
                self.persistenceService.persistTrades(self.completedTrades)
                return updated
            }
            return nil
        }

        // Update on Parse Server if available
        if let trade = updatedTrade, let tradeAPIService = tradeAPIService {
            do {
                _ = try await tradeAPIService.updateTrade(trade)
                print("✅ TradeLifecycleService: Trade #\(trade.tradeNumber) updated on Parse Server (partial sell order added)")
            } catch {
                print("⚠️ TradeLifecycleService: Failed to update trade on Parse Server: \(error)")
            }
        }
    }

    func cancelTrade(_ tradeId: String) async throws {
        let cancelledTrade: Trade? = await MainActor.run {
            if let index = completedTrades.firstIndex(where: { $0.id == tradeId }) {
                let trade = self.completedTrades[index]
                let cancelled = Trade(
                    id: trade.id,
                    tradeNumber: trade.tradeNumber,
                    traderId: trade.traderId,
                    symbol: trade.symbol,
                    description: trade.description,
                    buyOrder: trade.buyOrder,
                    sellOrder: trade.sellOrder, // Keep legacy sellOrder
                    sellOrders: trade.sellOrders, // Keep all partial sell orders
                    status: .cancelled,
                    createdAt: trade.createdAt,
                    completedAt: trade.completedAt,
                    updatedAt: Date()
                )
                self.completedTrades[index] = cancelled
                // Persist after update
                self.persistenceService.persistTrades(self.completedTrades)
                return cancelled
            }
            return nil
        }

        // Update on Parse Server if available
        if let trade = cancelledTrade, let tradeAPIService = tradeAPIService {
            do {
                _ = try await tradeAPIService.updateTrade(trade)
                print("✅ TradeLifecycleService: Trade #\(trade.tradeNumber) cancelled and updated on Parse Server")
            } catch {
                print("⚠️ TradeLifecycleService: Failed to update cancelled trade on Parse Server: \(error)")
            }
        }
    }

    func completeTrade(_ tradeId: String) async throws {
        let finalTrade: Trade? = await MainActor.run {
            guard let index = completedTrades.firstIndex(where: { $0.id == tradeId }) else {
                return nil
            }
            
            let trade = self.completedTrades[index]
            let updatedTrade = trade.updateStatus()

            // Calculate and store profit if trade is completed and we have invoice service
            let resultTrade: Trade
            if updatedTrade.isCompleted, let invoiceService = invoiceService {
                let allInvoices = invoiceService.getInvoicesForTrade(trade.id)
                let buyInvoices = allInvoices.filter { $0.transactionType == .buy }
                let sellInvoices = allInvoices.filter { $0.transactionType == .sell }
                let buyInvoice = buyInvoices.first

                let calculatedProfit = ProfitCalculationService.calculateTaxableProfit(buyInvoice: buyInvoice, sellInvoices: sellInvoices)
                resultTrade = updatedTrade.withCalculatedProfit(calculatedProfit)
            } else {
                resultTrade = updatedTrade
            }

            self.completedTrades[index] = resultTrade
            // Persist after completion
            self.persistenceService.persistTrades(self.completedTrades)
            
            return resultTrade
        }
        
        // ✅ MiFID II Compliance: Log trade completion (outside MainActor.run to avoid capture issues)
        if let trade = finalTrade,
           let auditService = auditLoggingService,
           let userId = userService?.currentUser?.id {
            let profitInfo = trade.calculatedProfit != nil
                ? "Profit: €\(trade.calculatedProfit!.formatted(.number.precision(.fractionLength(2)))))"
                : "Profit: Calculating..."

            let complianceEvent = ComplianceEvent(
                eventType: .tradeCompleted,
                agentId: userId,
                customerId: userId,
                description: "Trade #\(trade.tradeNumber) completed: \(trade.description)",
                severity: .medium,
                requiresReview: false,
                notes: "Trade ID: \(trade.id), \(profitInfo)"
            )
            Task {
                await auditService.logComplianceEvent(complianceEvent)
            }
        }

        // Generate Collection Bill document for completed trade
        if let trade = finalTrade {
            Task {
                await self.tradingNotificationService?.generateCollectionBillDocument(for: trade)
            }
        }

        // Update on Parse Server if available
        if let trade = finalTrade, let tradeAPIService = tradeAPIService {
            do {
                _ = try await tradeAPIService.updateTrade(trade)
                print("✅ TradeLifecycleService: Trade #\(trade.tradeNumber) completed and updated on Parse Server")
            } catch {
                print("⚠️ TradeLifecycleService: Failed to update completed trade on Parse Server: \(error)")
            }
        }
    }

    // MARK: - Private Methods

    private func loadMockData() {
        self.loadCompletedTradesSync()
    }

    private func loadCompletedTradesSync() {
        // Trades are now loaded from persistence when needed
        // This method kept for backward compatibility
    }

    /// Loads persisted trades synchronously (called when API is unavailable)
    private func loadPersistedTradesSync() {
        // Load persisted trades if not already loaded
        if self.completedTrades.isEmpty {
            self.persistenceService.loadPersistedTrades { [weak self] trades in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    self.completedTrades = trades

                    // Synchronize trade numbers from loaded trades
                    if let tradeNumberService = self.tradeNumberService {
                        tradeNumberService.synchronizeTradeNumbers(from: trades)
                    }
                }
            }
        }
    }

    /// Resets trade numbering for a specific trader to start at 1
    private func resetTradeNumbering(for traderId: String) {
        // Clear the trade number from UserDefaults for this trader
        // This matches the key format used in TradeNumberService
        let userDefaults = UserDefaults.standard
        let keyPrefix = "FIN1_TradeNumber_"
        let sanitizedId = traderId
            .replacingOccurrences(of: ":", with: "_")
            .replacingOccurrences(of: "@", with: "_")
            .replacingOccurrences(of: ".", with: "_")
        let key = "\(keyPrefix)user_\(sanitizedId)"

        // Reset to 0 so next trade will be #1
        userDefaults.set(0, forKey: key)
        print("🔄 TradeLifecycleService: Reset trade number counter for trader \(traderId) to 0")
    }
}
