import SwiftUI

/// Sheet for approving a pending configuration change.
struct PendingConfigurationApprovalSheet: View {
    @ObservedObject var viewModel: PendingConfigurationChangesViewModel

    var body: some View {
        NavigationStack {
            VStack(spacing: ResponsiveDesign.spacing(24)) {
                Image(systemName: "checkmark.seal")
                    .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize() * 2))
                    .foregroundColor(.green)

                Text("Approve Configuration Change")
                    .font(ResponsiveDesign.titleFont())

                if let changeId = viewModel.selectedChangeId,
                   let change = viewModel.pendingChanges.first(where: { $0.id == changeId }) {
                    PendingConfigurationChangeDetailsView(change: change, viewModel: viewModel)
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
}
