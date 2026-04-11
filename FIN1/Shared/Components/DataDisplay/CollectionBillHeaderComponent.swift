import SwiftUI

// MARK: - Collection Bill Header Component
/// Shared header component for both Trader and Investor Collection Bills
/// Follows DRY principle to avoid code duplication
struct CollectionBillHeaderComponent: View {
    let title: String
    let subtitle: String
    let documentNumber: String?
    let description: String?

    init(
        title: String,
        subtitle: String,
        documentNumber: String? = nil,
        description: String? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.documentNumber = documentNumber
        self.description = description
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            Text(title)
                .font(ResponsiveDesign.titleFont())
                .fontWeight(.bold)
                .foregroundColor(DocumentDesignSystem.textColor)

            Text(subtitle)
                .font(ResponsiveDesign.headlineFont())
                .foregroundColor(DocumentDesignSystem.textColor)

            // Belegnummer (Document Number) - gemäß GoB
            if let documentNumber = documentNumber {
                HStack {
                    Text("Belegnummer:")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(DocumentDesignSystem.textColorSecondary)
                    Text(documentNumber)
                        .font(ResponsiveDesign.captionFont())
                        .fontWeight(.medium)
                        .foregroundColor(DocumentDesignSystem.textColor)
                }
            }

            if let description = description {
                Text(description)
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(DocumentDesignSystem.textColorSecondary)
            }
        }
        .documentSection(level: 1)
    }
}

// MARK: - Preview
#if DEBUG
struct CollectionBillHeaderComponent_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: ResponsiveDesign.spacing(20)) {
            CollectionBillHeaderComponent(
                title: "Max Investor",
                subtitle: "Investment Collection Bill",
                documentNumber: "\(LegalIdentity.documentPrefix)-INVST-20250123-00001",
                description: "This document summarizes your share of the underlying trades."
            )

            CollectionBillHeaderComponent(
                title: "Jan Becker",
                subtitle: "Collection Bill",
                documentNumber: "\(LegalIdentity.documentPrefix)-INV-20250123-00001",
                description: "Sammelabrechnung (Wertpapierkauf/-verkauf)"
            )
        }
        .padding()
    }
}
#endif
