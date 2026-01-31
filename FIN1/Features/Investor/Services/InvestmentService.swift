import Foundation
import SwiftUI
import Combine

// MARK: - Investment Service Implementation
/// Handles investment operations, investment management, and portfolio operations
/// Delegates to focused helper services for specific functionality
final class InvestmentService: InvestmentServiceProtocol, ServiceLifecycle {

    // MARK: - Published Properties (delegated to repository)
    var investments: [Investment] {
        repository.investments
    }
    var investmentPools: [InvestmentPool] {
        repository.investmentPools
    }
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false

    // Publisher for investments (MVVM-friendly) - delegated to repository
    var investmentsPublisher: AnyPublisher<[Investment], Never> {
        repository.investmentsPublisher
    }

    /// Per-investor filtered publisher to prevent cross-user coupling in subscribers
    func investmentsPublisher(for investorId: String) -> AnyPublisher<[Investment], Never> {
        repository.investmentsPublisher(for: investorId)
    }

    // MARK: - Dependencies
    private let repository: any InvestmentRepositoryProtocol
    private let queryService: any InvestmentQueryServiceProtocol
    private let creationService: any InvestmentCreationServiceProtocol
    private let investorCashBalanceService: (any InvestorCashBalanceServiceProtocol)?
    private let poolTradeParticipationService: (any PoolTradeParticipationServiceProtocol)?
    private let telemetryService: (any TelemetryServiceProtocol)?
    private let documentService: (any DocumentServiceProtocol)?
    private let investmentManagementService: (any InvestmentManagementServiceProtocol)?
    private let investmentCompletionService: (any InvestmentCompletionServiceProtocol)?
    private let investmentDocumentService: (any InvestmentDocumentServiceProtocol)?
    private let configurationService: (any ConfigurationServiceProtocol)?
    private var investorGrossProfitService: (any InvestorGrossProfitServiceProtocol)?
    private var commissionCalculationService: (any CommissionCalculationServiceProtocol)?

    // MARK: - Initialization

    init(
        repository: (any InvestmentRepositoryProtocol)? = nil,
        queryService: (any InvestmentQueryServiceProtocol)? = nil,
        creationService: (any InvestmentCreationServiceProtocol)? = nil,
        investorCashBalanceService: (any InvestorCashBalanceServiceProtocol)? = nil,
        bankContraAccountService: (any BankContraAccountPostingServiceProtocol)? = nil,
        poolTradeParticipationService: (any PoolTradeParticipationServiceProtocol)? = nil,
        telemetryService: (any TelemetryServiceProtocol)? = nil,
        documentService: (any DocumentServiceProtocol)? = nil,
        investmentManagementService: (any InvestmentManagementServiceProtocol)? = nil,
        investmentCompletionService: (any InvestmentCompletionServiceProtocol)? = nil,
        investmentDocumentService: (any InvestmentDocumentServiceProtocol)? = nil,
        invoiceService: (any InvoiceServiceProtocol)? = nil,
        transactionIdService: (any TransactionIdServiceProtocol)? = nil,
        configurationService: (any ConfigurationServiceProtocol)? = nil,
        investorGrossProfitService: (any InvestorGrossProfitServiceProtocol)? = nil,
        commissionCalculationService: (any CommissionCalculationServiceProtocol)? = nil
    ) {
        self.repository = repository ?? InvestmentRepository()
        self.queryService = queryService ?? InvestmentQueryService()
        self.creationService = creationService ?? InvestmentCreationService(
            investorCashBalanceService: investorCashBalanceService,
            investmentManagementService: investmentManagementService,
            investmentDocumentService: investmentDocumentService,
            documentService: documentService,
            invoiceService: invoiceService,
            bankContraAccountService: bankContraAccountService,
            transactionIdService: transactionIdService ?? TransactionIdService()
        )
        self.investorCashBalanceService = investorCashBalanceService
        self.poolTradeParticipationService = poolTradeParticipationService
        self.telemetryService = telemetryService
        self.documentService = documentService
        self.investmentManagementService = investmentManagementService
        self.investmentCompletionService = investmentCompletionService
        self.investmentDocumentService = investmentDocumentService
        self.configurationService = configurationService
        self.investorGrossProfitService = investorGrossProfitService
        self.commissionCalculationService = commissionCalculationService
    }

    // MARK: - Post-Initialization Configuration

    func configureCalculationServices(
        investorGrossProfitService: (any InvestorGrossProfitServiceProtocol)?,
        commissionCalculationService: (any CommissionCalculationServiceProtocol)?
    ) {
        self.investorGrossProfitService = investorGrossProfitService
        self.commissionCalculationService = commissionCalculationService
    }

    // MARK: - ServiceLifecycle

    func start() {
        Task {
            if let investmentDocumentService = investmentDocumentService {
                await investmentDocumentService.regenerateInvestmentDocuments(for: repository.investments)
            }
        }
    }

    func stop() { /* noop */ }

