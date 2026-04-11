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

            summarySection

            toggleRow(
                title: "Ich habe die Zusammenfassung geprüft und bestätige die Richtigkeit aller Angaben.",
                isOn: $formData.confirmedSummary
            )

            if viewModel.completedSteps.count < CompanyKybStep.totalSteps - 1 {
                incompleteWarning
            }
        }
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            Text("Zusammenfassung")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.bold)
                .foregroundColor(AppTheme.fontColor)

            summaryRow(label: "Firma", value: viewModel.legalEntity.legalName)
            summaryRow(label: "Rechtsform", value: viewModel.legalEntity.legalForm)
            summaryRow(
                label: "Sitz",
                value: "\(viewModel.registeredAddress.city), \(viewModel.registeredAddress.country)"
            )
            summaryRow(label: "USt-IdNr.", value: viewModel.taxCompliance.vatId.isEmpty
                ? (viewModel.taxCompliance.noVatIdDeclared ? "Nicht vorhanden" : "–")
                : viewModel.taxCompliance.vatId
            )
            summaryRow(
                label: "UBOs",
                value: viewModel.beneficialOwners.noUboOver25Percent
                    ? "Kein UBO > 25 %"
                    : "\(viewModel.beneficialOwners.ubos.count) eingetragen"
            )
            summaryRow(
                label: "Vertreter",
                value: "\(viewModel.authorizedRepresentatives.representatives.count) eingetragen"
            )
            summaryRow(
                label: "Dokumente",
                value: viewModel.documents.documentsAcknowledged ? "Bestätigt" : "Ausstehend"
            )
            summaryRow(
                label: "Erklärungen",
                value: viewModel.declarations.accuracyDeclarationAccepted ? "Abgegeben" : "Ausstehend"
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
