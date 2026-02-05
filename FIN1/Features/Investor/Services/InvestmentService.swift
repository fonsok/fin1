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

    // Backend sync (optional - for persistence across devices)
    private var investmentAPIService: (any InvestmentAPIServiceProtocol)?
    private var pendingSyncIds: Set<String> = [] // Track investments not yet synced

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
        commissionCalculationService: (any CommissionCalculationServiceProtocol)? = nil,
        investmentAPIService: (any InvestmentAPIServiceProtocol)? = nil
    ) {
        self.repository = repository ?? InvestmentRepository()
        self.queryService = queryService ?? InvestmentQueryService()
        // Ensure configurationService is available for InvestmentCreationService
        guard let configService = configurationService else {
            fatalError("ConfigurationService must be provided to InvestmentService")
        }
        self.creationService = creationService ?? InvestmentCreationService(
            investorCashBalanceService: investorCashBalanceService,
            investmentManagementService: investmentManagementService,
            investmentDocumentService: investmentDocumentService,
            documentService: documentService,
            invoiceService: invoiceService,
            bankContraAccountService: bankContraAccountService,
            transactionIdService: transactionIdService ?? TransactionIdService(),
            configurationService: configService
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
        self.investmentAPIService = investmentAPIService
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
        // Capture current investment IDs before creation
        let existingIds = await MainActor.run { Set(repository.investments.map(\.id)) }

        // Create investments locally
        try await creationService.createInvestment(
            investor: investor,
            trader: trader,
            amountPerInvestment: amountPerInvestment,
            numberOfInvestments: numberOfInvestments,
            specialization: specialization,
            potSelection: potSelection,
            repository: repository
        )

        // Mark new investments for backend sync
        let newIds = await MainActor.run {
            repository.investments.map(\.id).filter { !existingIds.contains($0) }
        }
        for id in newIds {
            markForSync(id)
        }

        // Write-through: Sync immediately in background (fire-and-forget)
        if !newIds.isEmpty, investmentAPIService != nil {
            Task.detached(priority: .background) { [weak self] in
                await self?.syncToBackend()
            }
        }
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

    // MARK: - Backend Sync (Efficient, Lazy)

    /// Syncs pending investments to backend in batch (called on app background)
    func syncToBackend() async {
        guard let apiService = investmentAPIService, !pendingSyncIds.isEmpty else { return }

        let idsToSync = pendingSyncIds
        print("📡 InvestmentService: Syncing \(idsToSync.count) investments to backend...")

        let investmentsToSync = await MainActor.run {
            repository.investments.filter { idsToSync.contains($0.id) }
        }

        for investment in investmentsToSync {
            do {
                _ = try await apiService.saveInvestment(investment)
                await MainActor.run { pendingSyncIds.remove(investment.id) }
            } catch {
                print("⚠️ InvestmentService: Failed to sync investment \(investment.id): \(error)")
            }
        }

        print("✅ InvestmentService: Sync complete, \(pendingSyncIds.count) pending")
    }

    /// Fetches investments from backend (on-demand, merges with local)
    func fetchFromBackend(for investorId: String) async {
        guard let apiService = investmentAPIService else { return }

        do {
            let remoteInvestments = try await apiService.fetchInvestments(for: investorId)
            await MainActor.run {
                // Merge: Add remote investments not in local
                let localIds = Set(repository.investments.map(\.id))
                let newInvestments = remoteInvestments.filter { !localIds.contains($0.id) }
                for investment in newInvestments {
                    repository.addInvestment(investment)
                }
            }
            print("📡 InvestmentService: Merged \(remoteInvestments.count) from backend")
        } catch {
            print("⚠️ InvestmentService: Backend fetch failed: \(error)")
        }
    }

    /// Marks an investment for sync (called after local creation)
    func markForSync(_ investmentId: String) {
        pendingSyncIds.insert(investmentId)
    }
}
