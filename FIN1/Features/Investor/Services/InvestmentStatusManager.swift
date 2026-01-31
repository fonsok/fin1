import Foundation

// MARK: - Investment Status Manager
/// Handles investment status transitions (reserved → active → completed)
/// Extracted from InvestmentService to follow single responsibility principle
struct InvestmentStatusManager {

    // MARK: - Mark Investment as Active

    /// Marks the first reserved investment as active for a trader
    /// - Parameters:
    ///   - traderId: ID of the trader
    ///   - repository: Investment repository
    ///   - investmentManagementService: Service for investment management
    ///   - telemetryService: Optional telemetry service for tracking
    /// - Returns: Updated investment if found, nil otherwise
    @MainActor
    static func markInvestmentAsActive(
        for traderId: String,
        repository: any InvestmentRepositoryProtocol,
        investmentManagementService: (any InvestmentManagementServiceProtocol)?,
        telemetryService: (any TelemetryServiceProtocol)?
    ) -> Investment? {
        print("🔍 InvestmentStatusManager.markInvestmentAsActive: Called for trader '\(traderId)'")

        guard let investmentManagementService = investmentManagementService else {
            print("⚠️ InvestmentStatusManager: investmentManagementService is nil")
            return nil
        }

        guard let updatedInvestment = investmentManagementService.markInvestmentAsActive(
            for: traderId,
            in: repository.investments
        ) else {
            return nil
        }

        if let investmentIndex = repository.investments.firstIndex(where: { $0.id == updatedInvestment.id }) {
            repository.investments[investmentIndex] = updatedInvestment

            let sequenceNumber = updatedInvestment.sequenceNumber ?? 0
            print("✅ InvestmentStatusManager: Investment \(sequenceNumber) marked as active for trader \(traderId)")
            telemetryService?.trackEvent(name: "investment_activated", properties: [
                "investment_id": updatedInvestment.id,
                "trader_id": traderId,
                "sequence_number": sequenceNumber
            ])

            return updatedInvestment
        }

        return nil
    }

    // MARK: - Mark Investment as Completed

    /// Marks the first active investment as completed for a trader
    /// - Parameters:
    ///   - traderId: ID of the trader
    ///   - repository: Investment repository
    ///   - investmentManagementService: Service for investment management
    ///   - telemetryService: Optional telemetry service for tracking
    /// - Returns: Tuple of (updated investment, completed reservation) if found
    @MainActor
    static func markInvestmentAsCompleted(
        for traderId: String,
        repository: any InvestmentRepositoryProtocol,
        investmentManagementService: (any InvestmentManagementServiceProtocol)?,
        telemetryService: (any TelemetryServiceProtocol)?
    ) -> (Investment, InvestmentReservation)? {
        print("🔍 InvestmentStatusManager.markInvestmentAsCompleted: Called for trader '\(traderId)'")

        guard let investmentManagementService = investmentManagementService else {
            print("⚠️ InvestmentStatusManager: investmentManagementService is nil")
            return nil
        }

        guard let (updatedInvestment, completedReservation) = investmentManagementService.markInvestmentAsCompleted(
            for: traderId,
            in: repository.investments
        ) else {
            return nil
        }

        if let investmentIndex = repository.investments.firstIndex(where: { $0.id == updatedInvestment.id }) {
            repository.investments[investmentIndex] = updatedInvestment

            print("✅ InvestmentStatusManager: Investment \(completedReservation.sequenceNumber) marked as completed for trader \(traderId)")
            telemetryService?.trackEvent(name: "investment_completed", properties: [
                "investment_id": updatedInvestment.id,
                "trader_id": traderId,
                "sequence_number": completedReservation.sequenceNumber
            ])

            return (updatedInvestment, completedReservation)
        }

        return nil
    }

    // MARK: - Mark Next Investment as Active (Specific Investment)

    /// Marks the next reserved investment as active for a specific investment ID
    /// - Parameters:
    ///   - investmentId: ID of the specific investment
    ///   - repository: Investment repository
    ///   - investmentManagementService: Service for investment management
    /// - Returns: Updated investment if found, nil otherwise
    @MainActor
    static func markNextInvestmentAsActive(
        for investmentId: String,
        repository: any InvestmentRepositoryProtocol,
        investmentManagementService: (any InvestmentManagementServiceProtocol)?
    ) -> Investment? {
        guard let investmentManagementService = investmentManagementService else { return nil }

        guard let updatedInvestment = investmentManagementService.markNextInvestmentAsActive(
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

    // MARK: - Mark Active Investment as Completed (Specific Investment)

    /// Marks the active investment as completed for a specific investment ID
    /// - Parameters:
    ///   - investmentId: ID of the specific investment
    ///   - repository: Investment repository
    ///   - investmentManagementService: Service for investment management
    /// - Returns: Tuple of (updated investment, completed reservation) if found
    @MainActor
    static func markActiveInvestmentAsCompleted(
        for investmentId: String,
        repository: any InvestmentRepositoryProtocol,
        investmentManagementService: (any InvestmentManagementServiceProtocol)?
    ) -> (Investment, InvestmentReservation)? {
        guard let investmentManagementService = investmentManagementService else { return nil }

        guard let (updatedInvestment, completedReservation) = investmentManagementService.markActiveInvestmentAsCompleted(
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

    // MARK: - Delete Investment

    /// Deletes a reserved investment from the repository
    /// - Parameters:
    ///   - investmentId: ID of the investment to delete
    ///   - repository: Investment repository
    /// - Returns: True if deletion was successful
    @MainActor
    static func deleteInvestment(
        investmentId: String,
        repository: any InvestmentRepositoryProtocol
    ) -> Bool {
        print("🗑️ InvestmentStatusManager.deleteInvestment: Attempting to delete investment \(investmentId)")
        print("   📊 Current repository investments count: \(repository.investments.count)")

        guard let investmentIndex = repository.investments.firstIndex(where: { $0.id == investmentId }) else {
            print("⚠️ InvestmentStatusManager.deleteInvestment: Investment \(investmentId) not found")
            return false
        }

        let investment = repository.investments[investmentIndex]
        print("   📋 Found investment: ID=\(investment.id), status=\(investment.reservationStatus.rawValue), amount=€\(investment.amount)")

        // Only allow deletion of reserved investments (status 1)
        guard investment.reservationStatus == .reserved else {
            print("⚠️ InvestmentStatusManager.deleteInvestment: Cannot delete investment \(investmentId) with status \(investment.reservationStatus.rawValue) - only reserved investments can be deleted")
            return false
        }

        repository.investments.remove(at: investmentIndex)
        print("✅ InvestmentStatusManager.deleteInvestment: Deleted investment \(investmentId) from repository")
        print("   📊 Updated repository investments count: \(repository.investments.count)")
        print("   📡 Repository @Published will trigger publisher update")

        return true
    }
}











