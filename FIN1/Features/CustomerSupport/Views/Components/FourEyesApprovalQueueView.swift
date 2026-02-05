import SwiftUI

// MARK: - Four-Eyes Approval Queue View

/// Dashboard for reviewing and processing 4-Augen approval requests
struct FourEyesApprovalQueueView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: FourEyesApprovalQueueViewModel

    init(
        approvalService: FourEyesApprovalServiceProtocol,
        auditService: AuditLoggingServiceProtocol,
        currentAgentId: String,
        currentAgentName: String,
        currentAgentRole: CSRRole
    ) {
        _viewModel = StateObject(wrappedValue: FourEyesApprovalQueueViewModel(
            approvalService: approvalService,
            auditService: auditService,
            currentAgentId: currentAgentId,
            currentAgentName: currentAgentName,
            currentAgentRole: currentAgentRole
        ))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ResponsiveDesign.spacing(16)) {
                    statsSection
                    filterSection
                    requestsSection
                }
                .padding()
            }
            .background(AppTheme.screenBackground.ignoresSafeArea())
            .navigationTitle("4-Augen-Genehmigungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Schließen") { dismiss() }
                }
            }
            .task { await viewModel.loadRequests() }
            .refreshable { await viewModel.loadRequests() }
            .sheet(item: $viewModel.selectedRequest) { request in
                ApprovalDetailSheet(
                    request: request,
                    viewModel: viewModel
                )
            }
            .alert("Fehler", isPresented: $viewModel.showError) {
                Button("OK") { viewModel.clearError() }
            } message: {
                Text(viewModel.errorMessage ?? "Ein Fehler ist aufgetreten")
            }
            .alert("Erfolg", isPresented: $viewModel.showSuccess) {
                Button("OK") { viewModel.clearSuccess() }
            } message: {
                Text(viewModel.successMessage ?? "")
            }
        }
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            HStack {
                Image(systemName: "eye.2.fill")
                    .foregroundColor(AppTheme.accentLightBlue)
                Text("4-Augen-Prinzip Übersicht")
                    .font(ResponsiveDesign.headlineFont())
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.fontColor)
            }

            if let stats = viewModel.statistics {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: ResponsiveDesign.spacing(12)) {
                    ApprovalStatCard(
                        title: "Ausstehend",
                        value: "\(stats.pendingCount)",
                        icon: "hourglass",
                        color: AppTheme.accentOrange
                    )
                    ApprovalStatCard(
                        title: "Dringend",
                        value: "\(stats.urgentRequests)",
                        icon: "exclamationmark.triangle.fill",
                        color: AppTheme.accentRed
                    )
                    ApprovalStatCard(
                        title: "Genehmigt heute",
                        value: "\(stats.approvedToday)",
                        icon: "checkmark.circle.fill",
                        color: AppTheme.accentGreen
                    )
                    ApprovalStatCard(
                        title: "Ø Bearbeitungszeit",
                        value: String(format: "%.1f Std.", stats.averageApprovalTimeHours),
                        icon: "clock.fill",
                        color: AppTheme.accentLightBlue
                    )
                }
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    // MARK: - Filter Section

    private var filterSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            Text("Filter")
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: ResponsiveDesign.spacing(8)) {
                    ApprovalFilterChip(
                        title: "Alle",
                        isSelected: viewModel.selectedFilter == nil,
                        action: { viewModel.selectedFilter = nil }
                    )
                    ForEach(ApprovalRiskLevel.allCases, id: \.self) { level in
                        ApprovalFilterChip(
                            title: level.displayName,
                            isSelected: viewModel.selectedFilter == level,
                            color: colorForRiskLevel(level),
                            action: { viewModel.selectedFilter = level }
                        )
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Requests Section

    private var requestsSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            HStack {
                Text("Ausstehende Anfragen")
                    .font(ResponsiveDesign.headlineFont())
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.fontColor)

                Spacer()

                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }

            if viewModel.filteredRequests.isEmpty {
                emptyStateView
            } else {
                ForEach(viewModel.filteredRequests) { request in
                    ApprovalRequestCard(request: request) {
                        viewModel.selectedRequest = request
                    }
                }
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    private var emptyStateView: some View {
        VStack(spacing: ResponsiveDesign.spacing(12)) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 48))
                .foregroundColor(AppTheme.accentGreen.opacity(0.5))

            Text("Keine ausstehenden Genehmigungen")
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))

            Text("Alle 4-Augen-Anfragen wurden bearbeitet")
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, ResponsiveDesign.spacing(32))
    }

    private func colorForRiskLevel(_ level: ApprovalRiskLevel) -> Color {
        switch level {
        case .low: return AppTheme.accentGreen
        case .medium: return AppTheme.accentOrange
        case .high: return AppTheme.accentRed
        case .critical: return Color.purple
        }
    }
}

