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
        Double(currentStep.rawValue) / Double(CompanyKybStep.totalSteps)
    }

    var isFirstStep: Bool { currentStep == .legalEntity }
    var isLastStep: Bool { currentStep == .submission }

    var currentStepNumber: Int { currentStep.rawValue }

    var canCompleteCurrentStep: Bool {
        switch currentStep {
        case .legalEntity:
            return !legalEntity.legalName.isEmpty && !legalEntity.legalForm.isEmpty
                && !legalEntity.registerType.isEmpty && !legalEntity.registerNumber.isEmpty
                && !legalEntity.registerCourt.isEmpty
        case .registeredAddress:
            return !registeredAddress.streetAndNumber.isEmpty
                && !registeredAddress.postalCode.isEmpty && !registeredAddress.city.isEmpty
        case .taxCompliance:
            return !taxCompliance.vatId.isEmpty || !taxCompliance.nationalTaxNumber.isEmpty
                || taxCompliance.noVatIdDeclared
        case .beneficialOwners:
            if beneficialOwners.noUboOver25Percent { return true }
            return !beneficialOwners.ubos.isEmpty && beneficialOwners.ubos.allSatisfy { ubo in
                !ubo.fullName.isEmpty && !ubo.dateOfBirth.isEmpty && !ubo.nationality.isEmpty
            }
        case .authorizedRepresentatives:
            return !authorizedRepresentatives.representatives.isEmpty
                && authorizedRepresentatives.representatives.allSatisfy { rep in
                    !rep.fullName.isEmpty && !rep.roleTitle.isEmpty
                }
        case .documents:
            return documents.documentsAcknowledged
        case .declarations:
            return declarations.sanctionsSelfDeclarationAccepted
                && declarations.accuracyDeclarationAccepted
                && declarations.noTrustThirdPartyDeclarationAccepted
        case .submission:
            return submission.confirmedSummary
        }
    }

    // MARK: - Navigation

    func nextStep() {
        guard canCompleteCurrentStep else { return }
        Task { await completeAndAdvance() }
    }

    func previousStep() {
        guard let prev = currentStep.previous else { return }
        withAnimation(.easeInOut(duration: 0.3)) { currentStep = prev }
        Task { try? await companyKybAPIService.savePartialProgressPositionOnly(step: prev.backendKey) }
    }

    // MARK: - Resume

    func resumeProgress() async {
        isResuming = true
        defer { isResuming = false }
        do {
            let progress = try await companyKybAPIService.getCompanyKybProgress()
            kybCompleted = progress.companyKybCompleted
            kybStatus = progress.companyKybStatus
            completedSteps = Set(progress.completedSteps.compactMap(CompanyKybStep.fromBackendKey))

            if kybCompleted {
                shouldDismiss = true
                return
            }

            restoreFormData(from: progress.savedData)

            if let stepKey = progress.currentStep,
               let step = CompanyKybStep.fromBackendKey(stepKey) {
                currentStep = step.next ?? step
            }
        } catch {
            presentError(error)
        }
    }

    // MARK: - Complete & Advance

    private func completeAndAdvance() async {
        isLoading = true
        defer { isLoading = false }

        let stepData = savedDataForCurrentStep()

        do {
            let response = try await companyKybAPIService.completeStep(
                step: currentStep.backendKey,
                data: stepData
            )
            completedSteps.insert(currentStep)
            kybCompleted = response.companyKybCompleted ?? false
            kybStatus = response.companyKybStatus

            if kybCompleted {
                shouldDismiss = true
                return
            }

            if let nextKey = response.nextStep,
               let next = CompanyKybStep.fromBackendKey(nextKey) {
                withAnimation(.easeInOut(duration: 0.3)) { currentStep = next }
            } else if let next = currentStep.next {
                withAnimation(.easeInOut(duration: 0.3)) { currentStep = next }
            }
        } catch {
            presentError(error)
        }
    }

    func savePartialProgress() async {
        let stepData = savedDataForCurrentStep()
        try? await companyKybAPIService.savePartialProgress(
            step: currentStep.backendKey,
            data: stepData
        )
    }

    // MARK: - Data Mapping

    private func savedDataForCurrentStep() -> SavedCompanyKybData {
        switch currentStep {
        case .legalEntity: return legalEntity.toSavedData()
        case .registeredAddress: return registeredAddress.toSavedData()
        case .taxCompliance: return taxCompliance.toSavedData()
        case .beneficialOwners: return beneficialOwners.toSavedData()
        case .authorizedRepresentatives: return authorizedRepresentatives.toSavedData()
        case .documents: return documents.toSavedData()
        case .declarations: return declarations.toSavedData()
        case .submission: return submission.toSavedData()
        }
    }

    private func restoreFormData(from data: SavedCompanyKybData?) {
        guard let data else { return }

        if let v = data.legalName { legalEntity.legalName = v }
        if let v = data.legalForm { legalEntity.legalForm = v }
        if let v = data.registerType { legalEntity.registerType = v }
        if let v = data.registerNumber { legalEntity.registerNumber = v }
        if let v = data.registerCourt { legalEntity.registerCourt = v }
        if let v = data.incorporationCountry { legalEntity.incorporationCountry = v }
        if let v = data.notRegisteredReason { legalEntity.notRegisteredReason = v }

        if let v = data.streetAndNumber { registeredAddress.streetAndNumber = v }
        if let v = data.postalCode { registeredAddress.postalCode = v }
        if let v = data.city { registeredAddress.city = v }
        if let v = data.country { registeredAddress.country = v }
        if let v = data.businessStreetAndNumber { registeredAddress.businessStreetAndNumber = v }

        if let v = data.vatId { taxCompliance.vatId = v }
        if let v = data.nationalTaxNumber { taxCompliance.nationalTaxNumber = v }
        if let v = data.economicIdentificationNumber { taxCompliance.economicIdentificationNumber = v }
        if let v = data.noVatIdDeclared { taxCompliance.noVatIdDeclared = v }

        if let v = data.noUboOver25Percent { beneficialOwners.noUboOver25Percent = v }
        if let ubos = data.ubos {
            beneficialOwners.ubos = ubos.map { ubo in
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
            authorizedRepresentatives.appAccountHolderIsRepresentative = v
        }
        if let reps = data.representatives {
            authorizedRepresentatives.representatives = reps.map { rep in
                var entry = RepresentativeEntry()
                entry.fullName = rep.fullName ?? ""
                entry.roleTitle = rep.roleTitle ?? ""
                entry.signingAuthority = rep.signingAuthority ?? false
                return entry
            }
        }

        if let v = data.documentsAcknowledged { documents.documentsAcknowledged = v }
        if let v = data.tradeRegisterExtractReference { documents.tradeRegisterExtractReference = v }

        if let v = data.isPoliticallyExposed { declarations.isPoliticallyExposed = v }
        if let v = data.pepDetails { declarations.pepDetails = v }
        if let v = data.sanctionsSelfDeclarationAccepted { declarations.sanctionsSelfDeclarationAccepted = v }
        if let v = data.accuracyDeclarationAccepted { declarations.accuracyDeclarationAccepted = v }
        if let v = data.noTrustThirdPartyDeclarationAccepted {
            declarations.noTrustThirdPartyDeclarationAccepted = v
        }
    }

    // MARK: - Error Handling

    private func presentError(_ error: Error) {
        errorMessage = mapToAppErrorMessage(error)
        showError = true
    }

    private func mapToAppErrorMessage(_ error: Error) -> String {
        if let appError = error as? AppError {
            return appError.errorDescription ?? "Ein Fehler ist aufgetreten."
        }
        return error.localizedDescription
    }
}
