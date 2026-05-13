import SwiftUI

struct CompanyKybView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appServices) private var appServices
    @StateObject private var viewModel: CompanyKybViewModel

    init(companyKybAPIService: CompanyKybAPIServiceProtocol) {
        _viewModel = StateObject(wrappedValue: CompanyKybViewModel(
            companyKybAPIService: companyKybAPIService
        ))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.screenBackground.ignoresSafeArea()

                if self.viewModel.isResuming {
                    self.resumingIndicator
                }

                VStack(spacing: ResponsiveDesign.spacing(0)) {
                    self.progressHeader
                    self.stepContent
                    self.navigationButtons
                }
                .opacity(self.viewModel.isResuming ? 0 : 1)
            }
            .navigationTitle(self.viewModel.currentStep.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") {
                        Task { await self.viewModel.savePartialProgress() }
                        self.dismiss()
                    }
                    .foregroundColor(AppTheme.accentLightBlue)
                }
            }
        }
        .alert("Fehler", isPresented: self.$viewModel.showError) {
            Button("OK") {}
        } message: {
            Text(self.viewModel.errorMessage)
        }
        .task { await self.viewModel.resumeProgress() }
        .onChange(of: self.viewModel.shouldDismiss) { _, shouldDismiss in
            if shouldDismiss { self.dismiss() }
        }
    }

    // MARK: - Subviews

    private var resumingIndicator: some View {
        VStack(spacing: ResponsiveDesign.spacing(16)) {
            ProgressView().scaleEffect(1.2)
            Text("Fortschritt wird geladen…")
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor)
        }
    }

    private var progressHeader: some View {
        VStack(spacing: ResponsiveDesign.spacing(8)) {
            ProgressView(value: self.viewModel.progress)
                .tint(AppTheme.accentLightBlue)

            HStack {
                Text("Schritt \(self.viewModel.currentStepNumber) von \(CompanyKybStep.totalSteps)")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.7))
                Spacer()
                Image(systemName: self.viewModel.currentStep.icon)
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.accentLightBlue)
            }
        }
        .padding(.horizontal, ResponsiveDesign.lightBlueAreaHorizontalPadding())
        .padding(.vertical, ResponsiveDesign.spacing(8))
    }

    @ViewBuilder
    private var stepContent: some View {
        ScrollView {
            VStack(spacing: ResponsiveDesign.spacing(24)) {
                self.stepView(for: self.viewModel.currentStep)
            }
            .padding(.top, ResponsiveDesign.spacing(8))
            .padding(.bottom, ResponsiveDesign.spacing(8))
            .padding(.horizontal, ResponsiveDesign.scrollSectionHorizontalPadding())
            .background(AppTheme.systemSecondaryBackground)
            .cornerRadius(ResponsiveDesign.spacing(12))
        }
        .padding(.horizontal, ResponsiveDesign.lightBlueAreaHorizontalPadding())
    }

    @ViewBuilder
    private func stepView(for step: CompanyKybStep) -> some View {
        switch step {
        case .legalEntity:
            CompanyKybLegalEntityStep(formData: self.$viewModel.legalEntity)
        case .registeredAddress:
            CompanyKybAddressStep(formData: self.$viewModel.registeredAddress)
        case .taxCompliance:
            CompanyKybTaxStep(formData: self.$viewModel.taxCompliance)
        case .beneficialOwners:
            CompanyKybOwnersStep(formData: self.$viewModel.beneficialOwners)
        case .authorizedRepresentatives:
            CompanyKybRepresentativesStep(formData: self.$viewModel.authorizedRepresentatives)
        case .documents:
            CompanyKybDocumentsStep(formData: self.$viewModel.documents)
        case .declarations:
            CompanyKybDeclarationsStep(formData: self.$viewModel.declarations)
        case .submission:
            CompanyKybSubmissionStep(
                formData: self.$viewModel.submission,
                viewModel: self.viewModel
            )
        }
    }

    private var navigationButtons: some View {
        HStack(spacing: ResponsiveDesign.spacing(16)) {
            if !self.viewModel.isFirstStep {
                Button(action: { self.viewModel.previousStep() }) {
                    Text("Zurück")
                        .font(ResponsiveDesign.headlineFont())
                        .foregroundColor(AppTheme.accentLightBlue)
                        .frame(maxWidth: .infinity)
                        .frame(height: ResponsiveDesign.spacing(50))
                        .background(AppTheme.screenBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(12))
                                .stroke(AppTheme.accentLightBlue, lineWidth: 1)
                        )
                        .cornerRadius(ResponsiveDesign.spacing(12))
                }
            }

            Button(action: { self.viewModel.nextStep() }) {
                Group {
                    if self.viewModel.isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text(self.viewModel.isLastStep ? "Einreichen" : "Weiter")
                            .font(ResponsiveDesign.headlineFont())
                    }
                }
                .foregroundColor(AppTheme.screenBackground)
                .frame(maxWidth: .infinity)
                .frame(height: ResponsiveDesign.spacing(50))
                .background(
                    self.viewModel.canCompleteCurrentStep
                        ? AppTheme.accentLightBlue
                        : AppTheme.accentLightBlue.opacity(0.4)
                )
                .cornerRadius(ResponsiveDesign.spacing(12))
            }
            .disabled(!self.viewModel.canCompleteCurrentStep || self.viewModel.isLoading)
        }
        .padding(.horizontal, ResponsiveDesign.lightBlueAreaHorizontalPadding())
        .padding(.vertical, ResponsiveDesign.spacing(12))
    }
}

// MARK: - Preview (uses in-memory mock – no backend required)

#Preview("Company KYB Wizard") {
    CompanyKybView(companyKybAPIService: MockCompanyKybAPIService())
}
