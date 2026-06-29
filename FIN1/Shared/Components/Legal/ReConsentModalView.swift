import SwiftUI

/// Blocking flow for account-level legal version drift (`requiredReConsents` from server).
struct ReConsentModalView: View {
    @StateObject private var viewModel: ReConsentViewModel
    @Environment(\.appServices) private var appServices
    @State private var showTermsOfService = false
    @State private var showPrivacyPolicy = false

    init(viewModel: ReConsentViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel)
    }

    init(
        userService: any UserServiceProtocol,
        termsAcceptanceService: any TermsAcceptanceServiceProtocol,
        roleAgreementConsentService: (any RoleAgreementConsentServiceProtocol)?,
        parseAPIClient: (any ParseAPIClientProtocol)?
    ) {
        self._viewModel = StateObject(
            wrappedValue: ReConsentViewModel(
                userService: userService,
                termsAcceptanceService: termsAcceptanceService,
                roleAgreementConsentService: roleAgreementConsentService,
                parseAPIClient: parseAPIClient
            )
        )
    }

    var body: some View {
        ZStack {
            AppTheme.screenBackground
                .ignoresSafeArea()

            if !self.viewModel.hasLoadedFromUser {
                ProgressView(String(localized: "Zustimmung wird geladen…"))
                    .tint(AppTheme.accentLightBlue)
            } else if let item = viewModel.currentItem {
                ScrollView {
                    VStack(spacing: ResponsiveDesign.spacing(24)) {
                        self.headerSection

                        if item.requiresScrollToAccept, let role = self.role(for: item) {
                            RoleAgreementReConsentView(
                                item: item,
                                role: role,
                                termsContentService: self.appServices.termsContentService,
                                roleAgreementConsentService: RoleAgreementConsentService(
                                    parseAPIClient: self.appServices.parseAPIClient
                                ),
                                onAccepted: { version, hash in
                                    await self.viewModel.acceptRoleAgreement(
                                        role: role,
                                        version: version,
                                        documentHash: hash
                                    )
                                }
                            )
                        } else {
                            self.legalDocumentCard(item: item)
                        }

                        if let errorMessage = viewModel.errorMessage {
                            self.errorView(message: errorMessage)
                        }
                    }
                    .padding(ResponsiveDesign.spacing(24))
                }
                .overlay {
                    if self.viewModel.isLoading {
                        ZStack {
                            AppTheme.screenBackground.opacity(0.6)
                            ProgressView(String(localized: "Zustimmung wird gespeichert…"))
                                .tint(AppTheme.accentLightBlue)
                        }
                        .ignoresSafeArea()
                    }
                }
            } else {
                self.resolvedEmptyState
            }
        }
        .onAppear {
            self.viewModel.loadFromCurrentUser()
            self.dismissIfNothingPending()
        }
        .onReceive(NotificationCenter.default.publisher(for: .userDataDidUpdate)) { _ in
            self.viewModel.loadFromCurrentUser()
            self.dismissIfNothingPending()
        }
        .sheet(isPresented: self.$showTermsOfService) {
            TermsOfServiceView(
                configurationService: self.appServices.configurationService,
                termsContentService: self.appServices.termsContentService
            )
        }
        .sheet(isPresented: self.$showPrivacyPolicy) {
            PrivacyPolicyView(
                userService: self.appServices.userService,
                termsContentService: self.appServices.termsContentService
            )
        }
    }

    private var headerSection: some View {
        VStack(spacing: ResponsiveDesign.spacing(12)) {
            Image(systemName: "doc.badge.clock")
                .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize() * 2))
                .foregroundColor(AppTheme.accentOrange)

            Text(String(localized: "Aktualisierte Vertragsversion"))
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.bold)
                .foregroundColor(AppTheme.fontColor)

            Text(
                String(
                    localized: "Bitte bestätigen Sie die aktualisierte Fassung, bevor Sie die App weiter nutzen."
                )
            )
            .font(ResponsiveDesign.bodyFont())
            .foregroundColor(AppTheme.fontColor.opacity(0.7))
            .multilineTextAlignment(.center)
        }
    }

    private func legalDocumentCard(item: RequiredReConsent) -> some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            Text(item.displayTitle)
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.fontColor)

            Text(
                String(
                    localized: "Ihre Version: \(item.userVersion) — erforderlich: \(item.activeVersion)"
                )
            )
            .font(ResponsiveDesign.captionFont())
            .foregroundColor(AppTheme.fontColor.opacity(0.65))

            HStack(spacing: ResponsiveDesign.spacing(12)) {
                if item.isTermsOfService {
                    Button(String(localized: "Lesen")) { self.showTermsOfService = true }
                        .buttonStyle(.bordered)
                }
                if item.isPrivacyPolicy {
                    Button(String(localized: "Lesen")) { self.showPrivacyPolicy = true }
                        .buttonStyle(.bordered)
                }

                Button(String(localized: "Akzeptieren")) {
                    Task {
                        await self.viewModel.acceptTermsOrPrivacy(item: item)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accentLightBlue)
            }
        }
        .padding(ResponsiveDesign.spacing(16))
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    private func errorView(message: String) -> some View {
        Text(message)
            .font(ResponsiveDesign.captionFont())
            .foregroundColor(AppTheme.accentRed)
            .padding(ResponsiveDesign.spacing(12))
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.accentRed.opacity(0.1))
            .cornerRadius(ResponsiveDesign.spacing(8))
    }

    private func role(for item: RequiredReConsent) -> UserRole? {
        switch item.consentType {
        case "trader_agreement": return .trader
        case "investor_agreement": return .investor
        default: return nil
        }
    }

    private var resolvedEmptyState: some View {
        VStack(spacing: ResponsiveDesign.spacing(16)) {
            ProgressView()
                .tint(AppTheme.accentLightBlue)
            Text(String(localized: "Keine ausstehenden Zustimmungen."))
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.secondaryText)
        }
    }

    /// Gate was shown but server/user state has no blocking items — release the dashboard.
    private func dismissIfNothingPending() {
        guard self.viewModel.hasLoadedFromUser, !self.viewModel.hasPendingItems else { return }
        NotificationCenter.default.post(name: .reConsentCompleted, object: nil)
    }
}
