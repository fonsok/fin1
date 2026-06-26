import SwiftUI

struct RoleAgreementStep: View {
    @ObservedObject var signUpData: SignUpData
    let coordinator: SignUpCoordinator
    @Environment(\.appServices) private var appServices
    @StateObject private var viewModel: RoleAgreementStepViewModel

    init(
        signUpData: SignUpData,
        coordinator: SignUpCoordinator,
        termsContentService: (any TermsContentServiceProtocol)?,
        roleAgreementConsentService: (any RoleAgreementConsentServiceProtocol)?
    ) {
        self.signUpData = signUpData
        self.coordinator = coordinator
        _viewModel = StateObject(
            wrappedValue: RoleAgreementStepViewModel(
                role: signUpData.userRole,
                termsContentService: termsContentService,
                roleAgreementConsentService: roleAgreementConsentService
            )
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(16)) {
            self.header

            if self.viewModel.isLoading {
                ProgressView("Vereinbarung wird geladen…")
                    .frame(maxWidth: .infinity, minHeight: ResponsiveDesign.spacing(200))
            } else {
                self.documentScrollView
                self.consentControls
                self.submitSection
            }
        }
        .padding(.horizontal, ResponsiveDesign.lightBlueAreaHorizontalPadding())
        .task {
            await self.viewModel.loadDocument()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            Text(self.viewModel.title)
                .font(ResponsiveDesign.titleFont())
                .fontWeight(.bold)
                .foregroundColor(AppTheme.fontColor)

            Text("Version \(self.viewModel.documentVersion)")
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.65))

            Text(
                "Bitte lesen Sie die Vereinbarung vollständig und bestätigen Sie diese aktiv, "
                    + "bevor Sie die Registrierung abschließen."
            )
            .font(ResponsiveDesign.bodyFont())
            .foregroundColor(AppTheme.fontColor.opacity(0.8))
        }
    }

    private var documentScrollView: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(16)) {
                ForEach(self.viewModel.sections) { section in
                    VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(6)) {
                        if !section.titleOrEmpty.isEmpty {
                            Text(section.titleOrEmpty)
                                .font(ResponsiveDesign.headlineFont())
                                .foregroundColor(AppTheme.fontColor)
                        }
                        Text(section.content)
                            .font(ResponsiveDesign.bodyFont())
                            .foregroundColor(AppTheme.fontColor.opacity(0.9))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .scrollToAcceptContainer(hasReachedBottom: self.$viewModel.hasScrolledToBottom)
            .frame(height: ResponsiveDesign.spacing(360))
            .clipped()
            .background(AppTheme.sectionBackground)
            .cornerRadius(ResponsiveDesign.spacing(12))
            .overlay(
                RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(12))
                    .stroke(AppTheme.fontColor.opacity(0.12), lineWidth: 1)
            )

            if !self.viewModel.hasScrolledToBottom {
                HStack(spacing: ResponsiveDesign.spacing(8)) {
                    Image(systemName: "arrow.down.circle")
                        .foregroundColor(AppTheme.accentOrange)
                    Text("Bitte scrollen Sie bis zum Ende der Vereinbarung.")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.75))
                }
            }
        }
    }

    private var consentControls: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            Toggle(
                isOn: self.$viewModel.isCheckboxChecked,
                label: {
                    Text(self.checkboxLabel)
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(AppTheme.fontColor)
                }
            )
            .toggleStyle(CheckboxToggleStyle())
            .disabled(!self.viewModel.hasScrolledToBottom)

            if let loadError = viewModel.loadError, !loadError.isEmpty {
                Text("Hinweis: Servertext nicht verfügbar — es wird eine lokale Fassung angezeigt.")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.accentOrange)
            }
        }
    }

    private var checkboxLabel: String {
        switch self.signUpData.userRole {
        case .trader:
            return "Ich habe die Signalgeber-Vereinbarung gelesen und stimme ihr zu."
        case .investor:
            return "Ich habe die Investor-Vereinbarung gelesen und stimme ihr zu."
        default:
            return "Ich habe die Vereinbarung gelesen und stimme ihr zu."
        }
    }

    private var submitSection: some View {
        VStack(spacing: ResponsiveDesign.spacing(12)) {
            if let error = viewModel.submitError {
                Text(error)
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.accentRed)
                    .multilineTextAlignment(.center)
            }

            Button("Zustimmen und Registrierung abschließen") {
                Task { await self.completeWithConsent() }
            }
            .font(ResponsiveDesign.headlineFont())
            .foregroundColor(AppTheme.screenBackground)
            .frame(maxWidth: .infinity)
            .padding()
            .background(self.viewModel.canSubmit ? AppTheme.accentLightBlue : AppTheme.inputFieldPlaceholder)
            .cornerRadius(ResponsiveDesign.spacing(12))
            .disabled(!self.viewModel.canSubmit)
            .accessibilityIdentifier("RoleAgreementAcceptButton")
        }
    }

    @MainActor
    private func completeWithConsent() async {
        self.coordinator.isLoading = true
        do {
            try await self.viewModel.recordConsentAndReturn()
            self.signUpData.markRoleAgreementAccepted(
                for: self.signUpData.userRole,
                version: self.viewModel.documentVersion
            )
            try await self.coordinator.finalizeRegistration(
                signUpData: self.signUpData,
                appServices: self.appServices
            )
            self.coordinator.isLoading = false
            // `userDataDidUpdate` / `registrationDidFinalize` dismiss SignUp and open MainTabView.
        } catch {
            self.coordinator.isLoading = false
            self.coordinator.showError(error.localizedDescription)
        }
    }
}

/// Checkbox style without pre-selection (explicit tap required).
private struct CheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(alignment: .top, spacing: ResponsiveDesign.spacing(12)) {
                Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                    .foregroundColor(configuration.isOn ? AppTheme.accentLightBlue : AppTheme.fontColor.opacity(0.5))
                    .font(ResponsiveDesign.headlineFont())
                configuration.label
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    RoleAgreementStep(
        signUpData: SignUpData(),
        coordinator: SignUpCoordinator(),
        termsContentService: nil,
        roleAgreementConsentService: nil
    )
    .background(AppTheme.screenBackground)
}
