import Foundation

// MARK: - Investment Document Service Protocol
/// Defines the contract for investment document generation
protocol InvestmentDocumentServiceProtocol: ServiceLifecycle {
    /// Generates investment document and notification for a batch
    /// - Parameters:
    ///   - batch: The investment batch to generate a document for
    ///   - investments: The individual investments in the batch
    func generateInvestmentDocument(for batch: InvestmentBatch, investments: [Investment]) async

    /// Generates investment document for a single investment (backward compatibility)
    /// - Parameter investment: The investment to generate a document for
    func generateInvestmentDocument(for investment: Investment) async

    /// Regenerates missing documents for a list of investments
    func regenerateInvestmentDocuments(for investments: [Investment]) async
}
