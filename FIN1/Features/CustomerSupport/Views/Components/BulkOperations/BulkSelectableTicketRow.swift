import SwiftUI

/// Selectable row for bulk operations ticket list.
struct BulkSelectableTicketRow: View {
    let ticket: SupportTicket
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: self.onToggle) {
            HStack(spacing: ResponsiveDesign.spacing(12)) {
                Image(systemName: self.isSelected ? "checkmark.square.fill" : "square")
                    .foregroundColor(self.isSelected ? AppTheme.accentLightBlue : AppTheme.fontColor.opacity(0.4))
                    .font(ResponsiveDesign.headlineFont())

                VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
                    HStack {
                        Text(self.ticket.ticketNumber)
                            .font(ResponsiveDesign.captionFont())
                            .fontWeight(.semibold)
                            .foregroundColor(AppTheme.accentLightBlue)

                        CSStatusBadge(text: self.ticket.status.displayName, color: self.statusColor)

                        PriorityBadge(priority: self.ticket.priority)
                    }

                    Text(self.ticket.subject)
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(AppTheme.fontColor)
                        .lineLimit(1)

                    Text(self.ticket.customerName)
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.7))
                }

                Spacer()
            }
            .padding()
            .background(self.isSelected ? AppTheme.accentLightBlue.opacity(0.1) : AppTheme.sectionBackground)
            .cornerRadius(ResponsiveDesign.spacing(10))
            .overlay(
                RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(10))
                    .stroke(self.isSelected ? AppTheme.accentLightBlue : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var statusColor: Color {
        switch self.ticket.status {
        case .open, .inProgress: return AppTheme.accentLightBlue
        case .waitingForCustomer: return AppTheme.accentOrange
        case .escalated: return AppTheme.accentRed
        case .resolved, .closed: return AppTheme.accentGreen
        case .archived: return AppTheme.fontColor.opacity(0.5)
        }
    }
}
