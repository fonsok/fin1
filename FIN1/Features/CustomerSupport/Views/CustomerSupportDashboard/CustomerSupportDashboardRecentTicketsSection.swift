import SwiftUI

/// Recent/active tickets section for CSR dashboard.
struct CustomerSupportDashboardRecentTicketsSection: View {
    @ObservedObject var viewModel: CustomerSupportDashboardViewModel

    private var activeTickets: [SupportTicket] {
        viewModel.supportTickets.filter { ticket in
            ticket.status != .resolved &&
            ticket.status != .closed &&
            ticket.status != .archived
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            HStack {
                Text("Aktuelle Tickets")
                    .font(ResponsiveDesign.headlineFont())
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.fontColor)

                Spacer()

                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }

            if activeTickets.isEmpty {
                VStack(spacing: ResponsiveDesign.spacing(8)) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(ResponsiveDesign.largeTitleFont())
                        .foregroundColor(AppTheme.accentGreen.opacity(0.5))

                    Text("Keine aktiven Tickets")
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.7))

                    Text("Alle Tickets wurden bearbeitet")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.5))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, ResponsiveDesign.spacing(20))
            } else {
                VStack(spacing: ResponsiveDesign.spacing(8)) {
                    ForEach(activeTickets.prefix(5)) { ticket in
                        TicketRow(ticket: ticket) {
                            viewModel.selectTicket(ticket)
                        }
                    }

                    if activeTickets.count > 5 {
                        Text("+ \(activeTickets.count - 5) weitere aktive Tickets")
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(AppTheme.accentLightBlue)
                            .frame(maxWidth: .infinity)
                            .padding(.top, ResponsiveDesign.spacing(4))
                    }
                }
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }
}
