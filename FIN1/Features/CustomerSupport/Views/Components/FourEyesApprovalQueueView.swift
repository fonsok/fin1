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
                    FourEyesApprovalQueueStatsSection(statistics: self.viewModel.statistics)
                    FourEyesApprovalQueueFilterSection(viewModel: self.viewModel)
                    FourEyesApprovalQueueRequestsSection(viewModel: self.viewModel) { request in
                        self.viewModel.selectedRequest = request
                    }
                }
                .padding()
            }
            .background(AppTheme.screenBackground.ignoresSafeArea())
            .navigationTitle("4-Augen-Genehmigungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Schließen") { self.dismiss() }
                }
            }
            .task { await self.viewModel.loadRequests() }
            .refreshable { await self.viewModel.loadRequests() }
            .sheet(item: self.$viewModel.selectedRequest) { request in
                ApprovalDetailSheet(
                    request: request,
                    viewModel: self.viewModel
                )
            }
            .alert("Fehler", isPresented: self.$viewModel.showError) {
                Button("OK") { self.viewModel.clearError() }
            } message: {
                Text(self.viewModel.errorMessage ?? "Ein Fehler ist aufgetreten")
            }
            .alert("Erfolg", isPresented: self.$viewModel.showSuccess) {
                Button("OK") { self.viewModel.clearSuccess() }
            } message: {
                Text(self.viewModel.successMessage ?? "")
            }
        }
    }
}
