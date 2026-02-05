import SwiftUI

// MARK: - Pending Configuration Changes View
/// View for displaying and managing 4-eyes approval workflow for critical configuration changes
struct PendingConfigurationChangesView: View {
    @Environment(\.appServices) private var appServices
    @StateObject private var viewModel = PendingConfigurationChangesViewModel()

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Pending Approvals")
                .navigationBarTitleDisplayMode(.large)
                .task {
                    viewModel.configure(with: appServices.configurationService)
                    await viewModel.loadPendingChanges()
                }
                .refreshable {
                    await viewModel.loadPendingChanges()
                }
                .sheet(isPresented: $viewModel.showApprovalSheet) {
                    approvalSheet
                }
                .sheet(isPresented: $viewModel.showRejectionSheet) {
                    rejectionSheet
                }
        }
    }

    // MARK: - Content
    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.pendingChanges.isEmpty {
            loadingView
        } else if viewModel.pendingChanges.isEmpty {
            emptyStateView
        } else {
            pendingChangesList
        }
    }

    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: ResponsiveDesign.spacing(16)) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading pending changes...")
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: ResponsiveDesign.spacing(20)) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: ResponsiveDesign.iconSize() * 3))
                .foregroundColor(.green)

            Text("No Pending Changes")
                .font(ResponsiveDesign.titleFont())
                .foregroundColor(.primary)

            Text("All configuration change requests have been processed.")
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding()
            }

            Button {
                Task {
                    await viewModel.loadPendingChanges()
                }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Pending Changes List
    private var pendingChangesList: some View {
        ScrollView {
            LazyVStack(spacing: ResponsiveDesign.spacing(16)) {
                // Success/Error messages
                if let success = viewModel.successMessage {
                    successBanner(success)
                }

                if let error = viewModel.errorMessage {
                    errorBanner(error)
                }

                // Header
                headerSection

                // Pending changes
                ForEach(viewModel.pendingChanges) { change in
                    PendingChangeCard(
                        change: change,
                        viewModel: viewModel
                    )
                }
            }
            .padding()
        }
    }

    // MARK: - Header Section
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("4-Eyes Approval Required")
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(.primary)
                Spacer()
                Text("\(viewModel.pendingCount)")
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.orange)
                    .clipShape(Capsule())
            }

            Text("The following configuration changes require approval from a second administrator before they can be applied.")
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    // MARK: - Success Banner
    private func successBanner(_ message: String) -> some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            Text(message)
                .font(ResponsiveDesign.bodyFont())
            Spacer()
            Button {
                viewModel.successMessage = nil
            } label: {
                Image(systemName: "xmark")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(ResponsiveDesign.spacing(8))
    }

    // MARK: - Error Banner
    private func errorBanner(_ message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(.red)
            Text(message)
                .font(ResponsiveDesign.bodyFont())
            Spacer()
            Button {
                viewModel.errorMessage = nil
            } label: {
                Image(systemName: "xmark")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(ResponsiveDesign.spacing(8))
    }

    // MARK: - Approval Sheet
    private var approvalSheet: some View {
        NavigationStack {
            VStack(spacing: ResponsiveDesign.spacing(24)) {
                Image(systemName: "checkmark.seal")
                    .font(.system(size: ResponsiveDesign.iconSize() * 2))
                    .foregroundColor(.green)

                Text("Approve Configuration Change")
                    .font(ResponsiveDesign.titleFont())

                if let changeId = viewModel.selectedChangeId,
                   let change = viewModel.pendingChanges.first(where: { $0.id == changeId }) {
                    changeDetails(change)
                }

                VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
                    Text("Approval Notes (optional)")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(.secondary)

                    TextField("Add notes...", text: $viewModel.approvalNotes, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...6)
                }

                Spacer()

                HStack(spacing: ResponsiveDesign.spacing(16)) {
                    Button("Cancel") {
                        viewModel.dismissSheets()
                    }
                    .buttonStyle(.bordered)

                    Button {
                        Task {
                            await viewModel.approveSelectedChange()
                        }
                    } label: {
                        if viewModel.isLoading {
                            ProgressView()
                        } else {
                            Text("Approve")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .disabled(viewModel.isLoading)
                }
            }
            .padding()
            .navigationTitle("Approve Change")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.dismissSheets()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Rejection Sheet
    private var rejectionSheet: some View {
        NavigationStack {
            VStack(spacing: ResponsiveDesign.spacing(24)) {
                Image(systemName: "xmark.seal")
                    .font(.system(size: ResponsiveDesign.iconSize() * 2))
                    .foregroundColor(.red)

                Text("Reject Configuration Change")
                    .font(ResponsiveDesign.titleFont())

                if let changeId = viewModel.selectedChangeId,
                   let change = viewModel.pendingChanges.first(where: { $0.id == changeId }) {
                    changeDetails(change)
                }

                VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
                    Text("Rejection Reason (required)")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(.secondary)

                    TextField("Provide reason for rejection...", text: $viewModel.rejectionReason, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...6)
                }

                if viewModel.rejectionReason.isEmpty {
                    Text("A reason is required to reject this change")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(.orange)
                }

                Spacer()

                HStack(spacing: ResponsiveDesign.spacing(16)) {
                    Button("Cancel") {
                        viewModel.dismissSheets()
                    }
                    .buttonStyle(.bordered)

                    Button {
                        Task {
                            await viewModel.rejectSelectedChange()
                        }
                    } label: {
                        if viewModel.isLoading {
                            ProgressView()
                        } else {
                            Text("Reject")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .disabled(viewModel.isLoading || viewModel.rejectionReason.isEmpty)
                }
            }
            .padding()
            .navigationTitle("Reject Change")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.dismissSheets()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Change Details
    private func changeDetails(_ change: PendingConfigurationChange) -> some View {
        VStack(spacing: ResponsiveDesign.spacing(12)) {
            HStack {
                Text(viewModel.formatParameterName(change.parameterName))
                    .font(ResponsiveDesign.headlineFont())
                Spacer()
            }

            HStack {
                VStack(alignment: .leading) {
                    Text("Current Value")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(.secondary)
                    Text(viewModel.formatValue(change.oldValue, for: change.parameterName))
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(.primary)
                }

                Spacer()

                Image(systemName: "arrow.right")
                    .foregroundColor(.secondary)

                Spacer()

                VStack(alignment: .trailing) {
                    Text("New Value")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(.secondary)
                    Text(viewModel.formatValue(change.newValue, for: change.parameterName))
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(.blue)
                        .fontWeight(.semibold)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
                Text("Reason: \(change.reason)")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(.secondary)
                Text("Requested by: \(change.requesterEmail ?? change.requesterId)")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(ResponsiveDesign.spacing(8))
    }
}

// MARK: - Pending Change Card
struct PendingChangeCard: View {
    let change: PendingConfigurationChange
    @ObservedObject var viewModel: PendingConfigurationChangesViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.formatParameterName(change.parameterName))
                        .font(ResponsiveDesign.headlineFont())
                        .foregroundColor(.primary)

                    Text(viewModel.formatDate(change.createdAt))
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Expiry indicator
                Text(viewModel.timeRemaining(until: change.expiresAt))
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(change.expiresAt.timeIntervalSinceNow < 86400 ? .orange : .secondary)
            }

            // Value change
            HStack(spacing: ResponsiveDesign.spacing(12)) {
                VStack(alignment: .leading) {
                    Text("Current")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(.secondary)
                    Text(viewModel.formatValue(change.oldValue, for: change.parameterName))
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(.primary)
                }

                Image(systemName: "arrow.right.circle.fill")
                    .foregroundColor(.blue)

                VStack(alignment: .leading) {
                    Text("Proposed")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(.secondary)
                    Text(viewModel.formatValue(change.newValue, for: change.parameterName))
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(.blue)
                        .fontWeight(.semibold)
                }

                Spacer()
            }

            // Reason
            VStack(alignment: .leading, spacing: 2) {
                Text("Reason:")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(.secondary)
                Text(change.reason)
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(.primary)
                    .lineLimit(2)
            }

            // Requester info
            HStack {
                Image(systemName: "person.circle")
                    .foregroundColor(.secondary)
                Text(change.requesterEmail ?? change.requesterId)
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(.secondary)
                Text("(\(change.requesterRole))")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(.secondary)
            }

            Divider()

            // Action buttons
            HStack(spacing: ResponsiveDesign.spacing(12)) {
                Button {
                    viewModel.selectForRejection(change)
                } label: {
                    Label("Reject", systemImage: "xmark.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.red)

                Button {
                    viewModel.selectForApproval(change)
                } label: {
                    Label("Approve", systemImage: "checkmark.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(ResponsiveDesign.spacing(12))
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Compact Badge for Navigation
struct PendingApprovalsNavigationLink: View {
    @Environment(\.appServices) private var appServices
    @State private var pendingCount = 0

    var body: some View {
        NavigationLink {
            PendingConfigurationChangesView()
        } label: {
            HStack {
                Label("Pending Approvals", systemImage: "checkmark.seal")
                Spacer()
                if pendingCount > 0 {
                    Text("\(pendingCount)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.orange)
                        .clipShape(Capsule())
                }
            }
        }
        .task {
            await loadPendingCount()
        }
    }

    private func loadPendingCount() async {
        guard let service = appServices.configurationService as? ConfigurationService else { return }
        do {
            let changes = try await service.getPendingConfigurationChanges()
            pendingCount = changes.count
        } catch {
            pendingCount = 0
        }
    }
}

// MARK: - Preview
#Preview {
    PendingConfigurationChangesView()
        .environment(\.appServices, AppServices.live)
}