// MARK: - Approval Request Card

private struct ApprovalRequestCard: View {
    let request: FourEyesApprovalRequest
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
                HStack {
                    riskBadge
                    Spacer()
                    timeRemainingBadge
                }

                Text(request.requestType.displayName)
                    .font(ResponsiveDesign.bodyFont())
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.fontColor)

                if let customerName = request.customerName {
                    HStack(spacing: ResponsiveDesign.spacing(4)) {
                        Image(systemName: "person.fill")
                            .font(ResponsiveDesign.captionFont())
                        Text(customerName)
                    }
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.7))
                }

                Text(request.description)
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.7))
                    .lineLimit(2)

                HStack {
                    Text("Angefordert von: \(request.requesterName)")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.5))

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.3))
                }
            }
            .padding()
            .background(AppTheme.screenBackground)
            .cornerRadius(ResponsiveDesign.spacing(10))
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var riskBadge: some View {
        let level = request.requestType.riskLevel
        return HStack(spacing: ResponsiveDesign.spacing(4)) {
            Circle()
                .fill(colorForRisk(level))
                .frame(width: 8, height: 8)
            Text(level.displayName)
                .font(ResponsiveDesign.captionFont())
                .fontWeight(.medium)
        }
        .padding(.horizontal, ResponsiveDesign.spacing(8))
        .padding(.vertical, ResponsiveDesign.spacing(4))
        .background(colorForRisk(level).opacity(0.15))
        .cornerRadius(ResponsiveDesign.spacing(6))
    }

    private var timeRemainingBadge: some View {
        Group {
            if let remaining = request.timeRemaining {
                let hours = Int(remaining / 3600)
                let isUrgent = hours < 4

                HStack(spacing: ResponsiveDesign.spacing(4)) {
                    Image(systemName: "clock.fill")
                        .font(ResponsiveDesign.captionFont())
                    Text(hours > 0 ? "\(hours) Std." : "< 1 Std.")
                        .font(ResponsiveDesign.captionFont())
                }
                .foregroundColor(isUrgent ? AppTheme.accentRed : AppTheme.fontColor.opacity(0.7))
            }
        }
    }

    private func colorForRisk(_ level: ApprovalRiskLevel) -> Color {
        switch level {
        case .low: return AppTheme.accentGreen
        case .medium: return AppTheme.accentOrange
        case .high: return AppTheme.accentRed
        case .critical: return Color.purple
        }
    }
}

// MARK: - Approval Detail Sheet

private struct ApprovalDetailSheet: View {
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
            // 4-Augen Warning
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
                Button(action: { showRejectConfirmation = true }) {
                    Label("Ablehnen", systemImage: "xmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(AppTheme.accentRed)
                .disabled(!viewModel.canApproveRequest(request))

                Button(action: {
                    Task {
                        await viewModel.approveRequest(request, notes: approvalNotes)
                        dismiss()
                    }
                }) {
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

// MARK: - Helper Views

private struct ApprovalStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }
            Text(value)
                .font(ResponsiveDesign.titleFont())
                .fontWeight(.bold)
                .foregroundColor(AppTheme.fontColor)
            Text(title)
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))
        }
        .padding()
        .background(AppTheme.screenBackground)
        .cornerRadius(ResponsiveDesign.spacing(10))
    }
}

private struct ApprovalFilterChip: View {
    let title: String
    let isSelected: Bool
    var color: Color = AppTheme.accentLightBlue
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(ResponsiveDesign.captionFont())
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, ResponsiveDesign.spacing(12))
                .padding(.vertical, ResponsiveDesign.spacing(6))
                .background(isSelected ? color : AppTheme.screenBackground)
                .foregroundColor(isSelected ? .white : AppTheme.fontColor)
                .cornerRadius(ResponsiveDesign.spacing(16))
        }
    }
}

private struct ApprovalDetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.6))
            Spacer()
            Text(value)
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor)
        }
    }
}
