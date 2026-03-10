import SwiftUI

// MARK: - Four-Eyes Approval Queue View
/// Dashboard for reviewing and processing 4-Augen approval requests.
/// Section views live in FourEyesApproval/ (Stats, Filter, Requests, ApprovalRequestCard, ApprovalDetailSheet, Helpers).
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
                    FourEyesApprovalQueueStatsSection(statistics: viewModel.statistics)
                    FourEyesApprovalQueueFilterSection(viewModel: viewModel)
                    FourEyesApprovalQueueRequestsSection(viewModel: viewModel) { request in
                        viewModel.selectedRequest = request
                    }
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
}
