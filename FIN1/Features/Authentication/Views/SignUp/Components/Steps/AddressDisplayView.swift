import SwiftUI

struct AddressDisplayView: View {
    let address: AddressInfo
    
    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(16)) {
            Text("Ihre Adresse:")
                .font(ResponsiveDesign.headlineFont())
                .foregroundColor(AppTheme.fontColor)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(alignment: .leading, spacing: 8) {
                Text(address.streetAndNumber)
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.inputFieldText)
                Text("\(address.postalCode) \(address.city)")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.inputFieldText)
                Text(address.country)
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.inputFieldText)
            }
            .padding()
            .background(AppTheme.inputFieldBackground)
            .cornerRadius(ResponsiveDesign.spacing(12))
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(16))
    }
}

struct AddressInfo {
    let streetAndNumber: String
    let postalCode: String
    let city: String
    let country: String
}

#Preview {
    AddressDisplayView(address: AddressInfo(
        streetAndNumber: "Musterstraße 123",
        postalCode: "12345",
        city: "Musterstadt",
        country: "Deutschland"
    ))
    .background(AppTheme.screenBackground)
}
