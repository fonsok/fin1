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
            legalName: legalName, legalForm: legalForm,
            registerType: registerType, registerNumber: registerNumber,
            registerCourt: registerCourt, incorporationCountry: incorporationCountry,
            notRegisteredReason: notRegisteredReason.isEmpty ? nil : notRegisteredReason,
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
            streetAndNumber: streetAndNumber, postalCode: postalCode,
            city: city, country: country,
            businessStreetAndNumber: businessStreetAndNumber.isEmpty ? nil : businessStreetAndNumber,
            businessPostalCode: businessPostalCode.isEmpty ? nil : businessPostalCode,
            businessCity: businessCity.isEmpty ? nil : businessCity,
            businessCountry: businessCountry.isEmpty ? nil : businessCountry,
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
            vatId: vatId.isEmpty ? nil : vatId,
            nationalTaxNumber: nationalTaxNumber.isEmpty ? nil : nationalTaxNumber,
            economicIdentificationNumber: economicIdentificationNumber.isEmpty ? nil : economicIdentificationNumber,
            noVatIdDeclared: noVatIdDeclared ? true : nil,
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
        let uboList: [SavedCompanyKybUbo]? = noUboOver25Percent ? nil : ubos.map {
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
            ubos: uboList, noUboOver25Percent: noUboOver25Percent ? true : nil,
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
        let repList = representatives.map {
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
            appAccountHolderIsRepresentative: appAccountHolderIsRepresentative ? true : nil,
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
        let manifest: [SavedCompanyKybDocumentManifestEntry]? = documentManifest.isEmpty ? nil : documentManifest.map {
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
            tradeRegisterExtractReference: tradeRegisterExtractReference.isEmpty ? nil : tradeRegisterExtractReference,
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
            isPoliticallyExposed: isPoliticallyExposed,
            pepDetails: pepDetails.isEmpty ? nil : pepDetails,
            sanctionsSelfDeclarationAccepted: sanctionsSelfDeclarationAccepted,
            accuracyDeclarationAccepted: accuracyDeclarationAccepted,
            noTrustThirdPartyDeclarationAccepted: noTrustThirdPartyDeclarationAccepted,
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
            companyFourEyesRequestId: companyFourEyesRequestId.isEmpty ? nil : companyFourEyesRequestId,
            _positionOnly: nil
        )
    }
}
