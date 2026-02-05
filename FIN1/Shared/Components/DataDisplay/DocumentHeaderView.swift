import SwiftUI

// MARK: - Document Header View
/// ⚠️ DEPRECATED: This component is no longer used.
/// All document views now use `DocumentHeaderLayoutView` instead.
/// This file is kept for reference only and may be removed in the future.
/// 
/// Wiederverwendbare Komponente für den Kopfteil aller Dokumente
/// Enthält: Logo, Firmen-Adresse, Kontaktinformationen, Datum, Dokument-Titel, Kontoinhaber
/// Folgt DRY-Prinzip zur Vermeidung von Code-Duplikation
@available(*, deprecated, message: "Use DocumentHeaderLayoutView instead")
struct DocumentHeaderView: View {
    let documentTitle: String // z.B. "Rechnung", "Gutschrift", "Sammelabrechnung"
    let accountHolderName: String // "Vorname Nachname"
    let accountHolderAddress: String? // "Straße Hausnummer"
    let accountHolderCity: String? // "PLZ Ort"
    let documentDate: Date
    
    init(
        documentTitle: String = "",
        accountHolderName: String = "",
        accountHolderAddress: String? = nil,
        accountHolderCity: String? = nil,
        documentDate: Date = Date()
    ) {
        self.documentTitle = documentTitle
        self.accountHolderName = accountHolderName
        self.accountHolderAddress = accountHolderAddress
        self.accountHolderCity = accountHolderCity
        self.documentDate = documentDate
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(16)) {
            // Top Section: Logo + QR Code (QR Code will be added by parent view)
            HStack(alignment: .top, spacing: ResponsiveDesign.spacing(16)) {
                // Left: Logo + Company Address + Account Holder Address
                VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
                    // Logo (falls vorhanden)
                    if let logoImage = UIImage(named: LegalIdentity.logoAssetName) {
                        Image(uiImage: logoImage)
                            .resizable()
                            .scaledToFit()
                            .frame(height: ResponsiveDesign.spacing(40))
                    } else {
                        // Platzhalter falls Logo nicht vorhanden
                        Text(LegalIdentity.platformName)
                            .font(ResponsiveDesign.titleFont())
                            .fontWeight(.bold)
                            .foregroundColor(DocumentDesignSystem.textColor)
                    }
                    
                    // Adresse (1 Zeile, kleine Schriftgröße)
                    Text(companyAddressLine)
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(DocumentDesignSystem.textColorSecondary)
                    
                    // Account Holder Address (wie bei Briefköpfen üblich)
                    if !accountHolderName.isEmpty {
                        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(2)) {
                            Text(accountHolderName)
                                .font(ResponsiveDesign.bodyFont())
                                .foregroundColor(DocumentDesignSystem.textColor)
                                .padding(.top, ResponsiveDesign.spacing(8))
                            
                            if let address = accountHolderAddress {
                                Text(address)
                                    .font(ResponsiveDesign.bodyFont())
                                    .foregroundColor(DocumentDesignSystem.textColor)
                            }
                            
                            if let city = accountHolderCity {
                                Text(city)
                                    .font(ResponsiveDesign.bodyFont())
                                    .foregroundColor(DocumentDesignSystem.textColor)
                            }
                        }
                    }
                }
                
                Spacer()
            }
        }
        .documentSection(level: 1)
    }
    
    // MARK: - Company Info View (to be shown below QR code)
    var companyInfoView: some View {
        VStack(alignment: .trailing, spacing: ResponsiveDesign.spacing(4)) {
            // Email
            HStack {
                Text("E-Mail:")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(DocumentDesignSystem.textColorSecondary)
                Text(companyEmail)
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(DocumentDesignSystem.textColor)
            }
            
            // Telefon
            HStack {
                Text("Telefon:")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(DocumentDesignSystem.textColorSecondary)
                Text(companyPhone)
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(DocumentDesignSystem.textColor)
            }
            
            // BIC
            if let bic = companyBIC {
                HStack {
                    Text("BIC:")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(DocumentDesignSystem.textColorSecondary)
                    Text(bic)
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(DocumentDesignSystem.textColor)
                }
            }
            
            // Internetadresse
            if let website = companyWebsite {
                HStack {
                    Text("Internet:")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(DocumentDesignSystem.textColorSecondary)
                    Text(website)
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(DocumentDesignSystem.textColor)
                }
            }
            
            // Zeiten Erreichbarkeit
            Text(companyHours)
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(DocumentDesignSystem.textColorSecondary)
                .multilineTextAlignment(.trailing)
            
            // Datum
            Text(formattedDate)
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(DocumentDesignSystem.textColor)
                .padding(.top, ResponsiveDesign.spacing(4))
        }
    }
    
    // MARK: - Private Helpers
    
    private var companyAddressLine: String {
        // Kombiniert alle Adresszeilen zu einer Zeile
        let addressParts = PDFCompanyInfo.companyDetails.filter { detail in
            !detail.contains("Tel:") && !detail.contains("E-Mail:") && !detail.contains("Handelsregister:") && !detail.contains("USt-IdNr.:")
        }
        return addressParts.joined(separator: ", ")
    }
    
    private var companyEmail: String {
        // Try to extract from PDFCompanyInfo first, fallback to constant
        PDFCompanyInfo.companyDetails.first { $0.contains("E-Mail:") }?
            .replacingOccurrences(of: "E-Mail: ", with: "") ?? CompanyContactInfo.email
    }
    
    private var companyPhone: String {
        // Try to extract from PDFCompanyInfo first, fallback to constant
        PDFCompanyInfo.companyDetails.first { $0.contains("Tel:") }?
            .replacingOccurrences(of: "Tel: ", with: "") ?? CompanyContactInfo.phone
    }
    
    private var companyBIC: String? {
        // BIC from centralized constant
        return CompanyContactInfo.bic
    }
    
    private var companyWebsite: String? {
        // Website from centralized constant
        return CompanyContactInfo.website
    }
    
    private var companyHours: String {
        CompanyContactInfo.businessHours
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.locale = Locale(identifier: "de_DE")
        return formatter.string(from: documentDate)
    }
}

// MARK: - Preview
#if DEBUG
struct DocumentHeaderView_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack {
                DocumentHeaderLayoutView(
                    accountHolderName: "Max Mustermann",
                    accountHolderAddress: "Musterstraße 42",
                    accountHolderCity: "60311 Frankfurt am Main",
                    documentDate: Date()
                ) {
                    // QR Code placeholder for preview
                    RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(8))
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 120, height: 120)
                }
                .padding()
            }
        }
        .background(DocumentDesignSystem.documentBackground)
    }
}
#endif
