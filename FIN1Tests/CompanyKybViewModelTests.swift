@testable import FIN1
import XCTest

@MainActor
final class CompanyKybViewModelTests: XCTestCase {

    // MARK: - Test-Only Mock

    /// Zero-latency, fully controllable mock for unit tests.
    private final class StubKybService: CompanyKybAPIServiceProtocol, @unchecked Sendable {
        var progressToReturn: CompanyKybProgress?
        var stepResponseToReturn: CompanyKybStepResponse?
        var errorToThrow: Error?
        private(set) var completedStepCalls: [(step: String, data: SavedCompanyKybData)] = []
        private(set) var partialSaveCalls: [(step: String, data: SavedCompanyKybData)] = []
        private(set) var positionOnlyCalls: [String] = []

        func getCompanyKybProgress() async throws -> CompanyKybProgress {
            if let error = errorToThrow { throw error }
            return self.progressToReturn ?? CompanyKybProgress(
                currentStep: nil, completedSteps: [],
                companyKybCompleted: false, companyKybStatus: nil, savedData: nil
            )
        }

        func completeStep(step: String, data: SavedCompanyKybData) async throws -> CompanyKybStepResponse {
            self.completedStepCalls.append((step, data))
            if let error = errorToThrow { throw error }
            return self.stepResponseToReturn ?? CompanyKybStepResponse(
                success: true, nextStep: nil,
                companyKybCompleted: false, companyKybStatus: "draft"
            )
        }

        func savePartialProgress(step: String, data: SavedCompanyKybData) async throws {
            self.partialSaveCalls.append((step, data))
            if let error = errorToThrow { throw error }
        }

        func savePartialProgressPositionOnly(step: String) async throws {
            self.positionOnlyCalls.append(step)
            if let error = errorToThrow { throw error }
        }
    }

    // MARK: - SUT + Dependencies

    private var service: StubKybService!
    private var sut: CompanyKybViewModel!

    override func setUp() {
        super.setUp()
        self.service = StubKybService()
        self.sut = CompanyKybViewModel(companyKybAPIService: self.service)
    }

    override func tearDown() {
        self.sut = nil
        self.service = nil
        super.tearDown()
    }

    // MARK: - Initial State

    func testInitialState() {
        XCTAssertEqual(self.sut.currentStep, .legalEntity)
        XCTAssertTrue(self.sut.completedSteps.isEmpty)
        XCTAssertFalse(self.sut.isLoading)
        XCTAssertFalse(self.sut.isResuming)
        XCTAssertFalse(self.sut.showError)
        XCTAssertFalse(self.sut.kybCompleted)
        XCTAssertFalse(self.sut.shouldDismiss)
        XCTAssertTrue(self.sut.isFirstStep)
        XCTAssertFalse(self.sut.isLastStep)
    }

    // MARK: - Progress

    func testProgress_FirstStep() {
        XCTAssertEqual(self.sut.progress, 1.0 / 8.0, accuracy: 0.001)
    }

    func testProgress_LastStep() {
        self.sut.currentStep = .submission
        XCTAssertEqual(self.sut.progress, 1.0, accuracy: 0.001)
    }

    // MARK: - canCompleteCurrentStep

    func testCanComplete_LegalEntity_EmptyFields() {
        XCTAssertFalse(self.sut.canCompleteCurrentStep)
    }

    func testCanComplete_LegalEntity_AllFilled() {
        self.fillLegalEntity()
        XCTAssertTrue(self.sut.canCompleteCurrentStep)
    }

    func testCanComplete_RegisteredAddress_EmptyFields() {
        self.sut.currentStep = .registeredAddress
        XCTAssertFalse(self.sut.canCompleteCurrentStep)
    }

    func testCanComplete_RegisteredAddress_RequiredFilled() {
        self.sut.currentStep = .registeredAddress
        self.sut.registeredAddress.streetAndNumber = "Musterstr. 1"
        self.sut.registeredAddress.postalCode = "10115"
        self.sut.registeredAddress.city = "Berlin"
        XCTAssertTrue(self.sut.canCompleteCurrentStep)
    }

    func testCanComplete_TaxCompliance_VatIdOnly() {
        self.sut.currentStep = .taxCompliance
        self.sut.taxCompliance.vatId = "DE123456789"
        XCTAssertTrue(self.sut.canCompleteCurrentStep)
    }

