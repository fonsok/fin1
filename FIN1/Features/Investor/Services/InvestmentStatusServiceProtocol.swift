import Foundation

// MARK: - Investment Status Service Protocol
/// Coordinates investment status transitions (reserved → active → completed) using the pool lifecycle service and repository.
@MainActor
protocol InvestmentStatusServiceProtocol: AnyObject {
    func markInvestmentAsActive(
        for traderId: String,
        repository: any InvestmentRepositoryProtocol,
        investmentPoolLifecycleService: (any InvestmentPoolLifecycleServiceProtocol)?,
        telemetryService: (any TelemetryServiceProtocol)?
    ) -> Investment?

    func markInvestmentAsCompleted(
        for traderId: String,
        repository: any InvestmentRepositoryProtocol,
        investmentPoolLifecycleService: (any InvestmentPoolLifecycleServiceProtocol)?,
        telemetryService: (any TelemetryServiceProtocol)?
    ) -> (Investment, InvestmentReservation)?

    func markNextInvestmentAsActive(
        for investmentId: String,
        repository: any InvestmentRepositoryProtocol,
        investmentPoolLifecycleService: (any InvestmentPoolLifecycleServiceProtocol)?
    ) -> Investment?

    func markActiveInvestmentAsCompleted(
        for investmentId: String,
        repository: any InvestmentRepositoryProtocol,
        investmentPoolLifecycleService: (any InvestmentPoolLifecycleServiceProtocol)?
    ) -> (Investment, InvestmentReservation)?

    func deleteInvestment(
        investmentId: String,
        repository: any InvestmentRepositoryProtocol
    ) -> Bool
}
