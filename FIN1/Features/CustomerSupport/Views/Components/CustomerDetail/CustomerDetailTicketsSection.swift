import SwiftUI

/// Support tickets section for customer detail.
struct CustomerDetailTicketsSection: View {
    @ObservedObject var viewModel: CustomerSupportDashboardViewModel
    var onSelectTicket: (SupportTicket) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            HStack {
                Image(systemName: "ticket.fill")
                    .foregroundColor(AppTheme.accentLightBlue)

                Text("Support-Tickets")
                    .font(ResponsiveDesign.headlineFont())
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.fontColor)

                Spacer()

                if viewModel.isLoadingCustomerTickets {
                    ProgressView()
                        .scaleEffect(0.8)
                } else if !viewModel.customerTickets.isEmpty {
                    Text("\(viewModel.customerTickets.count)")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.7))
                        .padding(.horizontal, ResponsiveDesign.spacing(8))
                        .padding(.vertical, ResponsiveDesign.spacing(4))
                        .background(AppTheme.accentLightBlue.opacity(0.1))
                        .cornerRadius(ResponsiveDesign.spacing(6))
                }
            }

            if viewModel.isLoadingCustomerTickets {
                HStack {
                    Spacer()
                    ProgressView("Lade Tickets...")
                        .font(ResponsiveDesign.captionFont())
                    Spacer()
                }
                .padding()
            } else if viewModel.customerTickets.isEmpty {
                VStack(spacing: ResponsiveDesign.spacing(8)) {
                    Image(systemName: "tray")
                        .font(ResponsiveDesign.headlineFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.3))

                    Text("Keine Support-Tickets vorhanden")
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else {
                VStack(spacing: ResponsiveDesign.spacing(8)) {
                    if !viewModel.activeCustomerTickets.isEmpty {
                        Text("Aktive Tickets")
                            .font(ResponsiveDesign.captionFont())
                            .fontWeight(.medium)
                            .foregroundColor(AppTheme.fontColor.opacity(0.7))
                            .frame(maxWidth: .infinity, alignment: .leading)

                        ForEach(viewModel.activeCustomerTickets) { ticket in
                            CustomerTicketRow(ticket: ticket, viewModel: viewModel) {
                                onSelectTicket(ticket)
                            }
                        }
                    }

                    if !viewModel.closedCustomerTickets.isEmpty {
                        if !viewModel.activeCustomerTickets.isEmpty {
                            Divider()
                                .padding(.vertical, ResponsiveDesign.spacing(4))
                        }

                        Text("Abgeschlossene Tickets")
                            .font(ResponsiveDesign.captionFont())
                            .fontWeight(.medium)
                            .foregroundColor(AppTheme.fontColor.opacity(0.7))
                            .frame(maxWidth: .infinity, alignment: .leading)

                        ForEach(viewModel.closedCustomerTickets.prefix(3)) { ticket in
                            CustomerTicketRow(ticket: ticket, viewModel: viewModel) {
                                onSelectTicket(ticket)
                            }
                        }

                        if viewModel.closedCustomerTickets.count > 3 {
                            Text("+ \(viewModel.closedCustomerTickets.count - 3) weitere abgeschlossene Tickets")
                                .font(ResponsiveDesign.captionFont())
                                .foregroundColor(AppTheme.accentLightBlue)
                                .frame(maxWidth: .infinity)
                                .padding(.top, ResponsiveDesign.spacing(4))
                        }
                    }
                }
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }
}
