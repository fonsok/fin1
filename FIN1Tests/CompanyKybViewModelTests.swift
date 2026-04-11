import XCTest
@testable import FIN1

@MainActor
final class CompanyKybViewModelTests: XCTestCase {

    // MARK: - Test-Only Mock

    /// Zero-latency, fully controllable mock for unit tests.
    private final class StubKybService: CompanyKybAPIServiceProtocol {
        var progressToReturn: CompanyKybProgress?
        var stepResponseToReturn: CompanyKybStepResponse?
        var errorToThrow: Error?
        private(set) var completedStepCalls: [(step: String, data: SavedCompanyKybData)] = []
        private(set) var partialSaveCalls: [(step: String, data: SavedCompanyKybData)] = []
        private(set) var positionOnlyCalls: [String] = []

        func getCompanyKybProgress() async throws -> CompanyKybProgress {
            if let error = errorToThrow { throw error }
            return progressToReturn ?? CompanyKybProgress(
                currentStep: nil, completedSteps: [],
                companyKybCompleted: false, companyKybStatus: nil, savedData: nil
            )
        }

        func completeStep(step: String, data: SavedCompanyKybData) async throws -> CompanyKybStepResponse {
            completedStepCalls.append((step, data))
            if let error = errorToThrow { throw error }
            return stepResponseToReturn ?? CompanyKybStepResponse(
                success: true, nextStep: nil,
                companyKybCompleted: false, companyKybStatus: "draft"
            )
        }

        func savePartialProgress(step: String, data: SavedCompanyKybData) async throws {
            partialSaveCalls.append((step, data))
            if let error = errorToThrow { throw error }
        }

        func savePartialProgressPositionOnly(step: String) async throws {
            positionOnlyCalls.append(step)
            if let error = errorToThrow { throw error }
        }
    }

    // MARK: - SUT + Dependencies

    private var service: StubKybService!
    private var sut: CompanyKybViewModel!

    override func setUp() {
        super.setUp()
        service = StubKybService()
        sut = CompanyKybViewModel(companyKybAPIService: service)
    }

    override func tearDown() {
        sut = nil
        service = nil
        super.tearDown()
    }

    // MARK: - Initial State

    func testInitialState() {
        XCTAssertEqual(sut.currentStep, .legalEntity)
        XCTAssertTrue(sut.completedSteps.isEmpty)
        XCTAssertFalse(sut.isLoading)
        XCTAssertFalse(sut.isResuming)
        XCTAssertFalse(sut.showError)
        XCTAssertFalse(sut.kybCompleted)
        XCTAssertFalse(sut.shouldDismiss)
        XCTAssertTrue(sut.isFirstStep)
        XCTAssertFalse(sut.isLastStep)
    }

    // MARK: - Progress

    func testProgress_FirstStep() {
        XCTAssertEqual(sut.progress, 1.0 / 8.0, accuracy: 0.001)
    }

    func testProgress_LastStep() {
        sut.currentStep = .submission
        XCTAssertEqual(sut.progress, 1.0, accuracy: 0.001)
    }

    // MARK: - canCompleteCurrentStep

    func testCanComplete_LegalEntity_EmptyFields() {
        XCTAssertFalse(sut.canCompleteCurrentStep)
    }

    func testCanComplete_LegalEntity_AllFilled() {
        fillLegalEntity()
        XCTAssertTrue(sut.canCompleteCurrentStep)
    }

    func testCanComplete_RegisteredAddress_EmptyFields() {
        sut.currentStep = .registeredAddress
        XCTAssertFalse(sut.canCompleteCurrentStep)
    }

    func testCanComplete_RegisteredAddress_RequiredFilled() {
        sut.currentStep = .registeredAddress
        sut.registeredAddress.streetAndNumber = "Musterstr. 1"
        sut.registeredAddress.postalCode = "10115"
        sut.registeredAddress.city = "Berlin"
        XCTAssertTrue(sut.canCompleteCurrentStep)
    }

