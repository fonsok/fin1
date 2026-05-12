import Foundation
@testable import FIN1

// MARK: - Mock Investment Status Service
/// Test double for `InvestmentStatusServiceProtocol`. Defaults are inert (`nil` / `false`); set handlers or return properties to drive behavior.
@MainActor
final class MockInvestmentStatusService: InvestmentStatusServiceProtocol {

    // MARK: - markInvestmentAsActive

    private(set) var markInvestmentAsActiveCallCount = 0
    var lastMarkActiveTraderId: String?
    /// Used when `markInvestmentAsActiveHandler` is nil.
    var markInvestmentAsActiveReturn: Investment?
    var markInvestmentAsActiveHandler: (
        (String, any InvestmentRepositoryProtocol, (any InvestmentPoolLifecycleServiceProtocol)?, (any TelemetryServiceProtocol)?) -> Investment?
    )?

    func markInvestmentAsActive(
        for traderId: String,
        repository: any InvestmentRepositoryProtocol,
        investmentPoolLifecycleService: (any InvestmentPoolLifecycleServiceProtocol)?,
        telemetryService: (any TelemetryServiceProtocol)?
    ) -> Investment? {
        markInvestmentAsActiveCallCount += 1
        lastMarkActiveTraderId = traderId
        if let markInvestmentAsActiveHandler {
            return markInvestmentAsActiveHandler(traderId, repository, investmentPoolLifecycleService, telemetryService)
        }
        return markInvestmentAsActiveReturn
    }

    // MARK: - markInvestmentAsCompleted

    private(set) var markInvestmentAsCompletedCallCount = 0
    var lastMarkCompletedTraderId: String?
    var markInvestmentAsCompletedReturn: (Investment, InvestmentReservation)?
    var markInvestmentAsCompletedHandler: (
        (String, any InvestmentRepositoryProtocol, (any InvestmentPoolLifecycleServiceProtocol)?, (any TelemetryServiceProtocol)?) -> (Investment, InvestmentReservation)?
    )?

    func markInvestmentAsCompleted(
        for traderId: String,
        repository: any InvestmentRepositoryProtocol,
        investmentPoolLifecycleService: (any InvestmentPoolLifecycleServiceProtocol)?,
        telemetryService: (any TelemetryServiceProtocol)?
    ) -> (Investment, InvestmentReservation)? {
        markInvestmentAsCompletedCallCount += 1
        lastMarkCompletedTraderId = traderId
        if let markInvestmentAsCompletedHandler {
            return markInvestmentAsCompletedHandler(traderId, repository, investmentPoolLifecycleService, telemetryService)
        }
        return markInvestmentAsCompletedReturn
    }

    // MARK: - markNextInvestmentAsActive

    private(set) var markNextInvestmentAsActiveCallCount = 0
    var lastMarkNextActiveInvestmentId: String?
    var markNextInvestmentAsActiveReturn: Investment?
    var markNextInvestmentAsActiveHandler: (
        (String, any InvestmentRepositoryProtocol, (any InvestmentPoolLifecycleServiceProtocol)?) -> Investment?
    )?

    func markNextInvestmentAsActive(
        for investmentId: String,
        repository: any InvestmentRepositoryProtocol,
        investmentPoolLifecycleService: (any InvestmentPoolLifecycleServiceProtocol)?
    ) -> Investment? {
        markNextInvestmentAsActiveCallCount += 1
        lastMarkNextActiveInvestmentId = investmentId
        if let markNextInvestmentAsActiveHandler {
            return markNextInvestmentAsActiveHandler(investmentId, repository, investmentPoolLifecycleService)
        }
        return markNextInvestmentAsActiveReturn
    }

    // MARK: - markActiveInvestmentAsCompleted

    private(set) var markActiveInvestmentAsCompletedCallCount = 0
    var lastMarkActiveCompletedInvestmentId: String?
    var markActiveInvestmentAsCompletedReturn: (Investment, InvestmentReservation)?
    var markActiveInvestmentAsCompletedHandler: (
        (String, any InvestmentRepositoryProtocol, (any InvestmentPoolLifecycleServiceProtocol)?) -> (Investment, InvestmentReservation)?
    )?

    func markActiveInvestmentAsCompleted(
        for investmentId: String,
        repository: any InvestmentRepositoryProtocol,
        investmentPoolLifecycleService: (any InvestmentPoolLifecycleServiceProtocol)?
    ) -> (Investment, InvestmentReservation)? {
        markActiveInvestmentAsCompletedCallCount += 1
        lastMarkActiveCompletedInvestmentId = investmentId
        if let markActiveInvestmentAsCompletedHandler {
            return markActiveInvestmentAsCompletedHandler(investmentId, repository, investmentPoolLifecycleService)
        }
        return markActiveInvestmentAsCompletedReturn
    }

    // MARK: - deleteInvestment

    private(set) var deleteInvestmentCallCount = 0
    var lastDeleteInvestmentId: String?
    var deleteInvestmentReturn: Bool = false
    var deleteInvestmentHandler: ((String, any InvestmentRepositoryProtocol) -> Bool)?

    func deleteInvestment(
        investmentId: String,
        repository: any InvestmentRepositoryProtocol
    ) -> Bool {
        deleteInvestmentCallCount += 1
        lastDeleteInvestmentId = investmentId
        if let deleteInvestmentHandler {
            return deleteInvestmentHandler(investmentId, repository)
        }
        return deleteInvestmentReturn
    }

    // MARK: - Reset

    func reset() {
        markInvestmentAsActiveCallCount = 0
        lastMarkActiveTraderId = nil
        markInvestmentAsActiveReturn = nil
        markInvestmentAsActiveHandler = nil

        markInvestmentAsCompletedCallCount = 0
        lastMarkCompletedTraderId = nil
        markInvestmentAsCompletedReturn = nil
        markInvestmentAsCompletedHandler = nil

        markNextInvestmentAsActiveCallCount = 0
        lastMarkNextActiveInvestmentId = nil
        markNextInvestmentAsActiveReturn = nil
        markNextInvestmentAsActiveHandler = nil

        markActiveInvestmentAsCompletedCallCount = 0
        lastMarkActiveCompletedInvestmentId = nil
        markActiveInvestmentAsCompletedReturn = nil
        markActiveInvestmentAsCompletedHandler = nil

        deleteInvestmentCallCount = 0
        lastDeleteInvestmentId = nil
        deleteInvestmentReturn = false
        deleteInvestmentHandler = nil
    }
}
