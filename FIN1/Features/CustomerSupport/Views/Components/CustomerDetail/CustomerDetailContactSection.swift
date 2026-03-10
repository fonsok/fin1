import SwiftUI

/// Contact info section for customer detail.
struct CustomerDetailContactSection: View {
    let customer: CustomerProfile

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            Text("Kontaktdaten")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.fontColor)

            VStack(spacing: ResponsiveDesign.spacing(8)) {
                CSContactInfoRow(icon: "envelope.fill", label: "E-Mail", value: customer.email)
                CSContactInfoRow(icon: "phone.fill", label: "Telefon", value: customer.phoneNumber)
                if let address = customer.formattedAddress {
                    CSContactInfoRow(icon: "location.fill", label: "Adresse", value: address)
                }
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }
}
