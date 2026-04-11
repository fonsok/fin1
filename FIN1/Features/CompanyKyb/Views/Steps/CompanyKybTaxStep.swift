import SwiftUI

struct CompanyKybTaxStep: View {
    @Binding var formData: TaxComplianceFormData

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(20)) {
            stepHeader(
                title: "Steuern & Identifikatoren",
                subtitle: "Umsatzsteuer-ID oder nationale Steuernummer"
            )

            LabeledInputField(
                label: "USt-IdNr.",
                placeholder: "z. B. DE123456789",
                icon: "doc.text",
                text: $formData.vatId
            )

            LabeledInputField(
                label: "Nationale Steuernummer",
                placeholder: "z. B. 12/345/67890",
                icon: "doc.text",
                text: $formData.nationalTaxNumber
            )

            LabeledInputField(
                label: "Wirtschafts-Identifikationsnr. (optional)",
                placeholder: "W-ID",
                icon: "number",
                text: $formData.economicIdentificationNumber
            )

            toggleRow(
                title: "Keine USt-IdNr. vorhanden (Kleinunternehmer o. Ä.)",
                isOn: $formData.noVatIdDeclared
            )

            if formData.vatId.isEmpty && formData.nationalTaxNumber.isEmpty
                && !formData.noVatIdDeclared {
                HStack(spacing: ResponsiveDesign.spacing(8)) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                    Text("Bitte USt-IdNr., Steuernummer oder Kleinunternehmer-Erklärung angeben.")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(.orange)
                }
                .padding(ResponsiveDesign.spacing(12))
                .background(Color.orange.opacity(0.1))
                .cornerRadius(ResponsiveDesign.spacing(8))
            }
        }
    }
}