    func testCanComplete_TaxCompliance_NationalTaxOnly() {
        self.sut.currentStep = .taxCompliance
        self.sut.taxCompliance.nationalTaxNumber = "1234567890"
        XCTAssertTrue(self.sut.canCompleteCurrentStep)
    }

    func testCanComplete_TaxCompliance_NoVatDeclared() {
        self.sut.currentStep = .taxCompliance
        self.sut.taxCompliance.noVatIdDeclared = true
        XCTAssertTrue(self.sut.canCompleteCurrentStep)
    }

    func testCanComplete_TaxCompliance_AllEmpty() {
        self.sut.currentStep = .taxCompliance
        XCTAssertFalse(self.sut.canCompleteCurrentStep)
    }

    func testCanComplete_BeneficialOwners_WithCompleteUbo() {
        self.sut.currentStep = .beneficialOwners
        var ubo = BeneficialOwnerEntry()
        ubo.fullName = "Max Mustermann"
        ubo.dateOfBirth = "1990-01-15"
        ubo.nationality = "DE"
        self.sut.beneficialOwners.ubos = [ubo]
        XCTAssertTrue(self.sut.canCompleteCurrentStep)
    }

    func testCanComplete_BeneficialOwners_WithIncompleteUbo() {
        self.sut.currentStep = .beneficialOwners
        self.sut.beneficialOwners.ubos = [BeneficialOwnerEntry()]
        XCTAssertFalse(self.sut.canCompleteCurrentStep)
    }

    func testCanComplete_BeneficialOwners_NoUboFlagSet() {
        self.sut.currentStep = .beneficialOwners
        self.sut.beneficialOwners.noUboOver25Percent = true
        XCTAssertTrue(self.sut.canCompleteCurrentStep)
    }

    func testCanComplete_BeneficialOwners_Empty() {
        self.sut.currentStep = .beneficialOwners
        XCTAssertFalse(self.sut.canCompleteCurrentStep)
    }

    func testCanComplete_AuthorizedRepresentatives_WithCompleteEntry() {
        self.sut.currentStep = .authorizedRepresentatives
        var rep = RepresentativeEntry()
        rep.fullName = "Max Mustermann"
        rep.roleTitle = "CEO"
        self.sut.authorizedRepresentatives.representatives = [rep]
        XCTAssertTrue(self.sut.canCompleteCurrentStep)
    }

    func testCanComplete_AuthorizedRepresentatives_WithIncompleteEntry() {
        self.sut.currentStep = .authorizedRepresentatives
        self.sut.authorizedRepresentatives.representatives = [RepresentativeEntry()]
        XCTAssertFalse(self.sut.canCompleteCurrentStep)
    }

    func testCanComplete_AuthorizedRepresentatives_Empty() {
        self.sut.currentStep = .authorizedRepresentatives
        XCTAssertFalse(self.sut.canCompleteCurrentStep)
    }

    func testCanComplete_Documents_Acknowledged() {
        self.sut.currentStep = .documents
        self.sut.documents.documentsAcknowledged = true
        XCTAssertTrue(self.sut.canCompleteCurrentStep)
    }

    func testCanComplete_Declarations_AllAccepted() {
        self.sut.currentStep = .declarations
        self.sut.declarations.sanctionsSelfDeclarationAccepted = true
        self.sut.declarations.accuracyDeclarationAccepted = true
        self.sut.declarations.noTrustThirdPartyDeclarationAccepted = true
        XCTAssertTrue(self.sut.canCompleteCurrentStep)
    }

    func testCanComplete_Declarations_PartiallyAccepted() {
        self.sut.currentStep = .declarations
        self.sut.declarations.sanctionsSelfDeclarationAccepted = true
        self.sut.declarations.accuracyDeclarationAccepted = false
        self.sut.declarations.noTrustThirdPartyDeclarationAccepted = true
        XCTAssertFalse(self.sut.canCompleteCurrentStep)
    }

    func testCanComplete_Submission_Confirmed() {
        self.sut.currentStep = .submission
        self.sut.submission.confirmedSummary = true
        XCTAssertTrue(self.sut.canCompleteCurrentStep)
    }

    func testCanComplete_Submission_NotConfirmed() {
        self.sut.currentStep = .submission
        XCTAssertFalse(self.sut.canCompleteCurrentStep)
    }

    // MARK: - nextStep Validation Guard

    func testNextStep_DoesNotAdvance_WhenIncomplete() {
        self.sut.nextStep()
        XCTAssertEqual(self.sut.currentStep, .legalEntity)
        XCTAssertTrue(self.service.completedStepCalls.isEmpty)
    }

