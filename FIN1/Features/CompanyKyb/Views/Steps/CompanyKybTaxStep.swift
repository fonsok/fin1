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
                text: self.$formData.vatId
            )

            LabeledInputField(
                label: "Nationale Steuernummer",
                placeholder: "z. B. 12/345/67890",
                icon: "doc.text",
                text: self.$formData.nationalTaxNumber
            )

            LabeledInputField(
                label: "Wirtschafts-Identifikationsnr. (optional)",
                placeholder: "W-ID",
                icon: "number",
                text: self.$formData.economicIdentificationNumber
            )

            toggleRow(
                title: "Keine USt-IdNr. vorhanden (Kleinunternehmer o. Ä.)",
                isOn: self.$formData.noVatIdDeclared
            )

            if self.formData.vatId.isEmpty && self.formData.nationalTaxNumber.isEmpty
                && !self.formData.noVatIdDeclared {
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
