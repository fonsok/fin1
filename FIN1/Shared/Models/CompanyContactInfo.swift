import Foundation

// MARK: - Company Contact Information
/// Centralized company contact information for all documents
/// Follows DRY principles - single source of truth
/// Used by: DocumentHeaderLayoutView, DocumentHeaderView, PDFStyling, etc.
///
/// All values are configurable via Info.plist for easy rebranding.
struct CompanyContactInfo {
    private static func bundleString(_ key: String) -> String? {
        (Bundle.main.object(forInfoDictionaryKey: key) as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
    }

    // MARK: - Company Identity (delegates to LegalIdentity)

    /// Full company name (e.g., "FIN1 Investing GmbH")
    static var companyName: String {
        LegalIdentity.companyLegalName
    }

    /// Street address (e.g., "Hauptstraße 100")
    static var address: String {
        LegalIdentity.companyAddress
    }

    /// City with ZIP (e.g., "60311 Frankfurt am Main")
    static var city: String {
        LegalIdentity.companyCity
    }

    /// Full address line (e.g., "Hauptstraße 100, 60311 Frankfurt am Main")
    static var addressLine: String {
        LegalIdentity.companyAddressLine
    }

    /// Management name (e.g., "Max Mustermann")
    static var management: String {
        LegalIdentity.companyManagement
    }

    /// Register number (e.g., "HRB 123456")
    static var registerNumber: String {
        LegalIdentity.companyRegisterNumber
    }

    /// VAT ID (e.g., "DE123456789")
    static var vatId: String {
        LegalIdentity.companyVatId
    }

    // MARK: - Contact Information

    /// Company email address
    static var email: String {
        bundleString("LegalCompanyEmail") ?? "info@fin1-investing.de"
    }

    /// Company phone number
    static var phone: String {
        bundleString("LegalCompanyPhone") ?? "+49 (0) 69 12345678"
    }

    /// Company website URL
    static var website: String {
        bundleString("LegalCompanyWebsite") ?? "www.fin1-investing.de"
    }

    /// Business hours
    static var businessHours: String {
        bundleString("LegalCompanyBusinessHours") ?? "Mo-Fr: 9:00-18:00 Uhr"
    }

    // MARK: - Bank Information

    /// Bank name (e.g., "Deutsche Bank")
    static var bankName: String {
        LegalIdentity.bankName
    }

    /// Bank IBAN
    static var bankIBAN: String {
        LegalIdentity.bankIBAN
    }

    /// Bank BIC/SWIFT code
    static var bic: String {
        LegalIdentity.bankBIC
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
