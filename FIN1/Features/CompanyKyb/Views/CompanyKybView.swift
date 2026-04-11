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

                if viewModel.isResuming {
                    resumingIndicator
                }

                VStack(spacing: ResponsiveDesign.spacing(0)) {
                    progressHeader
                    stepContent
                    navigationButtons
                }
                .opacity(viewModel.isResuming ? 0 : 1)
            }
            .navigationTitle(viewModel.currentStep.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") {
                        Task { await viewModel.savePartialProgress() }
                        dismiss()
                    }
                    .foregroundColor(AppTheme.accentLightBlue)
                }
            }
        }
        .alert("Fehler", isPresented: $viewModel.showError) {
            Button("OK") {}
        } message: {
            Text(viewModel.errorMessage)
        }
        .task { await viewModel.resumeProgress() }
        .onChange(of: viewModel.shouldDismiss) { _, shouldDismiss in
            if shouldDismiss { dismiss() }
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
            ProgressView(value: viewModel.progress)
                .tint(AppTheme.accentLightBlue)

            HStack {
                Text("Schritt \(viewModel.currentStepNumber) von \(CompanyKybStep.totalSteps)")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.7))
                Spacer()
                Image(systemName: viewModel.currentStep.icon)
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
                stepView(for: viewModel.currentStep)
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
            CompanyKybLegalEntityStep(formData: $viewModel.legalEntity)
        case .registeredAddress:
            CompanyKybAddressStep(formData: $viewModel.registeredAddress)
        case .taxCompliance:
            CompanyKybTaxStep(formData: $viewModel.taxCompliance)
        case .beneficialOwners:
            CompanyKybOwnersStep(formData: $viewModel.beneficialOwners)
        case .authorizedRepresentatives:
            CompanyKybRepresentativesStep(formData: $viewModel.authorizedRepresentatives)
        case .documents:
            CompanyKybDocumentsStep(formData: $viewModel.documents)
        case .declarations:
            CompanyKybDeclarationsStep(formData: $viewModel.declarations)
        case .submission:
            CompanyKybSubmissionStep(
                formData: $viewModel.submission,
                viewModel: viewModel
            )
        }
    }

    private var navigationButtons: some View {
        HStack(spacing: ResponsiveDesign.spacing(16)) {
            if !viewModel.isFirstStep {
                Button(action: { viewModel.previousStep() }) {
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

            Button(action: { viewModel.nextStep() }) {
                Group {
                    if viewModel.isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text(viewModel.isLastStep ? "Einreichen" : "Weiter")
                            .font(ResponsiveDesign.headlineFont())
                    }
                }
                .foregroundColor(AppTheme.screenBackground)
                .frame(maxWidth: .infinity)
                .frame(height: ResponsiveDesign.spacing(50))
                .background(
                    viewModel.canCompleteCurrentStep
                        ? AppTheme.accentLightBlue
                        : AppTheme.accentLightBlue.opacity(0.4)
                )
                .cornerRadius(ResponsiveDesign.spacing(12))
            }
            .disabled(!viewModel.canCompleteCurrentStep || viewModel.isLoading)
        }
        .padding(.horizontal, ResponsiveDesign.lightBlueAreaHorizontalPadding())
        .padding(.vertical, ResponsiveDesign.spacing(12))
    }
}

// MARK: - Preview (uses in-memory mock – no backend required)

#Preview("Company KYB Wizard") {
    CompanyKybView(companyKybAPIService: MockCompanyKybAPIService())
}