    func testCanComplete_TaxCompliance_VatIdOnly() {
        sut.currentStep = .taxCompliance
        sut.taxCompliance.vatId = "DE123456789"
        XCTAssertTrue(sut.canCompleteCurrentStep)
    }

    func testCanComplete_TaxCompliance_NationalTaxOnly() {
        sut.currentStep = .taxCompliance
        sut.taxCompliance.nationalTaxNumber = "1234567890"
        XCTAssertTrue(sut.canCompleteCurrentStep)
    }

    func testCanComplete_TaxCompliance_NoVatDeclared() {
        sut.currentStep = .taxCompliance
        sut.taxCompliance.noVatIdDeclared = true
        XCTAssertTrue(sut.canCompleteCurrentStep)
    }

    func testCanComplete_TaxCompliance_AllEmpty() {
        sut.currentStep = .taxCompliance
        XCTAssertFalse(sut.canCompleteCurrentStep)
    }

    func testCanComplete_BeneficialOwners_WithCompleteUbo() {
        sut.currentStep = .beneficialOwners
        var ubo = BeneficialOwnerEntry()
        ubo.fullName = "Max Mustermann"
        ubo.dateOfBirth = "1990-01-15"
        ubo.nationality = "DE"
        sut.beneficialOwners.ubos = [ubo]
        XCTAssertTrue(sut.canCompleteCurrentStep)
    }

    func testCanComplete_BeneficialOwners_WithIncompleteUbo() {
        sut.currentStep = .beneficialOwners
        sut.beneficialOwners.ubos = [BeneficialOwnerEntry()]
        XCTAssertFalse(sut.canCompleteCurrentStep)
    }

    func testCanComplete_BeneficialOwners_NoUboFlagSet() {
        sut.currentStep = .beneficialOwners
        sut.beneficialOwners.noUboOver25Percent = true
        XCTAssertTrue(sut.canCompleteCurrentStep)
    }

    func testCanComplete_BeneficialOwners_Empty() {
        sut.currentStep = .beneficialOwners
        XCTAssertFalse(sut.canCompleteCurrentStep)
    }

    func testCanComplete_AuthorizedRepresentatives_WithCompleteEntry() {
        sut.currentStep = .authorizedRepresentatives
        var rep = RepresentativeEntry()
        rep.fullName = "Max Mustermann"
        rep.roleTitle = "CEO"
        sut.authorizedRepresentatives.representatives = [rep]
        XCTAssertTrue(sut.canCompleteCurrentStep)
    }

    func testCanComplete_AuthorizedRepresentatives_WithIncompleteEntry() {
        sut.currentStep = .authorizedRepresentatives
        sut.authorizedRepresentatives.representatives = [RepresentativeEntry()]
        XCTAssertFalse(sut.canCompleteCurrentStep)
    }

    func testCanComplete_AuthorizedRepresentatives_Empty() {
        sut.currentStep = .authorizedRepresentatives
        XCTAssertFalse(sut.canCompleteCurrentStep)
    }

    func testCanComplete_Documents_Acknowledged() {
        sut.currentStep = .documents
        sut.documents.documentsAcknowledged = true
        XCTAssertTrue(sut.canCompleteCurrentStep)
    }

    func testCanComplete_Declarations_AllAccepted() {
        sut.currentStep = .declarations
        sut.declarations.sanctionsSelfDeclarationAccepted = true
        sut.declarations.accuracyDeclarationAccepted = true
        sut.declarations.noTrustThirdPartyDeclarationAccepted = true
        XCTAssertTrue(sut.canCompleteCurrentStep)
    }

    func testCanComplete_Declarations_PartiallyAccepted() {
        sut.currentStep = .declarations
        sut.declarations.sanctionsSelfDeclarationAccepted = true
        sut.declarations.accuracyDeclarationAccepted = false
        sut.declarations.noTrustThirdPartyDeclarationAccepted = true
        XCTAssertFalse(sut.canCompleteCurrentStep)
    }

