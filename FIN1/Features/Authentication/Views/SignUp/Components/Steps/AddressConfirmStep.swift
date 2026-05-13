import SwiftUI

struct AddressConfirmStep: View {
    @Binding var addressConfirmed: Bool
    @Binding var addressVerificationDocument: UIImage?

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(24)) {
            // Header
            VStack(spacing: ResponsiveDesign.spacing(8)) {
                Text("Adressnachweis hochladen")
                    .font(ResponsiveDesign.headlineFont())
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.fontColor)
                    .multilineTextAlignment(.center)

                Text(
                    "Der Adressnachweis muss von einer vertrauenswürdigen Stelle stammen, darf nicht geschwärzt sein und muss zur beantragten Person passen."
                )
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.8))
                .multilineTextAlignment(.leading)
            }

            // Address Display
            AddressDisplayView(address: self.sampleAddressInfo)

            // Document Upload
            DocumentUploadView(selectedImage: self.$addressVerificationDocument)

            // Document Requirements
            DocumentRequirementsView()

            // Confirmation
            AddressConfirmationView(isConfirmed: self.$addressConfirmed)
        }
    }

    private var sampleAddressInfo: AddressInfo {
        AddressInfo(
            streetAndNumber: "Musterstraße 123",
            postalCode: "12345",
            city: "Musterstadt",
            country: "Deutschland"
        )
    }
}

struct AddressConfirmationView: View {
    @Binding var isConfirmed: Bool

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(16)) {
            Button(action: { self.isConfirmed.toggle() }, label: {
                HStack {
                    InteractiveElement(
                        isSelected: self.isConfirmed,
                        type: .confirmationCircle
                    )

                    Text("Ich bestätige, dass dies meine aktuelle Wohnadresse ist")
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(AppTheme.fontColor)
                        .multilineTextAlignment(.leading)

                    Spacer()
                }
            })
            .buttonStyle(PlainButtonStyle())
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(16))
    }
}

#Preview {
    AddressConfirmStep(
        addressConfirmed: .constant(false),
        addressVerificationDocument: .constant(nil)
    )
    .background(AppTheme.screenBackground)
}
