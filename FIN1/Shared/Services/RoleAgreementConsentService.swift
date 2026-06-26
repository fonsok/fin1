import Foundation

/// Records trader/investor role agreement consent with audit trail (`recordRoleAgreementConsent`).
protocol RoleAgreementConsentServiceProtocol: Sendable {
    func recordConsent(
        role: UserRole,
        version: String,
        documentHash: String?
    ) async throws
}

final class RoleAgreementConsentService: RoleAgreementConsentServiceProtocol, @unchecked Sendable {
    private let parseAPIClient: (any ParseAPIClientProtocol)?

    init(parseAPIClient: (any ParseAPIClientProtocol)?) {
        self.parseAPIClient = parseAPIClient
    }

    private struct ConsentResult: Codable {
        let objectId: String?
        let acceptedAt: String?
    }

    func recordConsent(
        role: UserRole,
        version: String,
        documentHash: String?
    ) async throws {
        guard let parseAPIClient else {
            throw AppError.serviceError(.serviceUnavailable)
        }

        var parameters: [String: Any] = [
            "role": role.rawValue,
            "version": version,
            "platform": AppBuildInfo.platform,
            "appVersion": AppBuildInfo.appVersion,
            "buildNumber": AppBuildInfo.buildNumber,
            "deviceInstallId": DeviceInstallIdProvider.getOrCreate(),
            "source": "onboarding",
            "sendConfirmationEmail": true,
        ]
        if let documentHash, !documentHash.isEmpty {
            parameters["documentHash"] = documentHash
        }

        let _: ConsentResult = try await parseAPIClient.callFunction(
            "recordRoleAgreementConsent",
            parameters: parameters
        )
    }
}
