import SwiftUI

/// Detail sheet for a single 4-eyes approval request (info, justification, approve/reject).
struct ApprovalDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let request: FourEyesApprovalRequest
    @ObservedObject var viewModel: FourEyesApprovalQueueViewModel
    @State private var approvalNotes = ""
    @State private var rejectionReason = ""
    @State private var showRejectConfirmation = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ResponsiveDesign.spacing(16)) {
                    requestInfoSection
                    customerInfoSection
                    justificationSection
                    metadataSection
                    actionSection
                }
                .padding()
            }
            .background(AppTheme.screenBackground.ignoresSafeArea())
            .navigationTitle("Genehmigungsanfrage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Schließen") { dismiss() }
                }
            }
            .alert("Anfrage ablehnen", isPresented: $showRejectConfirmation) {
                TextField("Ablehnungsgrund", text: $rejectionReason)
                Button("Abbrechen", role: .cancel) {}
                Button("Ablehnen", role: .destructive) {
                    Task {
                        await viewModel.rejectRequest(request, reason: rejectionReason)
                        dismiss()
                    }
                }
            } message: {
                Text("Bitte geben Sie einen Grund für die Ablehnung an.")
            }
        }
    }

    private var requestInfoSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            HStack {
                Image(systemName: "doc.text.fill")
                    .foregroundColor(AppTheme.accentLightBlue)
                Text("Anfragedetails")
                    .font(ResponsiveDesign.headlineFont())
                    .fontWeight(.semibold)
            }

            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
                ApprovalDetailRow(label: "Typ", value: request.requestType.displayName)
                ApprovalDetailRow(label: "Risikostufe", value: request.requestType.riskLevel.displayName)
                ApprovalDetailRow(label: "Angefordert von", value: "\(request.requesterName) (\(request.requesterRole.displayName))")
                ApprovalDetailRow(label: "Erstellt am", value: formatDate(request.createdAt))
                ApprovalDetailRow(label: "Läuft ab am", value: formatDate(request.expiresAt))
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    private var customerInfoSection: some View {
        Group {
            if let customerName = request.customerName {
                VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
                    HStack {
                        Image(systemName: "person.fill")
                            .foregroundColor(AppTheme.accentOrange)
                        Text("Betroffener Kunde")
                            .font(ResponsiveDesign.headlineFont())
                            .fontWeight(.semibold)
                    }

                    ApprovalDetailRow(label: "Name", value: customerName)
                    if let customerId = request.customerId {
                        ApprovalDetailRow(label: "Kunden-ID", value: customerId)
                    }
                }
                .padding()
                .background(AppTheme.sectionBackground)
                .cornerRadius(ResponsiveDesign.spacing(12))
            }
        }
    }

    private var justificationSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            HStack {
                Image(systemName: "text.quote")
                    .foregroundColor(AppTheme.accentGreen)
                Text("Begründung")
                    .font(ResponsiveDesign.headlineFont())
                    .fontWeight(.semibold)
            }

            Text(request.sensitiveAction)
                .font(ResponsiveDesign.bodyFont())
                .fontWeight(.medium)
                .foregroundColor(AppTheme.fontColor)

            Text(request.justification)
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.8))
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    private var metadataSection: some View {
        Group {
            if !request.metadata.isEmpty {
                VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(AppTheme.fontColor.opacity(0.5))
                        Text("Zusätzliche Informationen")
                            .font(ResponsiveDesign.headlineFont())
                            .fontWeight(.semibold)
                    }

                    ForEach(Array(request.metadata.keys.sorted()), id: \.self) { key in
                        if let value = request.metadata[key] {
                            ApprovalDetailRow(label: key, value: value)
                        }
                    }
                }
                .padding()
                .background(AppTheme.sectionBackground)
                .cornerRadius(ResponsiveDesign.spacing(12))
            }
        }
    }

    private var actionSection: some View {
        VStack(spacing: ResponsiveDesign.spacing(12)) {
            if !viewModel.canApproveRequest(request) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(AppTheme.accentOrange)
                    Text("Sie können diese Anfrage nicht genehmigen (4-Augen-Prinzip oder Rolle)")
                        .font(ResponsiveDesign.captionFont())
                }
                .padding()
                .background(AppTheme.accentOrange.opacity(0.1))
                .cornerRadius(ResponsiveDesign.spacing(8))
            }

            TextField("Notizen zur Genehmigung (optional)", text: $approvalNotes)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            HStack(spacing: ResponsiveDesign.spacing(12)) {
                Button { showRejectConfirmation = true } label: {
                    Label("Ablehnen", systemImage: "xmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(AppTheme.accentRed)
                .disabled(!viewModel.canApproveRequest(request))

                Button {
                    Task {
                        await viewModel.approveRequest(request, notes: approvalNotes)
                        dismiss()
                    }
                } label: {
                    Label("Genehmigen", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accentGreen)
                .disabled(!viewModel.canApproveRequest(request))
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "de_DE")
        return formatter.string(from: date)
    }
}