    func testCanComplete_Submission_Confirmed() {
        sut.currentStep = .submission
        sut.submission.confirmedSummary = true
        XCTAssertTrue(sut.canCompleteCurrentStep)
    }

    func testCanComplete_Submission_NotConfirmed() {
        sut.currentStep = .submission
        XCTAssertFalse(sut.canCompleteCurrentStep)
    }

    // MARK: - nextStep Validation Guard

    func testNextStep_DoesNotAdvance_WhenIncomplete() {
        sut.nextStep()
        XCTAssertEqual(sut.currentStep, .legalEntity)
        XCTAssertTrue(service.completedStepCalls.isEmpty)
    }

    // MARK: - previousStep

    func testPreviousStep_DoesNothing_OnFirstStep() {
        sut.previousStep()
        XCTAssertEqual(sut.currentStep, .legalEntity)
    }

    func testPreviousStep_NavigatesBack() {
        sut.currentStep = .registeredAddress
        sut.previousStep()
        XCTAssertEqual(sut.currentStep, .legalEntity)
    }

    func testPreviousStep_SavesPositionOnly() async throws {
        sut.currentStep = .taxCompliance
        sut.previousStep()
        try await Task.sleep(nanoseconds: 100_000_000) // let fire-and-forget Task run
        XCTAssertEqual(service.positionOnlyCalls, ["registered_address"])
    }

    // MARK: - Resume: Fresh Start

    func testResumeProgress_FreshStart() async {
        service.progressToReturn = CompanyKybProgress(
            currentStep: nil, completedSteps: [],
            companyKybCompleted: false, companyKybStatus: nil, savedData: nil
        )
        await sut.resumeProgress()
        XCTAssertFalse(sut.kybCompleted)
        XCTAssertFalse(sut.shouldDismiss)
        XCTAssertTrue(sut.completedSteps.isEmpty)
    }

    // MARK: - Resume: Already Completed

    func testResumeProgress_AlreadyCompleted_Dismisses() async {
        service.progressToReturn = CompanyKybProgress(
            currentStep: "submission", completedSteps: CompanyKybStep.allCases.map(\.backendKey),
            companyKybCompleted: true, companyKybStatus: "approved", savedData: nil
        )
        await sut.resumeProgress()
        XCTAssertTrue(sut.kybCompleted)
        XCTAssertTrue(sut.shouldDismiss)
    }

    // MARK: - Resume: Mid-Progress

    func testResumeProgress_MidProgress_RestoresStepAndData() async {
        let savedData = SavedCompanyKybData(
            legalName: "ACME GmbH", legalForm: "GmbH",
            registerType: "HRB", registerNumber: "12345",
            registerCourt: "Berlin", incorporationCountry: "DE",
            notRegisteredReason: nil,
            streetAndNumber: "Teststr. 1", postalCode: "10115",
            city: "Berlin", country: "DE",
            businessStreetAndNumber: nil, businessPostalCode: nil,
            businessCity: nil, businessCountry: nil,
            vatId: nil, nationalTaxNumber: nil,
            economicIdentificationNumber: nil, noVatIdDeclared: nil,
            ubos: nil, noUboOver25Percent: nil,
            representatives: nil, appAccountHolderIsRepresentative: nil,
            tradeRegisterExtractReference: nil, documentManifest: nil,
            documentsAcknowledged: nil,
            isPoliticallyExposed: nil, pepDetails: nil,
            sanctionsSelfDeclarationAccepted: nil,
            accuracyDeclarationAccepted: nil,
            noTrustThirdPartyDeclarationAccepted: nil,
            confirmedSummary: nil, companyFourEyesRequestId: nil,
            _positionOnly: nil
        )

        service.progressToReturn = CompanyKybProgress(
            currentStep: "registered_address",
            completedSteps: ["legal_entity", "registered_address"],
            companyKybCompleted: false, companyKybStatus: "draft",
            savedData: savedData
        )
        await sut.resumeProgress()

        XCTAssertEqual(sut.completedSteps, [.legalEntity, .registeredAddress])
        XCTAssertEqual(sut.currentStep, .taxCompliance)
        XCTAssertEqual(sut.legalEntity.legalName, "ACME GmbH")
        XCTAssertEqual(sut.legalEntity.registerNumber, "12345")
        XCTAssertEqual(sut.registeredAddress.streetAndNumber, "Teststr. 1")
        XCTAssertEqual(sut.registeredAddress.city, "Berlin")
    }

