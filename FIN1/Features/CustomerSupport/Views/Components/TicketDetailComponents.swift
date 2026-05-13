import SwiftUI

// MARK: - Ticket Response Row

struct TicketResponseRow: View {
    let response: TicketResponse

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            HStack {
                Image(systemName: self.response.responseType.icon)
                    .foregroundColor(self.responseTypeColor)
                    .font(ResponsiveDesign.captionFont())

                Text(self.response.agentName)
                    .font(ResponsiveDesign.bodyFont())
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.fontColor)

                Spacer()

                Text(self.response.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.7))
            }

            Text(self.response.message)
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor)

            // Show solution details if present
            if let solution = response.solutionDetails {
                self.solutionDetailsView(solution)
            }

            // Badges
            HStack(spacing: ResponsiveDesign.spacing(6)) {
                if self.response.isInternal {
                    CSStatusBadge(text: "Intern", color: AppTheme.accentOrange)
                }
                if self.response.responseType != .message {
                    CSStatusBadge(text: self.response.responseType.displayName, color: self.responseTypeColor)
                }
            }
        }
        .padding()
        .background(self.response.isInternal ? AppTheme.accentOrange.opacity(0.05) : AppTheme.screenBackground)
        .cornerRadius(ResponsiveDesign.spacing(8))
        .overlay(
            RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(8))
                .stroke(self.response.isInternal ? AppTheme.accentOrange.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func solutionDetailsView(_ solution: SolutionDetails) -> some View {
        HStack(spacing: ResponsiveDesign.spacing(6)) {
            Image(systemName: solution.solutionType.icon)
                .foregroundColor(AppTheme.accentGreen)
            Text(solution.solutionType.displayName)
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.accentGreen)

            if let article = solution.helpCenterArticleTitle {
                Text("• \(article)")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.7))
            }
        }
        .padding(ResponsiveDesign.spacing(6))
        .background(AppTheme.accentGreen.opacity(0.1))
        .cornerRadius(ResponsiveDesign.spacing(6))
    }

    private var responseTypeColor: Color {
        switch self.response.responseType {
        case .message: return AppTheme.accentLightBlue
        case .internalNote: return AppTheme.accentOrange
        case .solution: return AppTheme.accentGreen
        case .escalation: return AppTheme.accentRed
        case .statusChange: return Color.purple
        case .assignment: return Color.cyan
        }
    }
}

// MARK: - CS Info Row

struct CSInfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(self.label)
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))
                .frame(width: 100, alignment: .leading)

            Text(self.value)
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor)

            Spacer()
        }
    }
}

// MARK: - Ticket Detail Header

struct TicketDetailHeader: View {
    let ticket: SupportTicket

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(12)) {
            HStack {
                Image(systemName: "ticket.fill")
                    .font(ResponsiveDesign.titleFont())
                    .foregroundColor(self.ticketStatusColor)

                VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
                    Text(self.ticket.ticketNumber)
                        .font(ResponsiveDesign.titleFont())
                        .fontWeight(.bold)
                        .foregroundColor(AppTheme.fontColor)

                    Text(self.ticket.subject)
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.7))
                }

                Spacer()

                CSStatusBadge(text: self.ticket.status.displayName, color: self.ticketStatusColor)
            }

            HStack(spacing: ResponsiveDesign.spacing(8)) {
                CSStatusBadge(text: self.ticket.priority.displayName, color: self.priorityColor)
                if let assignedTo = ticket.assignedTo {
                    Text("Zugewiesen: \(assignedTo)")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.7))
                }
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    private var ticketStatusColor: Color {
        switch self.ticket.status {
        case .open, .inProgress: return AppTheme.accentLightBlue
        case .waitingForCustomer: return AppTheme.accentOrange
        case .escalated: return AppTheme.accentRed
        case .resolved, .closed: return AppTheme.accentGreen
        case .archived: return AppTheme.fontColor.opacity(0.5)
        }
    }

    private var priorityColor: Color {
        switch self.ticket.priority {
        case .low: return AppTheme.accentGreen
        case .medium: return AppTheme.accentLightBlue
        case .high: return AppTheme.accentOrange
        case .urgent: return AppTheme.accentRed
        }
    }
}

// MARK: - Ticket Info Section

struct TicketInfoSection: View {
    let ticket: SupportTicket

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            Text("Ticket-Informationen")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.fontColor)

            VStack(spacing: ResponsiveDesign.spacing(8)) {
                CSInfoRow(label: "Kunde", value: self.ticket.customerName)
                CSInfoRow(label: "Nutzer-ID", value: self.ticket.userId)
                CSInfoRow(
                    label: "Erstellt am",
                    value: self.ticket.createdAt.formatted(date: .abbreviated, time: .omitted)
                )
                CSInfoRow(
                    label: "Aktualisiert am",
                    value: self.ticket.updatedAt.formatted(date: .abbreviated, time: .omitted)
                )
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }
}

// MARK: - Ticket Description Section

struct TicketDescriptionSection: View {
    let ticket: SupportTicket

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            Text("Beschreibung")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.fontColor)

            Text(self.ticket.description)
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.screenBackground)
                .cornerRadius(ResponsiveDesign.spacing(10))
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }
}

// MARK: - Ticket Responses Section

struct TicketResponsesSection: View {
    let responses: [TicketResponse]

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            Text("Antworten (\(self.responses.count))")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.fontColor)

            VStack(spacing: ResponsiveDesign.spacing(8)) {
                ForEach(self.responses) { response in
                    TicketResponseRow(response: response)
                }
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }
}

