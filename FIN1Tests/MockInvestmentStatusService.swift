@testable import FIN1
import Foundation

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
        self.markInvestmentAsActiveCallCount += 1
        self.lastMarkActiveTraderId = traderId
        if let markInvestmentAsActiveHandler {
            return markInvestmentAsActiveHandler(traderId, repository, investmentPoolLifecycleService, telemetryService)
        }
        return self.markInvestmentAsActiveReturn
    }

    // MARK: - markInvestmentAsCompleted

    private(set) var markInvestmentAsCompletedCallCount = 0
    var lastMarkCompletedTraderId: String?
    var markInvestmentAsCompletedReturn: (Investment, InvestmentReservation)?
    var markInvestmentAsCompletedHandler: (
        (String, any InvestmentRepositoryProtocol, (any InvestmentPoolLifecycleServiceProtocol)?, (any TelemetryServiceProtocol)?) -> (
            Investment,
            InvestmentReservation
        )?
    )?

    func markInvestmentAsCompleted(
        for traderId: String,
        repository: any InvestmentRepositoryProtocol,
        investmentPoolLifecycleService: (any InvestmentPoolLifecycleServiceProtocol)?,
        telemetryService: (any TelemetryServiceProtocol)?
    ) -> (Investment, InvestmentReservation)? {
        self.markInvestmentAsCompletedCallCount += 1
        self.lastMarkCompletedTraderId = traderId
        if let markInvestmentAsCompletedHandler {
            return markInvestmentAsCompletedHandler(traderId, repository, investmentPoolLifecycleService, telemetryService)
        }
        return self.markInvestmentAsCompletedReturn
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
        self.markNextInvestmentAsActiveCallCount += 1
        self.lastMarkNextActiveInvestmentId = investmentId
        if let markNextInvestmentAsActiveHandler {
            return markNextInvestmentAsActiveHandler(investmentId, repository, investmentPoolLifecycleService)
        }
        return self.markNextInvestmentAsActiveReturn
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
        self.markActiveInvestmentAsCompletedCallCount += 1
        self.lastMarkActiveCompletedInvestmentId = investmentId
        if let markActiveInvestmentAsCompletedHandler {
            return markActiveInvestmentAsCompletedHandler(investmentId, repository, investmentPoolLifecycleService)
        }
        return self.markActiveInvestmentAsCompletedReturn
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
        self.deleteInvestmentCallCount += 1
        self.lastDeleteInvestmentId = investmentId
        if let deleteInvestmentHandler {
            return deleteInvestmentHandler(investmentId, repository)
        }
        return self.deleteInvestmentReturn
    }

    // MARK: - Reset

    func reset() {
        self.markInvestmentAsActiveCallCount = 0
        self.lastMarkActiveTraderId = nil
        self.markInvestmentAsActiveReturn = nil
        self.markInvestmentAsActiveHandler = nil

        self.markInvestmentAsCompletedCallCount = 0
        self.lastMarkCompletedTraderId = nil
        self.markInvestmentAsCompletedReturn = nil
        self.markInvestmentAsCompletedHandler = nil

        self.markNextInvestmentAsActiveCallCount = 0
        self.lastMarkNextActiveInvestmentId = nil
        self.markNextInvestmentAsActiveReturn = nil
        self.markNextInvestmentAsActiveHandler = nil

        self.markActiveInvestmentAsCompletedCallCount = 0
        self.lastMarkActiveCompletedInvestmentId = nil
        self.markActiveInvestmentAsCompletedReturn = nil
        self.markActiveInvestmentAsCompletedHandler = nil

        self.deleteInvestmentCallCount = 0
        self.lastDeleteInvestmentId = nil
        self.deleteInvestmentReturn = false
        self.deleteInvestmentHandler = nil
    }
}
