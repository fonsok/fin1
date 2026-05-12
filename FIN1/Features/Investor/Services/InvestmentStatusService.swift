import Foundation
import os

// MARK: - Investment Status Service
@MainActor
final class InvestmentStatusService: InvestmentStatusServiceProtocol {

    private static let log = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "FIN1",
        category: "InvestmentStatusService"
    )

    init() {}

    func markInvestmentAsActive(
        for traderId: String,
        repository: any InvestmentRepositoryProtocol,
        investmentPoolLifecycleService: (any InvestmentPoolLifecycleServiceProtocol)?,
        telemetryService: (any TelemetryServiceProtocol)?
    ) -> Investment? {
        Self.log.debug("markInvestmentAsActive traderId=\(traderId, privacy: .public)")

        guard let investmentPoolLifecycleService = investmentPoolLifecycleService else {
            assertionFailure("InvestmentStatusService: investmentPoolLifecycleService is nil — cannot mark investment active for trader \(traderId)")
            Self.log.error("investmentPoolLifecycleService nil; markInvestmentAsActive skipped traderId=\(traderId, privacy: .public)")
            return nil
        }

        guard let updatedInvestment = investmentPoolLifecycleService.markInvestmentAsActive(
            for: traderId,
            in: repository.investments
        ) else {
            return nil
        }

        if let investmentIndex = repository.investments.firstIndex(where: { $0.id == updatedInvestment.id }) {
            repository.investments[investmentIndex] = updatedInvestment

            let sequenceNumber = updatedInvestment.sequenceNumber ?? 0
            Self.log.debug("Investment \(sequenceNumber) marked active traderId=\(traderId, privacy: .public)")
            telemetryService?.trackEvent(name: "investment_activated", properties: [
                "investment_id": updatedInvestment.id,
                "trader_id": traderId,
                "sequence_number": sequenceNumber
            ])

            return updatedInvestment
        }

        return nil
    }

    func markInvestmentAsCompleted(
        for traderId: String,
        repository: any InvestmentRepositoryProtocol,
        investmentPoolLifecycleService: (any InvestmentPoolLifecycleServiceProtocol)?,
        telemetryService: (any TelemetryServiceProtocol)?
    ) -> (Investment, InvestmentReservation)? {
        Self.log.debug("markInvestmentAsCompleted traderId=\(traderId, privacy: .public)")

        guard let investmentPoolLifecycleService = investmentPoolLifecycleService else {
            assertionFailure("InvestmentStatusService: investmentPoolLifecycleService is nil — cannot mark investment completed for trader \(traderId)")
            Self.log.error("investmentPoolLifecycleService nil; markInvestmentAsCompleted skipped traderId=\(traderId, privacy: .public)")
            return nil
        }

        guard let (updatedInvestment, completedReservation) = investmentPoolLifecycleService.markInvestmentAsCompleted(
            for: traderId,
            in: repository.investments
        ) else {
            return nil
        }

        if let investmentIndex = repository.investments.firstIndex(where: { $0.id == updatedInvestment.id }) {
            repository.investments[investmentIndex] = updatedInvestment

            Self.log.debug("Investment seq=\(completedReservation.sequenceNumber) marked completed traderId=\(traderId, privacy: .public)")
            telemetryService?.trackEvent(name: "investment_completed", properties: [
                "investment_id": updatedInvestment.id,
                "trader_id": traderId,
                "sequence_number": completedReservation.sequenceNumber
            ])

            return (updatedInvestment, completedReservation)
        }

        return nil
    }

    func markNextInvestmentAsActive(
        for investmentId: String,
        repository: any InvestmentRepositoryProtocol,
        investmentPoolLifecycleService: (any InvestmentPoolLifecycleServiceProtocol)?
    ) -> Investment? {
        guard let investmentPoolLifecycleService = investmentPoolLifecycleService else {
            assertionFailure("InvestmentStatusService: investmentPoolLifecycleService is nil — markNextInvestmentAsActive investmentId=\(investmentId)")
            Self.log.error("investmentPoolLifecycleService nil; markNextInvestmentAsActive skipped investmentId=\(investmentId, privacy: .public)")
            return nil
        }

        guard let updatedInvestment = investmentPoolLifecycleService.markNextInvestmentAsActive(
            for: investmentId,
            in: repository.investments
        ) else {
            return nil
        }

        if let investmentIndex = repository.investments.firstIndex(where: { $0.id == investmentId }) {
            repository.investments[investmentIndex] = updatedInvestment
            return updatedInvestment
        }

        return nil
    }

    func markActiveInvestmentAsCompleted(
        for investmentId: String,
        repository: any InvestmentRepositoryProtocol,
        investmentPoolLifecycleService: (any InvestmentPoolLifecycleServiceProtocol)?
    ) -> (Investment, InvestmentReservation)? {
        guard let investmentPoolLifecycleService = investmentPoolLifecycleService else {
            assertionFailure("InvestmentStatusService: investmentPoolLifecycleService is nil — markActiveInvestmentAsCompleted investmentId=\(investmentId)")
            Self.log.error("investmentPoolLifecycleService nil; markActiveInvestmentAsCompleted skipped investmentId=\(investmentId, privacy: .public)")
            return nil
        }

        guard let (updatedInvestment, completedReservation) = investmentPoolLifecycleService.markActiveInvestmentAsCompleted(
            for: investmentId,
            in: repository.investments
        ) else {
            return nil
        }

        if let investmentIndex = repository.investments.firstIndex(where: { $0.id == investmentId }) {
            repository.investments[investmentIndex] = updatedInvestment
            return (updatedInvestment, completedReservation)
        }

        return nil
    }

    func deleteInvestment(
        investmentId: String,
        repository: any InvestmentRepositoryProtocol
    ) -> Bool {
        Self.log.debug("deleteInvestment id=\(investmentId, privacy: .public) count=\(repository.investments.count)")

        guard let investmentIndex = repository.investments.firstIndex(where: { $0.id == investmentId }) else {
            Self.log.warning("deleteInvestment not found id=\(investmentId, privacy: .public)")
            return false
        }

        let investment = repository.investments[investmentIndex]

        guard investment.reservationStatus == .reserved else {
            Self.log.warning("deleteInvestment rejected status=\(investment.reservationStatus.rawValue) id=\(investmentId, privacy: .public)")
            return false
        }

        repository.investments.remove(at: investmentIndex)
        Self.log.debug("deleteInvestment removed id=\(investmentId, privacy: .public) remaining=\(repository.investments.count)")

        return true
    }
}
