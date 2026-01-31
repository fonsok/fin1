import XCTest
@testable import FIN1

final class InvestmentCompletionTests: XCTestCase {
    func testDeletionLeadsToCancelledWhenNoCompletedPools() async {
        let service = InvestmentService()

        // Create a user and trader
        let user = User(
            id: "user:test@investor.com",
            customerId: "FIN1-TEST",
            accountType: .individual,
            email: "test@investor.com",
            username: "investor",
            phoneNumber: "",
            password: "",
            salutation: .mr,
            academicTitle: "",
            firstName: "Test",
            lastName: "Investor",
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
            incomeRange: .middle,
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
            financialProductsExperience: true,
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
            lastLoginDate: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        let trader = MockTrader(
            name: "Thomas Trader",
            username: "trader1",
            specialization: "Tech",
            experienceYears: 5,
            isVerified: true,
            performance: 0,
            totalTrades: 0,
            winRate: 0,
            averageReturn: 0,
            totalReturn: 0,
            riskLevel: .medium,
            recentTrades: [],
            lastNTrades: 0,
            successfulTradesInLastN: 0,
            averageReturnLastNTrades: 0,
            consecutiveWinningTrades: 0,
            maxDrawdown: 0,
            sharpeRatio: 0
        )

        // Create investment with 2 pots and delete both reserved pots
        try? await service.createInvestment(
            investor: user,
            trader: trader,
            amountPerPool: 1000,
            numberOfPools: 2,
            specialization: "Tech",
            poolSelection: .multiplePools
        )
        guard let inv = service.investments.first else {
            return XCTFail("Missing investment")
        }
        for res in inv.reservedPoolSlots {
            await service.deleteInvestment(investmentId: inv.id, reservationId: res.id)
        }

        // Assert cancelled (no completed pots existed)
        guard let updated = service.investments.first(where: { $0.id == inv.id }) else {
            return XCTFail("Missing updated investment")
        }
        XCTAssertEqual(updated.status, .cancelled)
    }

    func testPartialAppearsWhenOnePoolCompleted() async {
        let service = InvestmentService()
        let user = User(
            id: "user:test2@investor.com",
            customerId: "FIN1-TEST2",
            accountType: .individual,
            email: "test2@investor.com",
            username: "investor2",
            phoneNumber: "",
            password: "",
            salutation: .mr,
            academicTitle: "",
            firstName: "Test",
            lastName: "Investor",
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
            incomeRange: .middle,
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
            financialProductsExperience: true,
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
            lastLoginDate: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        let trader = MockTrader(
            name: "Thomas Trader",
            username: "trader1",
            specialization: "Tech",
            experienceYears: 5,
            isVerified: true,
            performance: 0,
            totalTrades: 0,
            winRate: 0,
            averageReturn: 0,
            totalReturn: 0,
            riskLevel: .medium,
            recentTrades: [],
            lastNTrades: 0,
            successfulTradesInLastN: 0,
            averageReturnLastNTrades: 0,
            consecutiveWinningTrades: 0,
            maxDrawdown: 0,
            sharpeRatio: 0
        )
        try? await service.createInvestment(
            investor: user,
            trader: trader,
            amountPerPool: 1000,
            numberOfPools: 2,
            specialization: "Tech",
            poolSelection: .multiplePools
        )
        guard let inv = service.investments.first else {
            return XCTFail("Missing investment")
        }
        // Activate and complete one pool
        await service.markNextPoolAsActive(for: inv.id)
        await service.markActivePoolAsCompleted(for: inv.id)
        guard let updated = service.investments.first(where: { $0.id == inv.id }) else {
            return XCTFail("Missing updated investment")
        }
        // Should remain active but have a completed pool
        XCTAssertEqual(updated.status, .active)
        XCTAssertTrue(updated.reservedPoolSlots.contains { $0.status == .completed })
    }
}
