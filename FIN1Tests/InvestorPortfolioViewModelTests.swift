import XCTest
@testable import FIN1

final class InvestorPortfolioViewModelTests: XCTestCase {
    func testTotalsAreComputed() {
        // Arrange
        let user = User(
            id: "investor1",
            customerId: "C1",
            accountType: .individual,
            email: "investor@test.com",
            username: "investor1",
            phoneNumber: "",
            password: "",
            salutation: .mr,
            academicTitle: "",
            firstName: "",
            lastName: "",
            streetAndNumber: "",
            postalCode: "",
            city: "",
            state: "",
            country: "",
            dateOfBirth: Date(),
            placeOfBirth: "",
            countryOfBirth: "",
            role: .investor,
            employmentStatus: .employed,
            income: 0,
            incomeRange: .low,
            riskTolerance: 3,
            address: "",
            nationality: "",
            additionalNationalities: "",
            taxNumber: "",
            additionalTaxResidences: "",
            isNotUSCitizen: true,
            identificationType: .passport,
            passportFrontImageURL: nil,
            passportBackImageURL: nil,
            idCardFrontImageURL: nil,
            idCardBackImageURL: nil,
            identificationConfirmed: true,
            addressConfirmed: true,
            addressVerificationDocumentURL: nil,
            leveragedProductsExperience: false,
            financialProductsExperience: false,
            investmentExperience: 0,
            tradingFrequency: 0,
            investmentKnowledge: 0,
            desiredReturn: .atLeastTenPercent,
            insiderTradingOptions: [:],
            moneyLaunderingDeclaration: true,
            assetType: .privateAssets,
            profileImageURL: nil,
            isEmailVerified: true,
            isKYCCompleted: true,
            acceptedTerms: true,
            acceptedPrivacyPolicy: true,
            acceptedMarketingConsent: true,
            lastLoginDate: Date(),
            createdAt: Date(),
            updatedAt: Date()
        )

        let fakeUser = MockUserService()
        fakeUser.currentUser = user

        let fakeInv = MockInvestmentService()

        fakeInv.investments = [
            Investment(id: "1", investorId: "investor1", traderId: "t1", traderName: "t1", amount: 1000, currentValue: 1200, date: Date(), status: .active, performance: 20, numberOfTrades: 1, numberOfPools: 1, createdAt: Date(), updatedAt: Date(), completedAt: nil, specialization: "", reservedPoolSlots: []),
            Investment(id: "2", investorId: "investor1", traderId: "t2", traderName: "t2", amount: 500, currentValue: 400, date: Date(), status: .active, performance: -20, numberOfTrades: 1, numberOfPools: 1, createdAt: Date(), updatedAt: Date(), completedAt: nil, specialization: "", reservedPoolSlots: [])
        ]

        let mockPoolService = MockPoolTradeParticipationService()
        let vm = InvestorPortfolioViewModel(
            userService: fakeUser,
            investmentService: fakeInv,
            investorCashBalanceService: nil,
            poolTradeParticipationService: mockPoolService
        )
        // Inject investments from the service into the VM (mirrors a loaded state)
        vm.investments = fakeInv.getInvestments(for: "investor1")

        // Act
        _ = vm.totalPortfolioValue
        _ = vm.totalInvestedAmount

        // Assert
        XCTAssertEqual(vm.totalInvestedAmount, 1500)
        XCTAssertEqual(vm.totalPortfolioValue, 1600)
        XCTAssertEqual(vm.isPositivePnL, true)
    }
}
