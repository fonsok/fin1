@testable import FIN1
import XCTest

@MainActor
final class InvestmentFormViewModelTests: XCTestCase {

    private func makeConfigurationService() -> ConfigurationService {
        ConfigurationService(userService: MockUserService())
    }

    func testFormatAndValidateInputDoesNotReemitUnchangedBackingAmount() {
        var backing = "3000"
        let viewModel = InvestmentFormViewModel(
            updateInvestmentAmount: { backing = $0 },
            getInvestmentAmount: { backing },
            configurationService: self.makeConfigurationService()
        )

        viewModel.updateDisplayFromAmount()
        let initialDisplay = viewModel.displayAmount
        XCTAssertFalse(initialDisplay.isEmpty)

        var updateCount = 0
        let trackingVM = InvestmentFormViewModel(
            updateInvestmentAmount: { _ in updateCount += 1 },
            getInvestmentAmount: { backing },
            configurationService: self.makeConfigurationService()
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
            configurationService: self.makeConfigurationService()
        )

        viewModel.formatAndValidateInput("3000")
        let displayAfterFormat = viewModel.displayAmount

        viewModel.updateDisplayFromAmount()
        XCTAssertEqual(viewModel.displayAmount, displayAfterFormat)
    }
}