    // MARK: - previousStep

    func testPreviousStep_DoesNothing_OnFirstStep() {
        self.sut.previousStep()
        XCTAssertEqual(self.sut.currentStep, .legalEntity)
    }

    func testPreviousStep_NavigatesBack() {
        self.sut.currentStep = .registeredAddress
        self.sut.previousStep()
        XCTAssertEqual(self.sut.currentStep, .legalEntity)
    }

    func testPreviousStep_SavesPositionOnly() async throws {
        self.sut.currentStep = .taxCompliance
        self.sut.previousStep()
        try await Task.sleep(nanoseconds: 100_000_000) // let fire-and-forget Task run
        XCTAssertEqual(self.service.positionOnlyCalls, ["registered_address"])
    }

    // MARK: - Resume: Fresh Start

    func testResumeProgress_FreshStart() async {
        self.service.progressToReturn = CompanyKybProgress(
            currentStep: nil, completedSteps: [],
            companyKybCompleted: false, companyKybStatus: nil, savedData: nil
        )
        await self.sut.resumeProgress()
        XCTAssertFalse(self.sut.kybCompleted)
        XCTAssertFalse(self.sut.shouldDismiss)
        XCTAssertTrue(self.sut.completedSteps.isEmpty)
    }

    // MARK: - Resume: Already Completed

    func testResumeProgress_AlreadyCompleted_Dismisses() async {
        self.service.progressToReturn = CompanyKybProgress(
            currentStep: "submission", completedSteps: CompanyKybStep.allCases.map(\.backendKey),
            companyKybCompleted: true, companyKybStatus: "approved", savedData: nil
        )
        await self.sut.resumeProgress()
        XCTAssertTrue(self.sut.kybCompleted)
        XCTAssertTrue(self.sut.shouldDismiss)
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

        self.service.progressToReturn = CompanyKybProgress(
            currentStep: "registered_address",
            completedSteps: ["legal_entity", "registered_address"],
            companyKybCompleted: false, companyKybStatus: "draft",
            savedData: savedData
        )
        await self.sut.resumeProgress()

        XCTAssertEqual(self.sut.completedSteps, [.legalEntity, .registeredAddress])
        XCTAssertEqual(self.sut.currentStep, .taxCompliance)
        XCTAssertEqual(self.sut.legalEntity.legalName, "ACME GmbH")
        XCTAssertEqual(self.sut.legalEntity.registerNumber, "12345")
        XCTAssertEqual(self.sut.registeredAddress.streetAndNumber, "Teststr. 1")
        XCTAssertEqual(self.sut.registeredAddress.city, "Berlin")
    }

    // MARK: - Resume: Error

    func testResumeProgress_Error_ShowsAlert() async {
        self.service.errorToThrow = NSError(domain: "Test", code: 500, userInfo: [
            NSLocalizedDescriptionKey: "Server down"
        ])
        await self.sut.resumeProgress()
        XCTAssertTrue(self.sut.showError)
        XCTAssertTrue(self.sut.errorMessage.contains("Server down"))
    }

    // MARK: - completeAndAdvance (via nextStep)

    func testNextStep_CompletesStep_AdvancesViaResponse() async throws {
        self.fillLegalEntity()
        self.service.stepResponseToReturn = CompanyKybStepResponse(
            success: true, nextStep: "registered_address",
            companyKybCompleted: false, companyKybStatus: "draft"
        )
        self.sut.nextStep()
        try await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertEqual(self.sut.currentStep, .registeredAddress)
        XCTAssertTrue(self.sut.completedSteps.contains(.legalEntity))
        XCTAssertEqual(self.service.completedStepCalls.count, 1)
        XCTAssertEqual(self.service.completedStepCalls.first?.step, "legal_entity")
    }

    func testNextStep_CompletesStep_AdvancesViaFallback_WhenNoNextKey() async throws {
        self.fillLegalEntity()
        self.service.stepResponseToReturn = CompanyKybStepResponse(
            success: true, nextStep: nil,
            companyKybCompleted: false, companyKybStatus: "draft"
        )
        self.sut.nextStep()
        try await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertEqual(self.sut.currentStep, .registeredAddress)
    }

