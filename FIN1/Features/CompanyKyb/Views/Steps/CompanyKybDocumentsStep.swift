import SwiftUI

struct CompanyKybDocumentsStep: View {
    @Binding var formData: DocumentsFormData

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(20)) {
            stepHeader(
                title: "Nachweise",
                subtitle: "Unternehmens- und Registerdokumente"
            )

            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
                Text("Erforderliche Dokumente")
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(AppTheme.fontColor)

                InfoBullet(text: "Aktueller Handelsregisterauszug (nicht älter als 6 Monate)")
                InfoBullet(text: "Gesellschaftsvertrag / Satzung (falls abweichend)")
                InfoBullet(text: "Transparenzregisterauszug (falls zutreffend)")
            }
            .padding(ResponsiveDesign.spacing(16))
            .background(AppTheme.sectionBackground)
            .cornerRadius(ResponsiveDesign.isCompactDevice() ? 12 : 16)

            LabeledInputField(
                label: "Handelsregisterauszug-Referenz (optional)",
                placeholder: "z. B. REF-HR-2026-001",
                icon: "doc.text",
                text: self.$formData.tradeRegisterExtractReference
            )

            toggleRow(
                title: "Ich bestätige, dass alle erforderlichen Dokumente vorliegen oder nachgereicht werden.",
                isOn: self.$formData.documentsAcknowledged
            )

            if !self.formData.documentsAcknowledged {
                HStack(spacing: ResponsiveDesign.spacing(8)) {
                    Image(systemName: "info.circle")
                        .foregroundColor(AppTheme.accentLightBlue)
                    Text("Bitte bestätigen Sie die Dokumentenbereitschaft, um fortzufahren.")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.7))
                }
            }
        }
    }
}
