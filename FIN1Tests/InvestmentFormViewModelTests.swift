@testable import FIN1
import XCTest

@MainActor
final class InvestmentFormViewModelTests: XCTestCase {

    private final class MockConfigurationService: ConfigurationServiceProtocol {
        var maximumInvestmentAmount: Double = 100_000
        var minimumInvestmentAmount: Double = 20
        var appServiceChargePercentage: String = "2,00%"
        var traderCommissionPercentage: Double = 0
        var effectiveAppServiceChargeRate: Double = 0.02

        func refreshConfigurationFromServerIfAvailable() async {}
        func getMinimumCashReserve(for userId: String) -> Double { 0 }
    }

    func testFormatAndValidateInputDoesNotReemitUnchangedBackingAmount() {
        var backing = "3000"
        let viewModel = InvestmentFormViewModel(
            updateInvestmentAmount: { backing = $0 },
            getInvestmentAmount: { backing },
            configurationService: MockConfigurationService()
        )

        viewModel.updateDisplayFromAmount()
        let initialDisplay = viewModel.displayAmount
        XCTAssertFalse(initialDisplay.isEmpty)

        var updateCount = 0
        let trackingVM = InvestmentFormViewModel(
            updateInvestmentAmount: { _ in updateCount += 1 },
            getInvestmentAmount: { backing },
            configurationService: MockConfigurationService()
        )
        trackingVM.updateDisplayFromAmount()
        updateCount = 0

        trackingVM.formatAndValidateInput(initialDisplay)
        XCTAssertEqual(updateCount, 0, "Identical formatted input should not re-write backing amount")
    }

    func testUpdateDisplayFromAmountSkipsWhenBackingMatchesLastEmitted() {
        var backing = "3000"
        let viewModel = InvestmentFormViewModel(
            updateInvestmentAmount: { backing = $0 },
            getInvestmentAmount: { backing },
            configurationService: MockConfigurationService()
        )

        viewModel.formatAndValidateInput("3000")
        let displayAfterFormat = viewModel.displayAmount

        viewModel.updateDisplayFromAmount()
        XCTAssertEqual(viewModel.displayAmount, displayAfterFormat)
    }
}