    func testNextStep_SubmissionCompletes_Dismisses() async throws {
        self.sut.currentStep = .submission
        self.sut.submission.confirmedSummary = true
        self.service.stepResponseToReturn = CompanyKybStepResponse(
            success: true, nextStep: nil,
            companyKybCompleted: true, companyKybStatus: "pending_review"
        )
        self.sut.nextStep()
        try await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertTrue(self.sut.kybCompleted)
        XCTAssertTrue(self.sut.shouldDismiss)
        XCTAssertEqual(self.sut.kybStatus, "pending_review")
    }

    func testNextStep_Error_ShowsAlert() async throws {
        self.fillLegalEntity()
        self.service.errorToThrow = AppError.network(.noConnection)
        self.sut.nextStep()
        try await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertTrue(self.sut.showError)
        XCTAssertEqual(self.sut.currentStep, .legalEntity)
        XCTAssertTrue(self.sut.completedSteps.isEmpty)
    }

    // MARK: - savePartialProgress

    func testSavePartialProgress_CallsService() async {
        self.sut.legalEntity.legalName = "Draft Co"
        await self.sut.savePartialProgress()
        XCTAssertEqual(self.service.partialSaveCalls.count, 1)
        XCTAssertEqual(self.service.partialSaveCalls.first?.step, "legal_entity")
        XCTAssertEqual(self.service.partialSaveCalls.first?.data.legalName, "Draft Co")
    }

    // MARK: - Data Mapping: toSavedData

    func testLegalEntityToSavedData_MapsCorrectly() {
        self.sut.legalEntity.legalName = "Test AG"
        self.sut.legalEntity.legalForm = "AG"
        self.sut.legalEntity.registerType = "HRB"
        self.sut.legalEntity.registerNumber = "99999"
        self.sut.legalEntity.registerCourt = "München"
        let data = self.sut.legalEntity.toSavedData()
        XCTAssertEqual(data.legalName, "Test AG")
        XCTAssertEqual(data.legalForm, "AG")
        XCTAssertEqual(data.registerNumber, "99999")
        XCTAssertNil(data.streetAndNumber)
    }

    func testDeclarationsToSavedData_PreservesAllFlags() {
        self.sut.declarations.sanctionsSelfDeclarationAccepted = true
        self.sut.declarations.accuracyDeclarationAccepted = true
        self.sut.declarations.noTrustThirdPartyDeclarationAccepted = true
        self.sut.declarations.isPoliticallyExposed = true
        self.sut.declarations.pepDetails = "Bürgermeister"
        let data = self.sut.declarations.toSavedData()
        XCTAssertEqual(data.sanctionsSelfDeclarationAccepted, true)
        XCTAssertEqual(data.accuracyDeclarationAccepted, true)
        XCTAssertEqual(data.noTrustThirdPartyDeclarationAccepted, true)
        XCTAssertEqual(data.isPoliticallyExposed, true)
        XCTAssertEqual(data.pepDetails, "Bürgermeister")
    }

    func testBeneficialOwnersToSavedData_NoUboFlag() {
        self.sut.beneficialOwners.noUboOver25Percent = true
        let data = self.sut.beneficialOwners.toSavedData()
        XCTAssertEqual(data.noUboOver25Percent, true)
        XCTAssertNil(data.ubos)
    }

    func testBeneficialOwnersToSavedData_WithUbos() {
        var ubo = BeneficialOwnerEntry()
        ubo.fullName = "Max Mustermann"
        ubo.ownershipPercent = 51.0
        self.sut.beneficialOwners.ubos = [ubo]
        let data = self.sut.beneficialOwners.toSavedData()
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
        self.service.errorToThrow = AppError.validation("Feld fehlt")
        self.service.progressToReturn = nil
        await self.sut.resumeProgress()
        XCTAssertTrue(self.sut.errorMessage.contains("Validation Error"))
    }

    func testErrorMapping_GenericNSError() async {
        self.service.errorToThrow = NSError(domain: "X", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "Netzwerk nicht erreichbar"
        ])
        await self.sut.resumeProgress()
        XCTAssertTrue(self.sut.errorMessage.contains("Netzwerk nicht erreichbar"))
    }

    // MARK: - Helpers

    private func fillLegalEntity() {
        self.sut.legalEntity.legalName = "Test GmbH"
        self.sut.legalEntity.legalForm = "GmbH"
        self.sut.legalEntity.registerType = "HRB"
        self.sut.legalEntity.registerNumber = "12345"
        self.sut.legalEntity.registerCourt = "Berlin"
    }
}
