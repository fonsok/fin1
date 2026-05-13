import Foundation

// MARK: - Per-Step Form Data Structs

struct LegalEntityFormData: Sendable {
    var legalName = ""
    var legalForm = ""
    var registerType = ""
    var registerNumber = ""
    var registerCourt = ""
    var incorporationCountry = "DE"
    var notRegisteredReason = ""
}

struct RegisteredAddressFormData: Sendable {
    var streetAndNumber = ""
    var postalCode = ""
    var city = ""
    var country = "DE"
    var businessStreetAndNumber = ""
    var businessPostalCode = ""
    var businessCity = ""
    var businessCountry = ""
    var showBusinessAddress = false
}

struct TaxComplianceFormData: Sendable {
    var vatId = ""
    var nationalTaxNumber = ""
    var economicIdentificationNumber = ""
    var noVatIdDeclared = false
}

struct BeneficialOwnerEntry: Identifiable, Sendable {
    let id: String
    var fullName = ""
    var dateOfBirth = ""
    var nationality = ""
    var ownershipPercent: Double?
    var directOrIndirect = "direct"

    init(id: String = UUID().uuidString) {
        self.id = id
    }
}

struct BeneficialOwnersFormData: Sendable {
    var ubos: [BeneficialOwnerEntry] = []
    var noUboOver25Percent = false
}

struct RepresentativeEntry: Identifiable, Sendable {
    let id: String
    var fullName = ""
    var roleTitle = ""
    var signingAuthority = false

    init(id: String = UUID().uuidString) {
        self.id = id
    }
}

struct AuthorizedRepresentativesFormData: Sendable {
    var representatives: [RepresentativeEntry] = []
    var appAccountHolderIsRepresentative = false
}

struct DocumentManifestEntry: Identifiable, Sendable {
    let id: String
    var documentType = ""
    var referenceId = ""

    init(id: String = UUID().uuidString) {
        self.id = id
    }
}

struct DocumentsFormData: Sendable {
    var tradeRegisterExtractReference = ""
    var documentManifest: [DocumentManifestEntry] = []
    var documentsAcknowledged = false
}

struct DeclarationsFormData: Sendable {
    var isPoliticallyExposed = false
    var pepDetails = ""
    var sanctionsSelfDeclarationAccepted = false
    var accuracyDeclarationAccepted = false
    var noTrustThirdPartyDeclarationAccepted = false
}

struct SubmissionFormData: Sendable {
    var confirmedSummary = false
    var companyFourEyesRequestId = ""
}

// MARK: - Conversion to API DTO

