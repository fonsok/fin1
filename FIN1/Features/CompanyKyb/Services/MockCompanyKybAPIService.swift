import Foundation

/// In-memory mock for development – lets you walk through all 8 KYB steps
/// without a running Parse Server. Simulates latency and tracks state.
final class MockCompanyKybAPIService: CompanyKybAPIServiceProtocol, @unchecked Sendable {

    private let latency: UInt64 = 400_000_000 // 0.4 s

    private var currentStep: String?
    private var completedSteps: [String] = []
    private var savedProgress: [String: [String: Any]] = [:]
    private var kybCompleted = false
    private var kybStatus: String?

    private let validSteps = [
        "legal_entity", "registered_address", "tax_compliance",
        "beneficial_owners", "authorized_representatives",
        "documents", "declarations", "submission",
    ]

    func getCompanyKybProgress() async throws -> CompanyKybProgress {
        try await Task.sleep(nanoseconds: self.latency)

        return CompanyKybProgress(
            currentStep: self.currentStep,
            completedSteps: self.completedSteps,
            companyKybCompleted: self.kybCompleted,
            companyKybStatus: self.kybStatus,
            savedData: nil
        )
    }

    func completeStep(step: String, data: SavedCompanyKybData) async throws -> CompanyKybStepResponse {
        try await Task.sleep(nanoseconds: self.latency)

        guard self.validSteps.contains(step) else {
            throw NSError(domain: "MockKYB", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Invalid step: \(step)",
            ])
        }

        self.currentStep = step
        if !self.completedSteps.contains(step) {
            self.completedSteps.append(step)
        }

        if step == "submission" {
            self.kybCompleted = true
            self.kybStatus = "pending_review"
        } else {
            self.kybStatus = self.kybStatus ?? "draft"
        }

        let nextIndex = (validSteps.firstIndex(of: step) ?? 0) + 1
        let nextStep = nextIndex < self.validSteps.count ? self.validSteps[nextIndex] : nil

        return CompanyKybStepResponse(
            success: true,
            nextStep: nextStep,
            companyKybCompleted: self.kybCompleted,
            companyKybStatus: self.kybStatus
        )
    }

    func savePartialProgress(step: String, data: SavedCompanyKybData) async throws {
        try await Task.sleep(nanoseconds: self.latency / 2)
        self.currentStep = step
        self.kybStatus = self.kybStatus ?? "draft"
    }

    func savePartialProgressPositionOnly(step: String) async throws {
        try await Task.sleep(nanoseconds: self.latency / 4)
        self.currentStep = step
    }
}
