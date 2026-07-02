import Foundation

extension OrderAPIService {
    func finalizePairedBuyExecution(pairExecutionId: String) async throws {
        print("📡 OrderAPIService: Finalizing paired buy execution: \(pairExecutionId)")

        struct FinalizePairedBuyResponse: Decodable {
            let pairExecutionId: String?
            let status: String?
        }

        _ = try await self.apiClient.callFunction(
            "finalizePairedBuyExecution",
            parameters: ["pairExecutionId": pairExecutionId]
        ) as FinalizePairedBuyResponse

        print("✅ OrderAPIService: Paired buy finalized on server")
    }

    func commitPairedBuyExecution(pairExecutionId: String, postDisplayStatus: String? = nil) async throws {
        print("📡 OrderAPIService: Committing paired buy execution: \(pairExecutionId)")

        struct CommitPairedBuyResponse: Decodable {
            let pairExecutionId: String?
            let status: String?
            let postDisplayStatus: String?
        }

        var parameters: [String: Any] = ["pairExecutionId": pairExecutionId]
        if let postDisplayStatus, !postDisplayStatus.isEmpty {
            parameters["postDisplayStatus"] = postDisplayStatus
        }

        _ = try await self.apiClient.callFunction(
            "commitPairedBuyExecution",
            parameters: parameters
        ) as CommitPairedBuyResponse

        print("✅ OrderAPIService: Paired buy committed on server")
    }

    func advancePairedOrderStatus(pairExecutionId: String, status: String) async throws {
        print("📡 OrderAPIService: Advancing paired order status: \(pairExecutionId) → \(status)")

        struct AdvancePairedOrderStatusResponse: Decodable {
            let pairExecutionId: String?
            let status: String?
            let legCount: Int?
        }

        _ = try await self.apiClient.callFunction(
            "advancePairedOrderStatus",
            parameters: [
                "pairExecutionId": pairExecutionId,
                "status": status,
            ]
        ) as AdvancePairedOrderStatusResponse

        print("✅ OrderAPIService: Paired order legs advanced to \(status)")
    }
}