extension LegalEntityFormData {
    func toSavedData() -> SavedCompanyKybData {
        SavedCompanyKybData(
            legalName: self.legalName, legalForm: self.legalForm,
            registerType: self.registerType, registerNumber: self.registerNumber,
            registerCourt: self.registerCourt, incorporationCountry: self.incorporationCountry,
            notRegisteredReason: self.notRegisteredReason.isEmpty ? nil : self.notRegisteredReason,
            streetAndNumber: nil, postalCode: nil, city: nil, country: nil,
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
    }
}

extension RegisteredAddressFormData {
    func toSavedData() -> SavedCompanyKybData {
        SavedCompanyKybData(
            legalName: nil, legalForm: nil, registerType: nil,
            registerNumber: nil, registerCourt: nil, incorporationCountry: nil,
            notRegisteredReason: nil,
            streetAndNumber: self.streetAndNumber, postalCode: self.postalCode,
            city: self.city, country: self.country,
            businessStreetAndNumber: self.businessStreetAndNumber.isEmpty ? nil : self.businessStreetAndNumber,
            businessPostalCode: self.businessPostalCode.isEmpty ? nil : self.businessPostalCode,
            businessCity: self.businessCity.isEmpty ? nil : self.businessCity,
            businessCountry: self.businessCountry.isEmpty ? nil : self.businessCountry,
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
    }
}

extension TaxComplianceFormData {
    func toSavedData() -> SavedCompanyKybData {
        SavedCompanyKybData(
            legalName: nil, legalForm: nil, registerType: nil,
            registerNumber: nil, registerCourt: nil, incorporationCountry: nil,
            notRegisteredReason: nil,
            streetAndNumber: nil, postalCode: nil, city: nil, country: nil,
            businessStreetAndNumber: nil, businessPostalCode: nil,
            businessCity: nil, businessCountry: nil,
            vatId: self.vatId.isEmpty ? nil : self.vatId,
            nationalTaxNumber: self.nationalTaxNumber.isEmpty ? nil : self.nationalTaxNumber,
            economicIdentificationNumber: self.economicIdentificationNumber.isEmpty ? nil : self.economicIdentificationNumber,
            noVatIdDeclared: self.noVatIdDeclared ? true : nil,
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
    }
}

extension BeneficialOwnersFormData {
    func toSavedData() -> SavedCompanyKybData {
        let uboList: [SavedCompanyKybUbo]? = self.noUboOver25Percent ? nil : self.ubos.map {
            SavedCompanyKybUbo(
                fullName: $0.fullName, dateOfBirth: $0.dateOfBirth,
                nationality: $0.nationality,
                ownershipPercent: $0.ownershipPercent,
                directOrIndirect: $0.directOrIndirect
            )
        }
        return SavedCompanyKybData(
            legalName: nil, legalForm: nil, registerType: nil,
            registerNumber: nil, registerCourt: nil, incorporationCountry: nil,
            notRegisteredReason: nil,
            streetAndNumber: nil, postalCode: nil, city: nil, country: nil,
            businessStreetAndNumber: nil, businessPostalCode: nil,
            businessCity: nil, businessCountry: nil,
            vatId: nil, nationalTaxNumber: nil,
            economicIdentificationNumber: nil, noVatIdDeclared: nil,
            ubos: uboList, noUboOver25Percent: self.noUboOver25Percent ? true : nil,
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
    }
}

extension AuthorizedRepresentativesFormData {
    func toSavedData() -> SavedCompanyKybData {
        let repList = self.representatives.map {
            SavedCompanyKybRepresentative(
                fullName: $0.fullName, roleTitle: $0.roleTitle,
                signingAuthority: $0.signingAuthority
            )
        }
        return SavedCompanyKybData(
            legalName: nil, legalForm: nil, registerType: nil,
            registerNumber: nil, registerCourt: nil, incorporationCountry: nil,
            notRegisteredReason: nil,
            streetAndNumber: nil, postalCode: nil, city: nil, country: nil,
            businessStreetAndNumber: nil, businessPostalCode: nil,
            businessCity: nil, businessCountry: nil,
            vatId: nil, nationalTaxNumber: nil,
            economicIdentificationNumber: nil, noVatIdDeclared: nil,
            ubos: nil, noUboOver25Percent: nil,
            representatives: repList,
            appAccountHolderIsRepresentative: self.appAccountHolderIsRepresentative ? true : nil,
            tradeRegisterExtractReference: nil, documentManifest: nil,
            documentsAcknowledged: nil,
            isPoliticallyExposed: nil, pepDetails: nil,
            sanctionsSelfDeclarationAccepted: nil,
            accuracyDeclarationAccepted: nil,
            noTrustThirdPartyDeclarationAccepted: nil,
            confirmedSummary: nil, companyFourEyesRequestId: nil,
            _positionOnly: nil
        )
    }
}

extension DocumentsFormData {
    func toSavedData() -> SavedCompanyKybData {
        let manifest: [SavedCompanyKybDocumentManifestEntry]? = self.documentManifest.isEmpty ? nil : self.documentManifest.map {
            SavedCompanyKybDocumentManifestEntry(documentType: $0.documentType, referenceId: $0.referenceId)
        }
        return SavedCompanyKybData(
            legalName: nil, legalForm: nil, registerType: nil,
            registerNumber: nil, registerCourt: nil, incorporationCountry: nil,
            notRegisteredReason: nil,
            streetAndNumber: nil, postalCode: nil, city: nil, country: nil,
            businessStreetAndNumber: nil, businessPostalCode: nil,
            businessCity: nil, businessCountry: nil,
            vatId: nil, nationalTaxNumber: nil,
            economicIdentificationNumber: nil, noVatIdDeclared: nil,
            ubos: nil, noUboOver25Percent: nil,
            representatives: nil, appAccountHolderIsRepresentative: nil,
            tradeRegisterExtractReference: self.tradeRegisterExtractReference.isEmpty ? nil : self.tradeRegisterExtractReference,
            documentManifest: manifest,
            documentsAcknowledged: true,
            isPoliticallyExposed: nil, pepDetails: nil,
            sanctionsSelfDeclarationAccepted: nil,
            accuracyDeclarationAccepted: nil,
            noTrustThirdPartyDeclarationAccepted: nil,
            confirmedSummary: nil, companyFourEyesRequestId: nil,
            _positionOnly: nil
        )
    }
}

extension DeclarationsFormData {
    func toSavedData() -> SavedCompanyKybData {
        SavedCompanyKybData(
            legalName: nil, legalForm: nil, registerType: nil,
            registerNumber: nil, registerCourt: nil, incorporationCountry: nil,
            notRegisteredReason: nil,
            streetAndNumber: nil, postalCode: nil, city: nil, country: nil,
            businessStreetAndNumber: nil, businessPostalCode: nil,
            businessCity: nil, businessCountry: nil,
            vatId: nil, nationalTaxNumber: nil,
            economicIdentificationNumber: nil, noVatIdDeclared: nil,
            ubos: nil, noUboOver25Percent: nil,
            representatives: nil, appAccountHolderIsRepresentative: nil,
            tradeRegisterExtractReference: nil, documentManifest: nil,
            documentsAcknowledged: nil,
            isPoliticallyExposed: self.isPoliticallyExposed,
            pepDetails: self.pepDetails.isEmpty ? nil : self.pepDetails,
            sanctionsSelfDeclarationAccepted: self.sanctionsSelfDeclarationAccepted,
            accuracyDeclarationAccepted: self.accuracyDeclarationAccepted,
            noTrustThirdPartyDeclarationAccepted: self.noTrustThirdPartyDeclarationAccepted,
            confirmedSummary: nil, companyFourEyesRequestId: nil,
            _positionOnly: nil
        )
    }
}

extension SubmissionFormData {
    func toSavedData() -> SavedCompanyKybData {
        SavedCompanyKybData(
            legalName: nil, legalForm: nil, registerType: nil,
            registerNumber: nil, registerCourt: nil, incorporationCountry: nil,
            notRegisteredReason: nil,
            streetAndNumber: nil, postalCode: nil, city: nil, country: nil,
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
            confirmedSummary: true,
            companyFourEyesRequestId: self.companyFourEyesRequestId.isEmpty ? nil : self.companyFourEyesRequestId,
            _positionOnly: nil
        )
    }
}
