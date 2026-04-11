import SwiftUI

struct CompanyKybLegalEntityStep: View {
    @Binding var formData: LegalEntityFormData

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(20)) {
            stepHeader(
                title: "Unternehmensdaten",
                subtitle: "Bitte geben Sie die Daten Ihres Unternehmens ein."
            )

            LabeledInputField(
                label: "Firmenname",
                placeholder: "z. B. Muster GmbH",
                icon: "building.2",
                text: $formData.legalName
            )

            LabeledInputField(
                label: "Rechtsform",
                placeholder: "z. B. GmbH, AG, UG",
                icon: "doc.text",
                text: $formData.legalForm
            )

            LabeledInputField(
                label: "Registerart",
                placeholder: "z. B. HRB, HRA",
                icon: "list.clipboard",
                text: $formData.registerType
            )

            LabeledInputField(
                label: "Registernummer",
                placeholder: "z. B. 123456",
                icon: "number",
                text: $formData.registerNumber
            )

            LabeledInputField(
                label: "Registergericht",
                placeholder: "z. B. Amtsgericht Frankfurt",
                icon: "building.columns",
                text: $formData.registerCourt
            )

            LabeledInputField(
                label: "Gründungsland (ISO-2)",
                placeholder: "DE",
                icon: "globe",
                text: $formData.incorporationCountry,
                maxLength: 2
            )

            LabeledInputField(
                label: "Nicht registriert? Begründung (optional)",
                placeholder: "Falls nicht eingetragen…",
                icon: "info.circle",
                text: $formData.notRegisteredReason
            )
        }
    }
}

#Preview { CompanyKybLegalEntityStep(formData: .constant(LegalEntityFormData())).padding() }
