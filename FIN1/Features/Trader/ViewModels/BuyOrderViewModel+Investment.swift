import Combine
import Foundation

extension BuyOrderViewModel {

    @MainActor
    func calculateInvestmentOrder() async {
        let price = Double(searchResult.askPrice.replacingOccurrences(of: ",", with: ".")) ?? 0.0
        let desiredQuantity = Int(self.effectiveQuantityForCalculation)

        guard let currentUser = userService.currentUser,
              currentUser.role == .trader else {
            investmentOrderCalculation = nil
            showInvestmentCalculation = false
            return
        }

        guard let result = await investmentCalculator.calculateInvestmentOrder(
            quantity: desiredQuantity,
            price: price,
            searchResult: searchResult,
            userService: userService,
            investmentService: investmentService,
            cashBalanceService: cashBalanceService,
            investmentQuantityCalculationService: investmentQuantityCalculationService
        ) else {
            investmentOrderCalculation = nil
            showInvestmentCalculation = false
            return
        }

        await MainActor.run {
            investmentOrderCalculation = result.calculation
            isInvestmentLimited = result.isInvestmentLimited
            showInvestmentCalculation = result.showInvestmentCalculation
        }
    }

    var totalInvestmentAmount: Double {
        reservedInvestments.reduce(0.0) { $0 + $1.amount }
    }

    func updateReservedInvestments() {
        let currentUser = userService.currentUser
        let traderId = investmentDataProvider.findTraderIdForMatching(currentUser: currentUser)
        reservedInvestments = investmentDataProvider.fetchReservedInvestments(
            traderId: traderId,
            currentUser: currentUser
        )
    }

    func refreshInvestments() {
        self.updateReservedInvestments()
    }

    /// Loads trader pool investments from Parse before buy UI / placement guards run.
    /// Concurrent callers await the same in-flight fetch (e.g. `.task` + Kaufen).
    func refreshInvestmentsFromBackend(force: Bool = false) async {
        guard let currentUser = userService.currentUser, currentUser.role == .trader else {
            self.refreshInvestments()
            return
        }

        if !force, let inFlight = poolInvestmentsRefreshTask {
            await inFlight.value
            self.updateReservedInvestments()
            return
        }

        let task = Task { @MainActor [investmentService] in
            await investmentService.fetchFromBackendForTrader(user: currentUser)
        }
        self.poolInvestmentsRefreshTask = task
        await task.value
        self.poolInvestmentsRefreshTask = nil

        self.updateReservedInvestments()
    }

    var totalInvestmentQuantity: Int {
        TotalInvestmentQuantityCalculator.calculate(
            investments: reservedInvestments,
            askPrice: searchResult.askPrice,
            denomination: searchResult.denomination
        )
    }

    func setupInvestmentObservation() {
        investmentService.investmentsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.updateReservedInvestments()
                guard !self.isPlacementLocked else { return }
                self.investmentCalculationTask?.cancel()
                self.investmentCalculationTask = Task { @MainActor [weak self] in
                    await self?.calculateInvestmentOrder()
                }
            }
            .store(in: &cancellables)

        self.updateReservedInvestments()
    }
}
