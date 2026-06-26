import Foundation

@MainActor
final class ReConsentViewModel: ObservableObject {
    @Published private(set) var pendingItems: [RequiredReConsent] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let userService: any UserServiceProtocol
    private let termsAcceptanceService: any TermsAcceptanceServiceProtocol
    private let roleAgreementConsentService: (any RoleAgreementConsentServiceProtocol)?
    private let parseAPIClient: (any ParseAPIClientProtocol)?

    init(
        userService: any UserServiceProtocol,
        termsAcceptanceService: any TermsAcceptanceServiceProtocol,
        roleAgreementConsentService: (any RoleAgreementConsentServiceProtocol)?,
        parseAPIClient: (any ParseAPIClientProtocol)?
    ) {
        self.userService = userService
        self.termsAcceptanceService = termsAcceptanceService
        self.roleAgreementConsentService = roleAgreementConsentService
        self.parseAPIClient = parseAPIClient
    }

    var currentItem: RequiredReConsent? {
        self.pendingItems.first(where: \.blocking)
    }

    var hasPendingItems: Bool { self.currentItem != nil }

    func loadFromCurrentUser() {
        let items = self.userService.currentUser?.requiredReConsents ?? []
        self.pendingItems = items.filter(\.blocking)
    }

    func acceptTermsOrPrivacy(item: RequiredReConsent, documentHash: String? = nil) async {
        guard let user = userService.currentUser else { return }

        self.isLoading = true
        self.errorMessage = nil

        do {
            let consentType = item.consentType
            try await self.recordLegalConsent(
                consentType: consentType,
                version: item.activeVersion,
                documentHash: documentHash
            )

            var updatedUser = user
            if item.isTermsOfService {
                updatedUser = self.termsAcceptanceService.recordTermsAcceptance(
                    user: updatedUser,
                    version: item.activeVersion
                )
            } else if item.isPrivacyPolicy {
                updatedUser = self.termsAcceptanceService.recordPrivacyPolicyAcceptance(
                    user: updatedUser,
                    version: item.activeVersion
                )
            }

            try await self.userService.updateProfile(updatedUser)
            try await self.userService.refreshUserData()
            self.loadFromCurrentUser()
            self.notifyIfComplete()
            self.isLoading = false
        } catch {
            self.errorMessage = error.localizedDescription
            self.isLoading = false
        }
    }

    func acceptRoleAgreement(
        role: UserRole,
        version: String,
        documentHash: String?
    ) async {
        guard let roleAgreementConsentService else {
            self.errorMessage = AppError.serviceError(.serviceUnavailable).localizedDescription
            return
        }

        self.isLoading = true
        self.errorMessage = nil

        do {
            try await roleAgreementConsentService.recordConsent(
                role: role,
                version: version,
                documentHash: documentHash,
                source: "app",
                sendConfirmationEmail: true
            )
            try await self.userService.refreshUserData()
            self.loadFromCurrentUser()
            self.notifyIfComplete()
            self.isLoading = false
        } catch {
            self.errorMessage = error.localizedDescription
            self.isLoading = false
        }
    }

    private struct ConsentResult: Codable {
        let objectId: String?
        let acceptedAt: String?
    }

    private func recordLegalConsent(
        consentType: String,
        version: String,
        documentHash: String?
    ) async throws {
        guard let parseAPIClient else {
            throw AppError.serviceError(.serviceUnavailable)
        }

        var parameters: [String: Any] = [
            "consentType": consentType,
            "version": version,
            "platform": AppBuildInfo.platform,
            "appVersion": AppBuildInfo.appVersion,
            "buildNumber": AppBuildInfo.buildNumber,
            "deviceInstallId": DeviceInstallIdProvider.getOrCreate(),
        ]
        if let documentHash, !documentHash.isEmpty {
            parameters["documentHash"] = documentHash
        }

        let _: ConsentResult = try await parseAPIClient.callFunction(
            "recordLegalConsent",
            parameters: parameters
        )
    }

    private func notifyIfComplete() {
        guard !self.hasPendingItems else { return }
        NotificationCenter.default.post(name: .reConsentCompleted, object: nil)
    }
}
