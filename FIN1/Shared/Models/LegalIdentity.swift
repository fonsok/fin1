import Foundation

// MARK: - Legal & Accounting Identity
/// Centralized legal/accounting identity values used in:
/// - document headers / PDFs (issuer / author / company name)
/// - document numbers / IDs prefix
/// - legal wording shown in-app (Terms/Privacy "App" naming)
///
/// NOTE:
/// - By default, these values derive from `AppBrand.appName` (Display Name) to support easy rebranding.
/// - For production/legal correctness, you SHOULD override legal/accounting identity values via Info.plist
///   (e.g., legal entity name, bank name, document prefix), because those values must be stable and accurate.
enum LegalIdentity {
    // MARK: Bundle keys (optional overrides)
    private enum InfoKey {
        static let platformName = "LegalPlatformName"
        static let companyLegalName = "LegalCompanyName"
        static let documentPrefix = "LegalDocumentPrefix"
        static let logoAssetName = "LegalLogoAssetName"
        static let companyAddress = "LegalCompanyAddress"
        static let companyCity = "LegalCompanyCity"
        static let companyAddressLine = "LegalCompanyAddressLine"
        static let companyRegisterNumber = "LegalCompanyRegisterNumber"
        static let companyVatId = "LegalCompanyVatId"
        static let companyManagement = "LegalCompanyManagement"
        static let bankName = "LegalBankName"
        static let bankIBAN = "LegalBankIBAN"
        static let bankBIC = "LegalBankBIC"
    }

    /// Reads a custom override from Info.plist. Returns nil if empty or not set.
    private static func bundleOverride(_ key: String) -> String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String else {
            return nil
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        // Treat build variable placeholders as "not set" (e.g., if plist has literal "$(VAR)" unresolved)
        if trimmed.isEmpty || trimmed.hasPrefix("$(") {
            return nil
        }
        return trimmed
    }

    /// Name used in legal wording (e.g., "the <App> App").
    /// Defaults to AppBrand.appName (Display Name).
    static var platformName: String {
        bundleOverride(InfoKey.platformName) ?? AppBrand.appName
    }

    /// Legal entity name used on accounting documents (issuer).
    /// Defaults to a rebrand-friendly value derived from Display Name.
    /// Override via Info.plist (`LegalCompanyName`) for legal correctness.
    static var companyLegalName: String {
        bundleOverride(InfoKey.companyLegalName) ?? "\(AppBrand.appName) Investing GmbH"
    }

    /// Company street address (e.g., "Hauptstraße 100").
    static var companyAddress: String {
        bundleOverride(InfoKey.companyAddress) ?? "Hauptstraße 100"
    }

    /// Company city with ZIP (e.g., "60311 Frankfurt am Main").
    static var companyCity: String {
        bundleOverride(InfoKey.companyCity) ?? "60311 Frankfurt am Main"
    }

    /// Registered business address line shown on documents (single-line).
    /// Combines address + city if not explicitly set.
    static var companyAddressLine: String {
        bundleOverride(InfoKey.companyAddressLine) ?? "\(companyAddress), \(companyCity)"
    }

    /// Company register number (e.g., "HRB 123456").
    static var companyRegisterNumber: String {
        bundleOverride(InfoKey.companyRegisterNumber) ?? "HRB 123456"
    }

    /// Company VAT ID (e.g., "DE123456789").
    static var companyVatId: String {
        bundleOverride(InfoKey.companyVatId) ?? "DE123456789"
    }

    /// Company management/Geschäftsführung name.
    static var companyManagement: String {
        bundleOverride(InfoKey.companyManagement) ?? "Max Mustermann"
    }

    /// Prefix used for accounting IDs / document numbers (e.g., `<AppName>-INV-...`).
    /// Defaults to a derived, *sanitized* prefix from Display Name.
    /// Override via Info.plist (`LegalDocumentPrefix`) for stable numbering schemes.
    static var documentPrefix: String {
        bundleOverride(InfoKey.documentPrefix) ?? derivedDocumentPrefix
    }

    /// Bank display name used in statements/invoices (demo/default).
    /// Defaults to a value derived from Display Name.
    /// Override via Info.plist (`LegalBankName`) for legal correctness.
    static var bankName: String {
        bundleOverride(InfoKey.bankName) ?? "\(AppBrand.appName) Bank AG"
    }

    /// Bank IBAN for payment information on documents.
    static var bankIBAN: String {
        bundleOverride(InfoKey.bankIBAN) ?? "DE89 3704 0044 0532 0130 00"
    }

    /// Bank BIC/SWIFT code for payment information on documents.
    static var bankBIC: String {
        bundleOverride(InfoKey.bankBIC) ?? "COBADEFFXXX"
    }

    /// Asset name for the legal/logo mark used on documents.
    /// Defaults to "<DocumentPrefix>Logo" (sanitized for asset naming).
    static var logoAssetName: String {
        bundleOverride(InfoKey.logoAssetName) ?? "\(derivedDocumentPrefix)Logo"
    }

    // MARK: - Derived defaults

    /// Derived prefix suitable for IDs / QR types (ASCII-ish, uppercase, no spaces).
    private static var derivedDocumentPrefix: String {
        let raw = AppBrand.appName.trimmingCharacters(in: .whitespacesAndNewlines)

        // Keep only alphanumerics for stability in document numbers / QR types.
        let scalars = raw.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }
        let cleaned = String(String.UnicodeScalarView(scalars)).uppercased()

        // Fall back to FIN1 for unusual runtime contexts.
        return cleaned.isEmpty ? "FIN1" : cleaned
    }
}
