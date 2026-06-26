import SwiftUI

/// Post-onboarding role agreement re-consent with scroll-to-accept (Gate 2 contract).
struct RoleAgreementReConsentView: View {
    let item: RequiredReConsent
    let role: UserRole
    let termsContentService: (any TermsContentServiceProtocol)?
    let roleAgreementConsentService: (any RoleAgreementConsentServiceProtocol)?
    let onAccepted: (_ version: String, _ documentHash: String?) async -> Void

    @StateObject private var viewModel: RoleAgreementStepViewModel
    @State private var didSubmit = false

    init(
        item: RequiredReConsent,
        role: UserRole,
        termsContentService: (any TermsContentServiceProtocol)?,
        roleAgreementConsentService: (any RoleAgreementConsentServiceProtocol)?,
        onAccepted: @escaping (_ version: String, _ documentHash: String?) async -> Void
    ) {
        self.item = item
        self.role = role
        self.termsContentService = termsContentService
        self.roleAgreementConsentService = roleAgreementConsentService
        self.onAccepted = onAccepted
        _viewModel = StateObject(
            wrappedValue: RoleAgreementStepViewModel(
                role: role,
                termsContentService: termsContentService,
                roleAgreementConsentService: roleAgreementConsentService
            )
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(16)) {
            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
                Text(self.viewModel.title)
                    .font(ResponsiveDesign.headlineFont())
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.fontColor)

                Text(
                    String(
                        localized: "Neue Version erforderlich: \(self.item.userVersion) → \(self.item.activeVersion)"
                    )
                )
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))
            }

            if self.viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: ResponsiveDesign.spacing(200))
            } else {
                self.documentScrollView
                self.consentControls
            }

            if let submitError = viewModel.submitError, !submitError.isEmpty {
                Text(submitError)
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.accentRed)
            }
        }
        .task {
            await self.viewModel.loadDocument()
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
                Text(String(localized: "Bitte scrollen Sie bis zum Ende der Vereinbarung."))
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.75))
            }
        }
    }

    private var consentControls: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            Toggle(
                isOn: self.$viewModel.isCheckboxChecked,
                label: {
                    Text(
                        String(
                            localized: "Ich habe die aktualisierte Vereinbarung gelesen und akzeptiere sie."
                        )
                    )
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor)
                }
            )
            .toggleStyle(ReConsentCheckboxToggleStyle())
            .disabled(!self.viewModel.hasScrolledToBottom)

            Button(String(localized: "Vereinbarung bestätigen")) {
                Task {
                    guard !self.didSubmit, self.viewModel.canSubmit else { return }
                    self.didSubmit = true
                    await self.onAccepted(self.viewModel.documentVersion, self.viewModel.documentHash)
                    self.didSubmit = false
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.accentLightBlue)
            .disabled(!self.viewModel.canSubmit || self.viewModel.isSubmitting)
        }
    }
}

private struct ReConsentCheckboxToggleStyle: ToggleStyle {
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
