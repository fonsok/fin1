import SwiftUI

// MARK: - Document Header Layout View
/// Einheitliches, wiederverwendbares Kopfteil für alle Dokumente
/// Folgt DRY-Prinzip - kapselt komplettes Layout (Logo, Adresse, QR Code, Company Info)
/// Verwendet bei: Invoices, Collection Bills (Trader & Investor), Credit Notes
struct DocumentHeaderLayoutView<QRCodeContent: View>: View {
    // Account Holder Information
    let accountHolderName: String
    let accountHolderAddress: String?
    let accountHolderCity: String?
    let documentDate: Date

    // QR Code Content (generic to support different QR code types)
    let qrCodeContent: () -> QRCodeContent

    init(
        accountHolderName: String = "",
        accountHolderAddress: String? = nil,
        accountHolderCity: String? = nil,
        documentDate: Date = Date(),
        @ViewBuilder qrCodeContent: @escaping () -> QRCodeContent
    ) {
        self.accountHolderName = accountHolderName
        self.accountHolderAddress = accountHolderAddress
        self.accountHolderCity = accountHolderCity
        self.documentDate = documentDate
        self.qrCodeContent = qrCodeContent
    }

    var body: some View {
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
                Text(self.companyAddressLine)
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(DocumentDesignSystem.textColorSecondary)

                // Account Holder Address (wie bei Briefköpfen üblich)
                if !self.accountHolderName.isEmpty {
                    VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(2)) {
                        Text(self.accountHolderName)
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

            // Right: QR Code + Company Info below
            VStack(alignment: .trailing, spacing: ResponsiveDesign.spacing(8)) {
                // QR Code (passed as content)
                self.qrCodeContent()

                // Company Info below QR Code
                self.companyInfoView
            }
        }
        .documentSection(level: 1)
    }

    // MARK: - Company Info View

    private var companyInfoView: some View {
        VStack(alignment: .trailing, spacing: ResponsiveDesign.spacing(4)) {
            // Email
            HStack {
                Text("E-Mail:")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(DocumentDesignSystem.textColorSecondary)
                Text(self.companyEmail)
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(DocumentDesignSystem.textColor)
            }

            // Telefon
            HStack {
                Text("Telefon:")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(DocumentDesignSystem.textColorSecondary)
                Text(self.companyPhone)
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
            Text(self.companyHours)
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(DocumentDesignSystem.textColorSecondary)
                .multilineTextAlignment(.trailing)

            // Datum
            Text(self.formattedDate)
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
        return formatter.string(from: self.documentDate)
    }
}

// MARK: - Preview
#if DEBUG
struct DocumentHeaderLayoutView_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack {
                DocumentHeaderLayoutView(
                    accountHolderName: "Max Mustermann",
                    accountHolderAddress: "Musterstraße 42",
                    accountHolderCity: "60311 Frankfurt am Main",
                    documentDate: Date()
                ) {
                    // QR Code placeholder
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
