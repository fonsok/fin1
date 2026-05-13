import SwiftUI

@MainActor
final class CompanyKybViewModel: ObservableObject {

    // MARK: - Navigation State

    @Published var currentStep: CompanyKybStep = .legalEntity
    @Published var completedSteps: Set<CompanyKybStep> = []
    @Published var isLoading = false
    @Published var isResuming = false
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var kybStatus: String?
    @Published var kybCompleted = false
    @Published var shouldDismiss = false

    // MARK: - Per-Step Form Data

    @Published var legalEntity = LegalEntityFormData()
    @Published var registeredAddress = RegisteredAddressFormData()
    @Published var taxCompliance = TaxComplianceFormData()
    @Published var beneficialOwners = BeneficialOwnersFormData()
    @Published var authorizedRepresentatives = AuthorizedRepresentativesFormData()
    @Published var documents = DocumentsFormData()
    @Published var declarations = DeclarationsFormData()
    @Published var submission = SubmissionFormData()

    // MARK: - Dependencies

    private let companyKybAPIService: CompanyKybAPIServiceProtocol

    // MARK: - Init

    init(companyKybAPIService: CompanyKybAPIServiceProtocol) {
        self.companyKybAPIService = companyKybAPIService
    }

    // MARK: - Computed Properties

    var progress: Double {
        Double(self.currentStep.rawValue) / Double(CompanyKybStep.totalSteps)
    }

    var isFirstStep: Bool { self.currentStep == .legalEntity }
    var isLastStep: Bool { self.currentStep == .submission }

    var currentStepNumber: Int { self.currentStep.rawValue }

    var canCompleteCurrentStep: Bool {
        switch self.currentStep {
        case .legalEntity:
            return !self.legalEntity.legalName.isEmpty && !self.legalEntity.legalForm.isEmpty
                && !self.legalEntity.registerType.isEmpty && !self.legalEntity.registerNumber.isEmpty
                && !self.legalEntity.registerCourt.isEmpty
        case .registeredAddress:
            return !self.registeredAddress.streetAndNumber.isEmpty
                && !self.registeredAddress.postalCode.isEmpty && !self.registeredAddress.city.isEmpty
        case .taxCompliance:
            return !self.taxCompliance.vatId.isEmpty || !self.taxCompliance.nationalTaxNumber.isEmpty
                || self.taxCompliance.noVatIdDeclared
        case .beneficialOwners:
            if self.beneficialOwners.noUboOver25Percent { return true }
            return !self.beneficialOwners.ubos.isEmpty && self.beneficialOwners.ubos.allSatisfy { ubo in
                !ubo.fullName.isEmpty && !ubo.dateOfBirth.isEmpty && !ubo.nationality.isEmpty
            }
        case .authorizedRepresentatives:
            return !self.authorizedRepresentatives.representatives.isEmpty
                && self.authorizedRepresentatives.representatives.allSatisfy { rep in
                    !rep.fullName.isEmpty && !rep.roleTitle.isEmpty
                }
        case .documents:
            return self.documents.documentsAcknowledged
        case .declarations:
            return self.declarations.sanctionsSelfDeclarationAccepted
                && self.declarations.accuracyDeclarationAccepted
                && self.declarations.noTrustThirdPartyDeclarationAccepted
        case .submission:
            return self.submission.confirmedSummary
        }
    }

    // MARK: - Navigation

    func nextStep() {
        guard self.canCompleteCurrentStep else { return }
        Task { await self.completeAndAdvance() }
    }

    func previousStep() {
        guard let prev = currentStep.previous else { return }
        withAnimation(.easeInOut(duration: 0.3)) { self.currentStep = prev }
        Task { try? await self.companyKybAPIService.savePartialProgressPositionOnly(step: prev.backendKey) }
    }

    // MARK: - Resume

    func resumeProgress() async {
        self.isResuming = true
        defer { isResuming = false }
        do {
            let progress = try await companyKybAPIService.getCompanyKybProgress()
            self.kybCompleted = progress.companyKybCompleted
            self.kybStatus = progress.companyKybStatus
            self.completedSteps = Set(progress.completedSteps.compactMap(CompanyKybStep.fromBackendKey))

            if self.kybCompleted {
                self.shouldDismiss = true
                return
            }

            self.restoreFormData(from: progress.savedData)

            if let stepKey = progress.currentStep,
               let step = CompanyKybStep.fromBackendKey(stepKey) {
                self.currentStep = step.next ?? step
            }
        } catch {
            self.presentError(error)
        }
    }

    // MARK: - Complete & Advance

