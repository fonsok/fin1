import Foundation

extension InvestmentService {
    // MARK: - Completion Checking

    func checkAndUpdateInvestmentCompletion(for investmentIds: [String]) async {
        await MainActor.run {
            InvestmentCompletionChecker.checkAndUpdate(
                for: investmentIds,
                repository: repository,
                investmentCompletionService: investmentCompletionService
            )
        }
    }

    func checkAndUpdateInvestmentCompletion() async {
        await MainActor.run {
            InvestmentCompletionChecker.checkAndUpdateAll(
                repository: repository,
                investmentCompletionService: investmentCompletionService
            )
        }
    }

    func updateInvestmentProfitsFromTrades() async {
        await MainActor.run {
            InvestmentCompletionChecker.updateProfitsFromTrades(
                repository: repository,
                investmentCompletionService: investmentCompletionService
            )
        }
    }

    // MARK: - Helpers

    func distributeCashForCompletion(investment: Investment, reservation: InvestmentReservation) async {
        if let investmentCompletionService = investmentCompletionService {
            await investmentCompletionService.distributeInvestmentCompletionCash(
                investment: investment,
                investmentReservation: reservation
            )
        } else {
            print("⚠️ InvestmentService: investmentCompletionService unavailable - cash distribution skipped for investment \(investment.id)")
        }
    }

    func generateCompletionDocument(for investment: Investment) async {
        if let investmentDocumentService = investmentDocumentService {
            print("📄 InvestmentService: Generating investor Collection Bill for investment \(investment.id)")
            await investmentDocumentService.generateInvestmentDocument(for: investment)
        } else {
            print("⚠️ InvestmentService: investmentDocumentService is nil - investor Collection Bill not generated")
        }
    }
}
