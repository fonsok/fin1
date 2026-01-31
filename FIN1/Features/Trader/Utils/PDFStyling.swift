import Foundation
import UIKit

// MARK: - PDF Styling Configuration
struct PDFStyling {

    // MARK: - Page Configuration
    static let pageWidth: CGFloat = 8.5 * 72.0 // A4 width in points
    static let pageHeight: CGFloat = 11.0 * 72.0 // A4 height in points
    static let margin: CGFloat = 50

    // MARK: - Font Configuration
    static let titleFont = UIFont.boldSystemFont(ofSize: 24)
    static let headerFont = UIFont.boldSystemFont(ofSize: 16)
    static let bodyFont = UIFont.systemFont(ofSize: 12)
    static let smallFont = UIFont.systemFont(ofSize: 10)

    // MARK: - Table Configuration
    static let headerHeight: CGFloat = 30
    static let rowHeight: CGFloat = 25
    static let totalsWidth: CGFloat = 200

    // MARK: - Color Configuration
    static let primaryTextColor = UIColor.black
    static let secondaryTextColor = UIColor.darkGray
    static let tertiaryTextColor = UIColor.gray
    static let headerBackgroundColor = UIColor.lightGray
    static let alternateRowBackgroundColor = UIColor.systemGray6
    static let separatorColor = UIColor.lightGray
}

// MARK: - PDF Text Attributes
struct PDFTextAttributes {

    static func titleAttributes() -> [NSAttributedString.Key: Any] {
        return [
            .font: PDFStyling.titleFont,
            .foregroundColor: PDFStyling.primaryTextColor
        ]
    }

    static func headerAttributes() -> [NSAttributedString.Key: Any] {
        return [
            .font: PDFStyling.headerFont,
            .foregroundColor: PDFStyling.primaryTextColor
        ]
    }

    static func bodyAttributes() -> [NSAttributedString.Key: Any] {
        return [
            .font: PDFStyling.bodyFont,
            .foregroundColor: PDFStyling.primaryTextColor
        ]
    }

    static func secondaryBodyAttributes() -> [NSAttributedString.Key: Any] {
        return [
            .font: PDFStyling.bodyFont,
            .foregroundColor: PDFStyling.secondaryTextColor
        ]
    }

    static func tertiaryBodyAttributes() -> [NSAttributedString.Key: Any] {
        return [
            .font: PDFStyling.bodyFont,
            .foregroundColor: PDFStyling.tertiaryTextColor
        ]
    }

    static func smallAttributes() -> [NSAttributedString.Key: Any] {
        return [
            .font: PDFStyling.smallFont,
            .foregroundColor: PDFStyling.tertiaryTextColor
        ]
    }

    static func smallSecondaryAttributes() -> [NSAttributedString.Key: Any] {
        return [
            .font: PDFStyling.smallFont,
            .foregroundColor: PDFStyling.secondaryTextColor
        ]
    }
}

// MARK: - PDF Company Information
struct PDFCompanyInfo {

    static var companyName: String { CompanyContactInfo.companyName }
    static var companyDetails: [String] {
        [
        "Wertpapierhandelsbank",
        LegalIdentity.companyAddressLine,
        "Tel: \(CompanyContactInfo.phone)",
        "E-Mail: \(CompanyContactInfo.email)",
        "Handelsregister: \(LegalIdentity.companyRegisterNumber)",
        "USt-IdNr.: \(LegalIdentity.companyVatId)"
        ]
    }

    static var additionalLegalInfo: [String] {
        [
            "Diese Abrechnung wurde elektronisch erstellt und ist ohne Unterschrift gültig.",
            "Bei Fragen wenden Sie sich an unseren Kundenservice unter \(CompanyContactInfo.phone).",
            "Alle Preise verstehen sich inklusive der gesetzlichen Mehrwertsteuer, soweit diese anfällt."
        ]
    }
}

// MARK: - PDF Metadata
struct PDFMetadata {

    static func createMetadata(for invoice: Invoice) -> [String: Any] {
        return [
            kCGPDFContextCreator as String: "\(LegalIdentity.platformName) Trading App",
            kCGPDFContextAuthor as String: CompanyContactInfo.companyName,
            kCGPDFContextTitle as String: "Wertpapierabrechnung \(invoice.formattedInvoiceNumber)"
        ]
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

// MARK: - PDF Table Configuration
struct PDFTableConfig {

    static func columnWidths(for contentWidth: CGFloat) -> [CGFloat] {
        return [
            contentWidth * 0.4,  // Position
            contentWidth * 0.15, // Stück
            contentWidth * 0.15, // Price per share
            contentWidth * 0.15, // Betrag (€)
            contentWidth * 0.15  // Art
        ]
    }

    static let columnTitles = ["Position", "Stück", "Kurs je Stück", "Betrag (€)", "Art"]
}