    private func completeAndAdvance() async {
        self.isLoading = true
        defer { isLoading = false }

        let stepData = self.savedDataForCurrentStep()

        do {
            let response = try await companyKybAPIService.completeStep(
                step: self.currentStep.backendKey,
                data: stepData
            )
            self.completedSteps.insert(self.currentStep)
            self.kybCompleted = response.companyKybCompleted ?? false
            self.kybStatus = response.companyKybStatus

            if self.kybCompleted {
                self.shouldDismiss = true
                return
            }

            if let nextKey = response.nextStep,
               let next = CompanyKybStep.fromBackendKey(nextKey) {
                withAnimation(.easeInOut(duration: 0.3)) { self.currentStep = next }
            } else if let next = currentStep.next {
                withAnimation(.easeInOut(duration: 0.3)) { self.currentStep = next }
            }
        } catch {
            self.presentError(error)
        }
    }

    func savePartialProgress() async {
        let stepData = self.savedDataForCurrentStep()
        try? await self.companyKybAPIService.savePartialProgress(
            step: self.currentStep.backendKey,
            data: stepData
        )
    }

    // MARK: - Data Mapping

    private func savedDataForCurrentStep() -> SavedCompanyKybData {
        switch self.currentStep {
        case .legalEntity: return self.legalEntity.toSavedData()
        case .registeredAddress: return self.registeredAddress.toSavedData()
        case .taxCompliance: return self.taxCompliance.toSavedData()
        case .beneficialOwners: return self.beneficialOwners.toSavedData()
        case .authorizedRepresentatives: return self.authorizedRepresentatives.toSavedData()
        case .documents: return self.documents.toSavedData()
        case .declarations: return self.declarations.toSavedData()
        case .submission: return self.submission.toSavedData()
        }
    }

    private func restoreFormData(from data: SavedCompanyKybData?) {
        guard let data else { return }

        if let v = data.legalName { self.legalEntity.legalName = v }
        if let v = data.legalForm { self.legalEntity.legalForm = v }
        if let v = data.registerType { self.legalEntity.registerType = v }
        if let v = data.registerNumber { self.legalEntity.registerNumber = v }
        if let v = data.registerCourt { self.legalEntity.registerCourt = v }
        if let v = data.incorporationCountry { self.legalEntity.incorporationCountry = v }
        if let v = data.notRegisteredReason { self.legalEntity.notRegisteredReason = v }

        if let v = data.streetAndNumber { self.registeredAddress.streetAndNumber = v }
        if let v = data.postalCode { self.registeredAddress.postalCode = v }
        if let v = data.city { self.registeredAddress.city = v }
        if let v = data.country { self.registeredAddress.country = v }
        if let v = data.businessStreetAndNumber { self.registeredAddress.businessStreetAndNumber = v }

        if let v = data.vatId { self.taxCompliance.vatId = v }
        if let v = data.nationalTaxNumber { self.taxCompliance.nationalTaxNumber = v }
        if let v = data.economicIdentificationNumber { self.taxCompliance.economicIdentificationNumber = v }
        if let v = data.noVatIdDeclared { self.taxCompliance.noVatIdDeclared = v }

        if let v = data.noUboOver25Percent { self.beneficialOwners.noUboOver25Percent = v }
        if let ubos = data.ubos {
            self.beneficialOwners.ubos = ubos.map { ubo in
                var entry = BeneficialOwnerEntry()
                entry.fullName = ubo.fullName ?? ""
                entry.dateOfBirth = ubo.dateOfBirth ?? ""
                entry.nationality = ubo.nationality ?? ""
                entry.ownershipPercent = ubo.ownershipPercent
                entry.directOrIndirect = ubo.directOrIndirect ?? "direct"
                return entry
            }
        }

        if let v = data.appAccountHolderIsRepresentative {
            self.authorizedRepresentatives.appAccountHolderIsRepresentative = v
        }
        if let reps = data.representatives {
            self.authorizedRepresentatives.representatives = reps.map { rep in
                var entry = RepresentativeEntry()
                entry.fullName = rep.fullName ?? ""
                entry.roleTitle = rep.roleTitle ?? ""
                entry.signingAuthority = rep.signingAuthority ?? false
                return entry
            }
        }

        if let v = data.documentsAcknowledged { self.documents.documentsAcknowledged = v }
        if let v = data.tradeRegisterExtractReference { self.documents.tradeRegisterExtractReference = v }

        if let v = data.isPoliticallyExposed { self.declarations.isPoliticallyExposed = v }
        if let v = data.pepDetails { self.declarations.pepDetails = v }
        if let v = data.sanctionsSelfDeclarationAccepted { self.declarations.sanctionsSelfDeclarationAccepted = v }
        if let v = data.accuracyDeclarationAccepted { self.declarations.accuracyDeclarationAccepted = v }
        if let v = data.noTrustThirdPartyDeclarationAccepted {
            self.declarations.noTrustThirdPartyDeclarationAccepted = v
        }
    }

    // MARK: - Error Handling

    private func presentError(_ error: Error) {
        self.errorMessage = self.mapToAppErrorMessage(error)
        self.showError = true
    }

    private func mapToAppErrorMessage(_ error: Error) -> String {
        if let appError = error as? AppError {
            return appError.errorDescription ?? "Ein Fehler ist aufgetreten."
        }
        return error.localizedDescription
    }
}