    func reset() {
        repository.investments.removeAll()
        repository.investmentPools.removeAll()
        if let investmentManagementService = investmentManagementService as? InvestmentManagementService {
            repository.investmentPools = investmentManagementService.investmentPools
        }
    }

    // MARK: - Investment Selection (Round-Robin)

    func selectNextInvestmentForTrader(_ traderId: String) async -> Investment? {
        await MainActor.run {
            investmentManagementService?.selectNextInvestmentForTrader(traderId, in: repository.investments)
        }
    }

    func selectNextInvestmentForInvestor(_ investorId: String, traderId: String) async -> Investment? {
        await MainActor.run {
            investmentManagementService?.selectNextInvestmentForInvestor(investorId, traderId: traderId, in: repository.investments)
        }
    }

    // MARK: - Investment Creation

    func createInvestment(
        investor: User,
        trader: MockTrader,
        amountPerInvestment: Double,
        numberOfInvestments: Int,
        specialization: String,
        potSelection: InvestmentSelectionStrategy
    ) async throws {
        try await creationService.createInvestment(
            investor: investor,
            trader: trader,
            amountPerInvestment: amountPerInvestment,
            numberOfInvestments: numberOfInvestments,
            specialization: specialization,
            potSelection: potSelection,
            repository: repository
        )
    }

    // MARK: - Investment Queries

    func getInvestments(for investorId: String) -> [Investment] {
        queryService.getInvestments(for: investorId, in: repository.investments)
    }

    func getInvestments(forTrader traderId: String) -> [Investment] {
        queryService.getInvestments(forTrader: traderId, in: repository.investments)
    }

    func getInvestmentPools(forTrader traderId: String) -> [InvestmentPool] {
        queryService.getInvestmentPools(
            forTrader: traderId,
            in: repository.investmentPools,
            investmentManagementService: investmentManagementService
        )
    }

    func getGroupedInvestmentsBySequence(forTrader traderId: String) -> [Int: [Investment]] {
        queryService.getGroupedInvestmentsBySequence(
            forTrader: traderId,
            in: repository.investments,
            investmentManagementService: investmentManagementService
        )
    }

    // MARK: - Investment Status Management

    func markInvestmentAsActive(for traderId: String) async {
        await MainActor.run {
            _ = InvestmentStatusManager.markInvestmentAsActive(
                for: traderId,
                repository: repository,
                investmentManagementService: investmentManagementService,
                telemetryService: telemetryService
            )
        }
    }

    func markInvestmentAsCompleted(for traderId: String) async {
        let cashDistributionValues: (Investment, InvestmentReservation)? = await MainActor.run {
            InvestmentStatusManager.markInvestmentAsCompleted(
                for: traderId,
                repository: repository,
                investmentManagementService: investmentManagementService,
                telemetryService: telemetryService
            )
        }

        // Trigger completion check
        Task { await checkAndUpdateInvestmentCompletion() }

        // Distribute cash if applicable
        if let (investment, reservation) = cashDistributionValues {
            await distributeCashForCompletion(investment: investment, reservation: reservation)
        }
    }

    func markNextInvestmentAsActive(for investmentId: String) async {
        await MainActor.run {
            _ = InvestmentStatusManager.markNextInvestmentAsActive(
                for: investmentId,
                repository: repository,
                investmentManagementService: investmentManagementService
            )
        }
    }

    func markActiveInvestmentAsCompleted(for investmentId: String) async {
        let cashDistributionValues: (Investment, InvestmentReservation)? = await MainActor.run {
            InvestmentStatusManager.markActiveInvestmentAsCompleted(
                for: investmentId,
                repository: repository,
                investmentManagementService: investmentManagementService
            )
        }

        if let (investment, reservation) = cashDistributionValues {
            await distributeCashForCompletion(investment: investment, reservation: reservation)
            await generateCompletionDocument(for: investment)
        }

        await checkAndUpdateInvestmentCompletion(for: [investmentId])
    }

    func deleteInvestment(investmentId: String, reservationId: String) async {
        let deleted = await MainActor.run {
            InvestmentStatusManager.deleteInvestment(investmentId: investmentId, repository: repository)
        }

        if deleted {
            await checkAndUpdateInvestmentCompletion()
        }
    }

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

    // MARK: - Private Helpers

    private func distributeCashForCompletion(investment: Investment, reservation: InvestmentReservation) async {
        if let investmentCompletionService = investmentCompletionService {
            await investmentCompletionService.distributeInvestmentCompletionCash(
                investment: investment,
                investmentReservation: reservation
            )
        } else {
            print("⚠️ InvestmentService: investmentCompletionService unavailable - cash distribution skipped for investment \(investment.id)")
        }
    }

    private func generateCompletionDocument(for investment: Investment) async {
        if let investmentDocumentService = investmentDocumentService {
            print("📄 InvestmentService: Generating investor Collection Bill for investment \(investment.id)")
            await investmentDocumentService.generateInvestmentDocument(for: investment)
        } else {
            print("⚠️ InvestmentService: investmentDocumentService is nil - investor Collection Bill not generated")
        }
    }
}
