import Foundation
import Combine

@MainActor
extension TradesOverviewViewModel {
    func attach(
        orderService: any OrderManagementServiceProtocol,
        tradeService: any TradeLifecycleServiceProtocol,
        statisticsService: any TradingStatisticsServiceProtocol,
        invoiceService: any InvoiceServiceProtocol,
        configurationService: any ConfigurationServiceProtocol,
        poolTradeParticipationService: (any PoolTradeParticipationServiceProtocol)? = nil,
        commissionCalculationService: (any CommissionCalculationServiceProtocol)? = nil,
        investorGrossProfitService: (any InvestorGrossProfitServiceProtocol)? = nil,
        userService: (any UserServiceProtocol)? = nil,
        parseLiveQueryClient: (any ParseLiveQueryClientProtocol)? = nil
    ) {
        guard self.orderService == nil && self.tradeService == nil && self.statisticsService == nil && self.invoiceService == nil && self.configurationService == nil else { return }
        self.orderService = orderService
        self.tradeService = tradeService
        self.statisticsService = statisticsService
        self.invoiceService = invoiceService
        self.configurationService = configurationService
        self.userService = userService
        self.parseLiveQueryClient = parseLiveQueryClient

        self.commissionCalculator = TradesOverviewCommissionCalculator(
            invoiceService: invoiceService,
            tradeService: tradeService,
            poolTradeParticipationService: poolTradeParticipationService,
            commissionCalculationService: commissionCalculationService,
            configurationService: configurationService
        )

        orderService.activeOrdersPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.rebuildTrades()
                }
            }
            .store(in: &cancellables)

        tradeService.completedTradesPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.rebuildTrades()
                }
            }
            .store(in: &cancellables)

        Task {
            await subscribeToLiveUpdates()
        }

        NotificationCenter.default.publisher(for: .invoiceDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                if let invoiceType = notification.userInfo?["invoiceType"] as? String,
                   invoiceType == InvoiceType.creditNote.rawValue {
                    print("📄 TradesOverviewViewModel: Credit note added - refreshing trades to update commission")
                    Task { @MainActor [weak self] in
                        await self?.rebuildTrades()
                    }
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .userDataDidUpdate)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                print("🔄 TradesOverviewViewModel: User data updated - reloading trades")
                Task { @MainActor [weak self] in
                    await self?.rebuildTrades()
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSNotification.Name("UserRoleChanged"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                print("🔄 TradesOverviewViewModel: Role changed - reloading trades")
                Task { @MainActor [weak self] in
                    await self?.rebuildTrades()
                }
            }
            .store(in: &cancellables)

        Task { @MainActor [weak self] in
            await self?.rebuildTrades()
        }
    }
}
