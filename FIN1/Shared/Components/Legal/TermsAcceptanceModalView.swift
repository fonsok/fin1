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

            if viewModel.isLoading {
                loadingView
            } else {
                contentView
            }
        }
        .sheet(isPresented: $showTermsOfService) {
            TermsOfServiceView(
                configurationService: appServices.configurationService,
                termsContentService: appServices.termsContentService
            )
        }
        .sheet(isPresented: $showPrivacyPolicy) {
            PrivacyPolicyView(
                userService: appServices.userService,
                termsContentService: appServices.termsContentService
            )
        }
        .onChange(of: viewModel.canProceed) { _, canProceed in
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
            headerSection

            // Acceptance Items
            VStack(spacing: ResponsiveDesign.spacing(16)) {
                if viewModel.needsTermsAcceptance {
                    termsAcceptanceCard
                }

                if viewModel.needsPrivacyPolicyAcceptance {
                    privacyPolicyAcceptanceCard
                }
            }

            // Error Message
            if let errorMessage = viewModel.errorMessage {
                errorView(message: errorMessage)
            }
        }
        .padding(ResponsiveDesign.spacing(24))
    }

    private var headerSection: some View {
        VStack(spacing: ResponsiveDesign.spacing(12)) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: ResponsiveDesign.iconSize() * 2))
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

            Text("Version \(viewModel.currentTermsVersionForDisplay)")
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.6))

            HStack(spacing: ResponsiveDesign.spacing(12)) {
                Button("Review") {
                    showTermsOfService = true
                }
                .buttonStyle(.bordered)
                .foregroundColor(AppTheme.accentLightBlue)

                Button("Accept") {
                    Task {
                        await viewModel.acceptTerms()
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

            Text("Version \(viewModel.currentPrivacyVersionForDisplay)")
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.6))

            HStack(spacing: ResponsiveDesign.spacing(12)) {
                Button("Review") {
                    showPrivacyPolicy = true
                }
                .buttonStyle(.bordered)
                .foregroundColor(AppTheme.accentLightBlue)

                Button("Accept") {
                    Task {
                        await viewModel.acceptPrivacyPolicy()
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

