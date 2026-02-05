import XCTest
@testable import FIN1

final class InvestorPortfolioViewModelDITests: XCTestCase {
    func testReconfigureWithServicesKeepsPoolServiceAndMapsPoolProfit() {
        // Arrange services
        let userService = MockUserService()
        userService.currentUser = User(
            id: "investorX",
            customerId: "CUSTX",
            accountType: .individual,
            email: "investor@test.com",
            username: "investor",
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

        let investmentService = MockInvestmentService()
        let poolService = MockPoolTradeParticipationService()

        // One investment, 2 completed pools
        let invId = "INV1"
        let pool1 = PoolReservation(id: "P1", poolNumber: 1, status: .completed, actualPoolId: nil, allocatedAmount: 1000, reservedAt: Date(), isLocked: true)
        let pool2 = PoolReservation(id: "P2", poolNumber: 2, status: .completed, actualPoolId: nil, allocatedAmount: 1000, reservedAt: Date(), isLocked: true)
        investmentService.investments = [
            Investment(id: invId, investorId: userService.currentUser?.id ?? "default", traderId: "T1", traderName: "Trader", amount: 3000, currentValue: 3000, date: Date(), status: .active, performance: 0, numberOfTrades: 0, numberOfPools: 3, createdAt: Date(), updatedAt: Date(), completedAt: nil, specialization: "", reservedPoolSlots: [pool1, pool2, PoolReservation(id: "P3", poolNumber: 3, status: .reserved, actualPoolId: nil, allocatedAmount: 1000, reservedAt: Date(), isLocked: false)])
        ]

        // Profits for completed pools
        poolService.participations = [
            PoolTradeParticipation(tradeId: "T1", investmentId: invId, poolReservationId: "P1", poolNumber: 1, allocatedAmount: 1000, totalTradeValue: 1000, ownershipPercentage: 1.0, profitShare: -30.55),
            PoolTradeParticipation(tradeId: "T2", investmentId: invId, poolReservationId: "P2", poolNumber: 2, allocatedAmount: 1000, totalTradeValue: 1000, ownershipPercentage: 1.0, profitShare: 788.58)
        ]

        // ViewModel
        let viewModel = InvestorPortfolioViewModel(
            userService: userService,
            investmentService: investmentService,
            investorCashBalanceService: nil,
            poolTradeParticipationService: poolService
        )

        // Force-load
        viewModel.investments = investmentService.investments

        // Act
        let rows = viewModel.ongoingPoolRows

        // Assert: both completed pools present with profit values
        let pool1Row = rows.first { $0.reservation.id == "P1" }
        let pool2Row = rows.first { $0.reservation.id == "P2" }
        XCTAssertNotNil(pool1Row)
        XCTAssertNotNil(pool2Row)
        XCTAssertEqual(pool1Row??.profit, -30.55, accuracy: 0.01)
        XCTAssertEqual(pool2Row??.profit, 788.58, accuracy: 0.01)
    }
}
