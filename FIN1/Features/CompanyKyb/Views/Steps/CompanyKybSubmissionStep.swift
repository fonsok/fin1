import SwiftUI

struct CompanyKybSubmissionStep: View {
    @Binding var formData: SubmissionFormData
    @ObservedObject var viewModel: CompanyKybViewModel

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(20)) {
            stepHeader(
                title: "Einreichung",
                subtitle: "Bitte prüfen Sie die Zusammenfassung und reichen Sie den Antrag ein."
            )

            self.summarySection

            toggleRow(
                title: "Ich habe die Zusammenfassung geprüft und bestätige die Richtigkeit aller Angaben.",
                isOn: self.$formData.confirmedSummary
            )

            if self.viewModel.completedSteps.count < CompanyKybStep.totalSteps - 1 {
                self.incompleteWarning
            }
        }
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            Text("Zusammenfassung")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.bold)
                .foregroundColor(AppTheme.fontColor)

            self.summaryRow(label: "Firma", value: self.viewModel.legalEntity.legalName)
            self.summaryRow(label: "Rechtsform", value: self.viewModel.legalEntity.legalForm)
            self.summaryRow(
                label: "Sitz",
                value: "\(self.viewModel.registeredAddress.city), \(self.viewModel.registeredAddress.country)"
            )
            self.summaryRow(label: "USt-IdNr.", value: self.viewModel.taxCompliance.vatId.isEmpty
                ? (self.viewModel.taxCompliance.noVatIdDeclared ? "Nicht vorhanden" : "–")
                : self.viewModel.taxCompliance.vatId)
            self.summaryRow(
                label: "UBOs",
                value: self.viewModel.beneficialOwners.noUboOver25Percent
                    ? "Kein UBO > 25 %"
                    : "\(self.viewModel.beneficialOwners.ubos.count) eingetragen"
            )
            self.summaryRow(
                label: "Vertreter",
                value: "\(self.viewModel.authorizedRepresentatives.representatives.count) eingetragen"
            )
            self.summaryRow(
                label: "Dokumente",
                value: self.viewModel.documents.documentsAcknowledged ? "Bestätigt" : "Ausstehend"
            )
            self.summaryRow(
                label: "Erklärungen",
                value: self.viewModel.declarations.accuracyDeclarationAccepted ? "Abgegeben" : "Ausstehend"
            )
        }
        .padding(ResponsiveDesign.spacing(16))
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.isCompactDevice() ? 12 : 16)
    }

    private func summaryRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))
                .frame(maxWidth: ResponsiveDesign.spacing(120), alignment: .leading)
            Text(value)
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor)
            Spacer()
        }
    }

    private var incompleteWarning: some View {
        HStack(spacing: ResponsiveDesign.spacing(8)) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundColor(.orange)
            Text("Nicht alle Schritte abgeschlossen. Bitte vervollständigen Sie alle vorherigen Schritte.")
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(.orange)
        }
        .padding(ResponsiveDesign.spacing(12))
        .background(Color.orange.opacity(0.1))
        .cornerRadius(ResponsiveDesign.spacing(8))
    }
}
