import SwiftUI

// MARK: - Terms Acceptance Modal View

/// Blocking modal that requires users to accept updated Terms of Service and/or Privacy Policy
/// Prevents app usage until acceptance is complete
struct TermsAcceptanceModalView: View {
    @ObservedObject private var viewModel: TermsAcceptanceViewModel
    @Environment(\.appServices) private var appServices
    @State private var showTermsOfService = false
    @State private var showPrivacyPolicy = false

    init(
        termsAcceptanceService: any TermsAcceptanceServiceProtocol,
        userService: any UserServiceProtocol,
        parseAPIClient: (any ParseAPIClientProtocol)? = nil,
        termsContentService: (any TermsContentServiceProtocol)? = nil
    ) {
        self._viewModel = ObservedObject(wrappedValue: TermsAcceptanceViewModel(
            termsAcceptanceService: termsAcceptanceService,
            userService: userService,
            parseAPIClient: parseAPIClient,
            termsContentService: termsContentService
        ))
    }

    var body: some View {
        ZStack {
            // Blocking background
            AppTheme.screenBackground
                .ignoresSafeArea()

            if self.viewModel.isLoading {
                self.loadingView
            } else {
                self.contentView
            }
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
        .onChange(of: self.viewModel.canProceed) { _, canProceed in
            // Hide modal when all documents are accepted
            if canProceed {
                // Notify that acceptance is complete
                NotificationCenter.default.post(name: .userDataDidUpdate, object: nil)
            }
        }
    }

    // MARK: - Content Views

    private var contentView: some View {
        VStack(spacing: ResponsiveDesign.spacing(24)) {
            // Header
            self.headerSection

            // Acceptance Items
            VStack(spacing: ResponsiveDesign.spacing(16)) {
                if self.viewModel.needsTermsAcceptance {
                    self.termsAcceptanceCard
                }

                if self.viewModel.needsPrivacyPolicyAcceptance {
                    self.privacyPolicyAcceptanceCard
                }
            }

            // Error Message
            if let errorMessage = viewModel.errorMessage {
                self.errorView(message: errorMessage)
            }
        }
        .padding(ResponsiveDesign.spacing(24))
    }

    private var headerSection: some View {
        VStack(spacing: ResponsiveDesign.spacing(12)) {
            Image(systemName: "doc.text.fill")
                .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize() * 2))
                .foregroundColor(AppTheme.accentLightBlue)

            Text("Updated Legal Documents")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.bold)
                .foregroundColor(AppTheme.fontColor)

            Text("Please review and accept the updated legal documents to continue using the app.")
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))
                .multilineTextAlignment(.center)
        }
    }

    private var termsAcceptanceCard: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            HStack {
                Image(systemName: "doc.text.fill")
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(AppTheme.accentLightBlue)

                Text("Terms of Service")
                    .font(ResponsiveDesign.headlineFont())
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.fontColor)

                Spacer()
            }

            Text("Version \(self.viewModel.currentTermsVersionForDisplay)")
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.6))

            HStack(spacing: ResponsiveDesign.spacing(12)) {
                Button("Review") {
                    self.showTermsOfService = true
                }
                .buttonStyle(.bordered)
                .foregroundColor(AppTheme.accentLightBlue)

                Button("Accept") {
                    Task {
                        await self.viewModel.acceptTerms()
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

    private var privacyPolicyAcceptanceCard: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            HStack {
                Image(systemName: "hand.raised.slash.fill")
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(AppTheme.accentRed)

                Text("Privacy Policy")
                    .font(ResponsiveDesign.headlineFont())
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.fontColor)

                Spacer()
            }

            Text("Version \(self.viewModel.currentPrivacyVersionForDisplay)")
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.6))

            HStack(spacing: ResponsiveDesign.spacing(12)) {
                Button("Review") {
                    self.showPrivacyPolicy = true
                }
                .buttonStyle(.bordered)
                .foregroundColor(AppTheme.accentLightBlue)

                Button("Accept") {
                    Task {
                        await self.viewModel.acceptPrivacyPolicy()
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
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(AppTheme.accentRed)

            Text(message)
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.accentRed)
        }
        .padding(ResponsiveDesign.spacing(12))
        .background(AppTheme.accentRed.opacity(0.1))
        .cornerRadius(ResponsiveDesign.spacing(8))
    }

    private var loadingView: some View {
        VStack(spacing: ResponsiveDesign.spacing(16)) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Saving acceptance...")
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))
        }
    }
}

#Preview {
    TermsAcceptanceModalView(
        termsAcceptanceService: TermsAcceptanceService(),
        userService: UserService(),
        parseAPIClient: nil,
        termsContentService: nil
    )
}

