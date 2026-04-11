import SwiftUI

struct CompanyKybAddressStep: View {
    @Binding var formData: RegisteredAddressFormData

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(20)) {
            stepHeader(
                title: "Sitz & Anschrift",
                subtitle: "Eingetragener Sitz der Gesellschaft"
            )

            LabeledInputField(
                label: "Straße und Hausnummer",
                placeholder: "z. B. Hauptstraße 1",
                icon: "mappin",
                text: $formData.streetAndNumber
            )

            HStack(spacing: ResponsiveDesign.spacing(12)) {
                LabeledInputField(
                    label: "PLZ",
                    placeholder: "60311",
                    icon: "number",
                    text: $formData.postalCode,
                    maxLength: 10
                )
                .frame(maxWidth: ResponsiveDesign.spacing(140))

                LabeledInputField(
                    label: "Ort",
                    placeholder: "Frankfurt",
                    icon: "building",
                    text: $formData.city
                )
            }

            LabeledInputField(
                label: "Land",
                placeholder: "DE",
                icon: "globe",
                text: $formData.country,
                maxLength: 2
            )

            toggleRow(
                title: "Abweichende Geschäftsanschrift",
                isOn: $formData.showBusinessAddress
            )

            if formData.showBusinessAddress {
                businessAddressSection
            }
        }
    }

    private var businessAddressSection: some View {
        VStack(spacing: ResponsiveDesign.spacing(16)) {
            LabeledInputField(
                label: "Geschäftsstraße",
                placeholder: "Nebenstraße 5",
                icon: "mappin",
                text: $formData.businessStreetAndNumber
            )

            HStack(spacing: ResponsiveDesign.spacing(12)) {
                LabeledInputField(
                    label: "PLZ",
                    placeholder: "10115",
                    icon: "number",
                    text: $formData.businessPostalCode,
                    maxLength: 10
                )
                .frame(maxWidth: ResponsiveDesign.spacing(140))

                LabeledInputField(
                    label: "Ort",
                    placeholder: "Berlin",
                    icon: "building",
                    text: $formData.businessCity
                )
            }

            LabeledInputField(
                label: "Land",
                placeholder: "DE",
                icon: "globe",
                text: $formData.businessCountry,
                maxLength: 2
            )
        }
        .padding(ResponsiveDesign.spacing(16))
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.isCompactDevice() ? 12 : 16)
    }
}
