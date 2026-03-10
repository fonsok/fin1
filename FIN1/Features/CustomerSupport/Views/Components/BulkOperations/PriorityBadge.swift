import SwiftUI

/// Small priority badge for ticket rows.
struct PriorityBadge: View {
    let priority: SupportTicket.TicketPriority

    var body: some View {
        Text(priority.rawValue)
            .font(ResponsiveDesign.captionFont())
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, ResponsiveDesign.spacing(6))
            .padding(.vertical, ResponsiveDesign.spacing(2))
            .background(priorityColor)
            .cornerRadius(ResponsiveDesign.spacing(4))
    }

    private var priorityColor: Color {
        switch priority {
        case .urgent: return AppTheme.accentRed
        case .high: return AppTheme.accentOrange
        case .medium: return AppTheme.accentLightBlue
        case .low: return AppTheme.fontColor.opacity(0.5)
        }
    }
}