    // MARK: - Resume: Error

    func testResumeProgress_Error_ShowsAlert() async {
        service.errorToThrow = NSError(domain: "Test", code: 500, userInfo: [
            NSLocalizedDescriptionKey: "Server down"
        ])
        await sut.resumeProgress()
        XCTAssertTrue(sut.showError)
        XCTAssertTrue(sut.errorMessage.contains("Server down"))
    }

    // MARK: - completeAndAdvance (via nextStep)

    func testNextStep_CompletesStep_AdvancesViaResponse() async throws {
        fillLegalEntity()
        service.stepResponseToReturn = CompanyKybStepResponse(
            success: true, nextStep: "registered_address",
            companyKybCompleted: false, companyKybStatus: "draft"
        )
        sut.nextStep()
        try await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertEqual(sut.currentStep, .registeredAddress)
        XCTAssertTrue(sut.completedSteps.contains(.legalEntity))
        XCTAssertEqual(service.completedStepCalls.count, 1)
        XCTAssertEqual(service.completedStepCalls.first?.step, "legal_entity")
    }

    func testNextStep_CompletesStep_AdvancesViaFallback_WhenNoNextKey() async throws {
        fillLegalEntity()
        service.stepResponseToReturn = CompanyKybStepResponse(
            success: true, nextStep: nil,
            companyKybCompleted: false, companyKybStatus: "draft"
        )
        sut.nextStep()
        try await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertEqual(sut.currentStep, .registeredAddress)
    }

    func testNextStep_SubmissionCompletes_Dismisses() async throws {
        sut.currentStep = .submission
        sut.submission.confirmedSummary = true
        service.stepResponseToReturn = CompanyKybStepResponse(
            success: true, nextStep: nil,
            companyKybCompleted: true, companyKybStatus: "pending_review"
        )
        sut.nextStep()
        try await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertTrue(sut.kybCompleted)
        XCTAssertTrue(sut.shouldDismiss)
        XCTAssertEqual(sut.kybStatus, "pending_review")
    }

    func testNextStep_Error_ShowsAlert() async throws {
        fillLegalEntity()
        service.errorToThrow = AppError.network(.noConnection)
        sut.nextStep()
        try await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertTrue(sut.showError)
        XCTAssertEqual(sut.currentStep, .legalEntity)
        XCTAssertTrue(sut.completedSteps.isEmpty)
    }

    // MARK: - savePartialProgress

    func testSavePartialProgress_CallsService() async {
        sut.legalEntity.legalName = "Draft Co"
        await sut.savePartialProgress()
        XCTAssertEqual(service.partialSaveCalls.count, 1)
        XCTAssertEqual(service.partialSaveCalls.first?.step, "legal_entity")
        XCTAssertEqual(service.partialSaveCalls.first?.data.legalName, "Draft Co")
    }

    // MARK: - Data Mapping: toSavedData

    func testLegalEntityToSavedData_MapsCorrectly() {
        sut.legalEntity.legalName = "Test AG"
        sut.legalEntity.legalForm = "AG"
        sut.legalEntity.registerType = "HRB"
        sut.legalEntity.registerNumber = "99999"
        sut.legalEntity.registerCourt = "München"
        let data = sut.legalEntity.toSavedData()
        XCTAssertEqual(data.legalName, "Test AG")
        XCTAssertEqual(data.legalForm, "AG")
        XCTAssertEqual(data.registerNumber, "99999")
        XCTAssertNil(data.streetAndNumber)
    }

