import SwiftUI

struct AddressConfirmStep: View {
    @Binding var addressConfirmed: Bool
    @Binding var addressVerificationDocument: UIImage?

    var body: some View {
        SignUpStepList {
            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
                Text("Adressnachweis hochladen")
                    .font(ResponsiveDesign.headlineFont())
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.fontColor)

                Text(
                    "Der Adressnachweis muss von einer vertrauenswürdigen Stelle stammen, darf nicht geschwärzt sein und muss zur beantragten Person passen."
                )
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.8))
            }
            .signUpListSection(stripeIndex: 0)

            AddressDisplayView(address: self.sampleAddressInfo)
                .signUpListSection(stripeIndex: 1)

            DocumentUploadView(selectedImage: self.$addressVerificationDocument)
                .signUpListSection(stripeIndex: 2)

            DocumentRequirementsView()
                .signUpListSection(stripeIndex: 3)

            AddressConfirmationView(isConfirmed: self.$addressConfirmed)
                .signUpListSection(
                    stripeIndex: 4,
                    isSelected: self.addressConfirmed,
                    selectionAccent: AppTheme.accentGreen
                )
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
}

#Preview {
    AddressConfirmStep(
        addressConfirmed: .constant(false),
        addressVerificationDocument: .constant(nil)
    )
    .background(AppTheme.screenBackground)
}
