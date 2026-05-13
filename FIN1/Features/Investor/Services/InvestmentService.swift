import Combine
import Foundation
import SwiftUI

// MARK: - Investment Service Implementation
/// Handles investment operations, pool lifecycle coordination, and investment overview
/// Delegates to focused helper services for specific functionality
final class InvestmentService: InvestmentServiceProtocol, ServiceLifecycle, @unchecked Sendable {

    // MARK: - Published Properties (delegated to repository)
    var investments: [Investment] {
        self.repository.investments
    }
    var investmentPools: [InvestmentPool] {
        self.repository.investmentPools
    }
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false

    // Publisher for investments (MVVM-friendly) - delegated to repository
    var investmentsPublisher: AnyPublisher<[Investment], Never> {
        self.repository.investmentsPublisher
    }

    /// Per-investor filtered publisher to prevent cross-user coupling in subscribers
    func investmentsPublisher(for investorId: String) -> AnyPublisher<[Investment], Never> {
        self.repository.investmentsPublisher(for: investorId)
    }

    // MARK: - Dependencies
    let repository: any InvestmentRepositoryProtocol
    let queryService: any InvestmentQueryServiceProtocol
    let creationService: any InvestmentCreationServiceProtocol
    let investorCashBalanceService: (any InvestorCashBalanceServiceProtocol)?
    let poolTradeParticipationService: (any PoolTradeParticipationServiceProtocol)?
    let telemetryService: (any TelemetryServiceProtocol)?
    let documentService: (any DocumentServiceProtocol)?
    let investmentPoolLifecycleService: (any InvestmentPoolLifecycleServiceProtocol)?
    let investmentStatusService: any InvestmentStatusServiceProtocol
    let investmentCompletionService: (any InvestmentCompletionServiceProtocol)?
    let investmentDocumentService: (any InvestmentDocumentServiceProtocol)?
    let configurationService: any ConfigurationServiceProtocol
    var investorGrossProfitService: (any InvestorGrossProfitServiceProtocol)?
    var commissionCalculationService: (any CommissionCalculationServiceProtocol)?

    // Backend sync (optional - for persistence across devices)
    var investmentAPIService: (any InvestmentAPIServiceProtocol)?
    var pendingSyncIds: Set<String> = [] // Track investments not yet synced

    // MARK: - Initialization

    init(
        repository: (any InvestmentRepositoryProtocol)? = nil,
        queryService: (any InvestmentQueryServiceProtocol)? = nil,
        creationService: any InvestmentCreationServiceProtocol,
        investorCashBalanceService: (any InvestorCashBalanceServiceProtocol)? = nil,
        poolTradeParticipationService: (any PoolTradeParticipationServiceProtocol)? = nil,
        telemetryService: (any TelemetryServiceProtocol)? = nil,
        documentService: (any DocumentServiceProtocol)? = nil,
        investmentPoolLifecycleService: (any InvestmentPoolLifecycleServiceProtocol)? = nil,
        investmentStatusService: any InvestmentStatusServiceProtocol,
        investmentCompletionService: (any InvestmentCompletionServiceProtocol)? = nil,
        investmentDocumentService: (any InvestmentDocumentServiceProtocol)? = nil,
        configurationService: any ConfigurationServiceProtocol,
        investorGrossProfitService: (any InvestorGrossProfitServiceProtocol)? = nil,
        commissionCalculationService: (any CommissionCalculationServiceProtocol)? = nil,
        investmentAPIService: (any InvestmentAPIServiceProtocol)? = nil
    ) {
        self.repository = repository ?? InvestmentRepository()
        self.queryService = queryService ?? InvestmentQueryService()
        self.creationService = creationService
        self.investorCashBalanceService = investorCashBalanceService
        self.poolTradeParticipationService = poolTradeParticipationService
        self.telemetryService = telemetryService
        self.documentService = documentService
        self.investmentPoolLifecycleService = investmentPoolLifecycleService
        self.investmentStatusService = investmentStatusService
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
            // Sync investment status from backend (picks up completed/cancelled states)
            if let userId = repository.investments.first?.investorId {
                await fetchFromBackend(for: userId)
            }
            if let investmentDocumentService = investmentDocumentService {
                await investmentDocumentService.regenerateInvestmentDocuments(for: self.repository.investments)
            }
        }
    }

    func stop() { /* noop */ }

    func reset() {
        self.repository.investments.removeAll()
        self.repository.investmentPools.removeAll()
        if let investmentPoolLifecycleService = investmentPoolLifecycleService as? InvestmentPoolLifecycleService {
            self.repository.investmentPools = investmentPoolLifecycleService.investmentPools
        }
    }

    // MARK: - Investment Selection (Round-Robin)

    func selectNextInvestmentForTrader(_ traderId: String) async -> Investment? {
        await MainActor.run {
            self.investmentPoolLifecycleService?.selectNextInvestmentForTrader(traderId, in: self.repository.investments)
        }
    }

    func selectNextInvestmentForInvestor(_ investorId: String, traderId: String) async -> Investment? {
        await MainActor.run {
            self.investmentPoolLifecycleService?.selectNextInvestmentForInvestor(
                investorId,
                traderId: traderId,
                in: self.repository.investments
            )
        }
    }

    // MARK: - Investment Queries

    func getInvestments(for investorId: String) -> [Investment] {
        self.queryService.getInvestments(for: investorId, in: self.repository.investments)
    }

    func getInvestments(forTrader traderId: String) -> [Investment] {
        self.queryService.getInvestments(forTrader: traderId, in: self.repository.investments)
    }

    func getInvestmentPools(forTrader traderId: String) -> [InvestmentPool] {
        self.queryService.getInvestmentPools(
            forTrader: traderId,
            in: self.repository.investmentPools,
            investmentPoolLifecycleService: self.investmentPoolLifecycleService
        )
    }

    func getGroupedInvestmentsBySequence(forTrader traderId: String) -> [Int: [Investment]] {
        self.queryService.getGroupedInvestmentsBySequence(
            forTrader: traderId,
            in: self.repository.investments,
            investmentPoolLifecycleService: self.investmentPoolLifecycleService
        )
    }
}