    func testDeclarationsToSavedData_PreservesAllFlags() {
        sut.declarations.sanctionsSelfDeclarationAccepted = true
        sut.declarations.accuracyDeclarationAccepted = true
        sut.declarations.noTrustThirdPartyDeclarationAccepted = true
        sut.declarations.isPoliticallyExposed = true
        sut.declarations.pepDetails = "Bürgermeister"
        let data = sut.declarations.toSavedData()
        XCTAssertEqual(data.sanctionsSelfDeclarationAccepted, true)
        XCTAssertEqual(data.accuracyDeclarationAccepted, true)
        XCTAssertEqual(data.noTrustThirdPartyDeclarationAccepted, true)
        XCTAssertEqual(data.isPoliticallyExposed, true)
        XCTAssertEqual(data.pepDetails, "Bürgermeister")
    }

    func testBeneficialOwnersToSavedData_NoUboFlag() {
        sut.beneficialOwners.noUboOver25Percent = true
        let data = sut.beneficialOwners.toSavedData()
        XCTAssertEqual(data.noUboOver25Percent, true)
        XCTAssertNil(data.ubos)
    }

    func testBeneficialOwnersToSavedData_WithUbos() {
        var ubo = BeneficialOwnerEntry()
        ubo.fullName = "Max Mustermann"
        ubo.ownershipPercent = 51.0
        sut.beneficialOwners.ubos = [ubo]
        let data = sut.beneficialOwners.toSavedData()
        XCTAssertEqual(data.ubos?.count, 1)
        XCTAssertEqual(data.ubos?.first?.fullName, "Max Mustermann")
        XCTAssertEqual(data.ubos?.first?.ownershipPercent, 51.0)
    }

    // MARK: - CompanyKybStep Model

    func testStepBackendKeys() {
        XCTAssertEqual(CompanyKybStep.legalEntity.backendKey, "legal_entity")
        XCTAssertEqual(CompanyKybStep.submission.backendKey, "submission")
    }

    func testStepFromBackendKey_Valid() {
        XCTAssertEqual(CompanyKybStep.fromBackendKey("tax_compliance"), .taxCompliance)
    }

    func testStepFromBackendKey_Invalid() {
        XCTAssertNil(CompanyKybStep.fromBackendKey("nonexistent"))
    }

    func testStepNavigation_Next() {
        XCTAssertEqual(CompanyKybStep.legalEntity.next, .registeredAddress)
        XCTAssertNil(CompanyKybStep.submission.next)
    }

    func testStepNavigation_Previous() {
        XCTAssertNil(CompanyKybStep.legalEntity.previous)
        XCTAssertEqual(CompanyKybStep.submission.previous, .declarations)
    }

    func testTotalSteps() {
        XCTAssertEqual(CompanyKybStep.totalSteps, 8)
    }

    // MARK: - Error Mapping

    func testErrorMapping_AppError() async {
        service.errorToThrow = AppError.validation("Feld fehlt")
        service.progressToReturn = nil
        await sut.resumeProgress()
        XCTAssertTrue(sut.errorMessage.contains("Validation Error"))
    }

    func testErrorMapping_GenericNSError() async {
        service.errorToThrow = NSError(domain: "X", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "Netzwerk nicht erreichbar"
        ])
        await sut.resumeProgress()
        XCTAssertTrue(sut.errorMessage.contains("Netzwerk nicht erreichbar"))
    }

    // MARK: - Helpers

    private func fillLegalEntity() {
        sut.legalEntity.legalName = "Test GmbH"
        sut.legalEntity.legalForm = "GmbH"
        sut.legalEntity.registerType = "HRB"
        sut.legalEntity.registerNumber = "12345"
        sut.legalEntity.registerCourt = "Berlin"
    }
}
