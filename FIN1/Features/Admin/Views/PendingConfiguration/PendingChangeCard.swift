import SwiftUI

/// Card for a single pending configuration change (diff + approve/reject).
struct PendingChangeCard: View {
    let change: PendingConfigurationChange
    @ObservedObject var viewModel: PendingConfigurationChangesViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
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

                Text(viewModel.timeRemaining(until: change.expiresAt))
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(change.expiresAt.timeIntervalSinceNow < 86400 ? .orange : .secondary)
            }

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

            VStack(alignment: .leading, spacing: 2) {
                Text("Reason:")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(.secondary)
                Text(change.reason)
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(.primary)
                    .lineLimit(2)
            }

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
