import Combine
import Foundation

extension BuyOrderViewModel {

    @MainActor
    func calculateInvestmentOrder() async {
        let price = Double(searchResult.askPrice.replacingOccurrences(of: ",", with: ".")) ?? 0.0
        let desiredQuantity = Int(quantity)

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
                self?.updateReservedInvestments()
            }
            .store(in: &cancellables)

        self.updateReservedInvestments()
        [0.1, 0.5, 1.0].forEach { delay in
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.updateReservedInvestments()
            }
        }
    }
}
