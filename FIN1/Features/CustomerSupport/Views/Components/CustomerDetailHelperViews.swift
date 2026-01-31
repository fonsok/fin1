import SwiftUI

// MARK: - Customer Detail Helper Views
/// Reusable components extracted from CustomerDetailSheet to maintain file size limits

// MARK: - KYC Status Row

struct KYCStatusRow: View {
    let title: String
    let isComplete: Bool

    var body: some View {
        HStack {
            Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isComplete ? AppTheme.accentGreen : AppTheme.fontColor.opacity(0.3))

            Text(title)
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor)

            Spacer()
        }
    }
}

// MARK: - Contact Info Row

struct CSContactInfoRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: ResponsiveDesign.spacing(12)) {
            Image(systemName: icon)
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.accentLightBlue)
                .frame(width: ResponsiveDesign.spacing(20))

            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(2)) {
                Text(label)
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.7))

                Text(value)
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor)
            }

            Spacer()
        }
    }
}

// MARK: - Investment Summary Card

struct InvestmentSummaryCard: View {
    let investment: CustomerInvestmentSummary
    var onTap: (() -> Void)? = nil

    var body: some View {
        Button(action: { onTap?() }) {
            HStack {
                VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
                    HStack {
                        Text(investment.investmentNumber)
                            .font(ResponsiveDesign.captionFont())
                            .fontWeight(.medium)
                            .foregroundColor(AppTheme.accentLightBlue)

                        Spacer()

                        Text(investment.amount.formattedAsLocalizedCurrency())
                            .font(ResponsiveDesign.bodyFont())
                            .fontWeight(.semibold)
                            .foregroundColor(AppTheme.fontColor)
                    }

                    HStack {
                        Text("Trader: \(investment.traderName)")
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(AppTheme.fontColor.opacity(0.7))

                        Spacer()

                        Text(String(format: "%.1f%%", investment.returnPercentage))
                            .font(ResponsiveDesign.captionFont())
                            .fontWeight(.medium)
                            .foregroundColor(investment.returnPercentage >= 0 ? AppTheme.accentGreen : AppTheme.accentRed)
                    }
                }

                if onTap != nil {
                    Image(systemName: "chevron.right")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.5))
                }
            }
            .padding()
            .background(AppTheme.screenBackground)
            .cornerRadius(ResponsiveDesign.spacing(8))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Trade Summary Card

struct TradeSummaryCard: View {
    let trade: CustomerTradeSummary
    var onTap: (() -> Void)? = nil

    var body: some View {
        Button(action: { onTap?() }) {
            HStack {
                VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
                    HStack {
                        Text(trade.tradeNumber)
                            .font(ResponsiveDesign.captionFont())
                            .fontWeight(.medium)
                            .foregroundColor(AppTheme.accentLightBlue)

                        Spacer()

                        CSStatusBadge(
                            text: trade.status.capitalized,
                            color: statusColor
                        )
                    }

                    HStack {
                        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
                            Text("\(trade.symbol) • \(trade.direction)")
                                .font(ResponsiveDesign.bodyFont())
                                .fontWeight(.medium)
                                .foregroundColor(AppTheme.fontColor)

                            Text("\(trade.quantity) @ \(trade.entryPrice.formattedAsLocalizedCurrency())")
                                .font(ResponsiveDesign.captionFont())
                                .foregroundColor(AppTheme.fontColor.opacity(0.7))
                        }

                        Spacer()

                        if let profitLoss = trade.profitLoss {
                            VStack(alignment: .trailing, spacing: ResponsiveDesign.spacing(2)) {
                                Text(profitLoss.formattedAsLocalizedCurrency())
                                    .font(ResponsiveDesign.bodyFont())
                                    .fontWeight(.semibold)
                                    .foregroundColor(profitLoss >= 0 ? AppTheme.accentGreen : AppTheme.accentRed)

                                Text("P&L")
                                    .font(ResponsiveDesign.captionFont())
                                    .foregroundColor(AppTheme.fontColor.opacity(0.7))
                            }
                        } else if let currentPrice = trade.currentPrice {
                            VStack(alignment: .trailing, spacing: ResponsiveDesign.spacing(2)) {
                                Text(currentPrice.formattedAsLocalizedCurrency())
                                    .font(ResponsiveDesign.bodyFont())
                                    .fontWeight(.semibold)
                                    .foregroundColor(AppTheme.fontColor)

                                Text("Aktuell")
                                    .font(ResponsiveDesign.captionFont())
                                    .foregroundColor(AppTheme.fontColor.opacity(0.7))
                            }
                        }
                    }
                }

                if onTap != nil {
                    Image(systemName: "chevron.right")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.5))
                }
            }
            .padding()
            .background(AppTheme.screenBackground)
            .cornerRadius(ResponsiveDesign.spacing(8))
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var statusColor: Color {
        switch trade.status.lowercased() {
        case "open", "active":
            return AppTheme.accentOrange
        case "closed", "completed":
            return AppTheme.accentGreen
        default:
            return AppTheme.fontColor.opacity(0.7)
        }
    }
}

// MARK: - CS Action Button

struct CSActionButton: View {
    let icon: String
    let title: String
    var subtitle: String? = nil
    let color: Color
    var action: (() -> Void)?

    var body: some View {
        Button(action: { action?() }) {
            HStack(spacing: ResponsiveDesign.spacing(12)) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .frame(width: ResponsiveDesign.spacing(24))

                VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(2)) {
                    Text(title)
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(AppTheme.fontColor)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(AppTheme.fontColor.opacity(0.6))
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.5))
            }
            .padding()
            .background(AppTheme.screenBackground)
            .cornerRadius(ResponsiveDesign.spacing(8))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Document Row

struct DocumentRow: View {
    let document: CustomerDocumentSummary

    var body: some View {
        HStack(spacing: ResponsiveDesign.spacing(12)) {
            // Document icon
            Image(systemName: documentIcon(for: document.type))
                .font(.title3)
                .foregroundColor(document.isVerified ? AppTheme.accentGreen : AppTheme.accentOrange)
                .frame(width: ResponsiveDesign.spacing(32))

            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
                Text(document.name)
                    .font(ResponsiveDesign.bodyFont())
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.fontColor)

                HStack(spacing: ResponsiveDesign.spacing(8)) {
                    Text(document.category)
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.7))

                    Text("•")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.5))

                    Text(document.uploadedAt.formatted(date: .abbreviated, time: .omitted))
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.7))
                }
            }

            Spacer()

            // Verification status badge
            CSStatusBadge(
                text: document.isVerified ? "Verifiziert" : "Ausstehend",
                color: document.isVerified ? AppTheme.accentGreen : AppTheme.accentOrange
            )
        }
        .padding()
        .background(AppTheme.screenBackground)
        .cornerRadius(ResponsiveDesign.spacing(8))
    }

    private func documentIcon(for type: String) -> String {
        switch type.lowercased() {
        case "identity", "id":
            return "person.text.rectangle.fill"
        case "address":
            return "mappin.circle.fill"
        case "proof":
            return "doc.badge.checkmark.fill"
        default:
            return "doc.fill"
        }
    }
}

// MARK: - Customer Ticket Row

struct CustomerTicketRow: View {
    let ticket: SupportTicket
    let viewModel: CustomerSupportDashboardViewModel
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: ResponsiveDesign.spacing(12)) {
                // Status indicator
                Circle()
                    .fill(ticketStatusColor)
                    .frame(width: ResponsiveDesign.spacing(10), height: ResponsiveDesign.spacing(10))

                VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
                    HStack {
                        Text(ticket.ticketNumber)
                            .font(ResponsiveDesign.captionFont())
                            .fontWeight(.medium)
                            .foregroundColor(AppTheme.accentLightBlue)

                        Spacer()

                        Text(ticket.createdAt.formatted(date: .abbreviated, time: .omitted))
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(AppTheme.fontColor.opacity(0.5))
                    }

                    Text(ticket.subject)
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(AppTheme.fontColor)
                        .lineLimit(1)

                    HStack(spacing: ResponsiveDesign.spacing(8)) {
                        CSStatusBadge(
                            text: ticketStatusText,
                            color: ticketStatusColor
                        )

                        if ticket.priority == .high || ticket.priority == .urgent {
                            CSStatusBadge(
                                text: ticket.priority == .urgent ? "Dringend" : "Hoch",
                                color: AppTheme.accentRed
                            )
                        }

                        if let agentId = ticket.assignedTo {
                            Text("• \(viewModel.getAgentName(for: agentId))")
                                .font(ResponsiveDesign.captionFont())
                                .foregroundColor(AppTheme.fontColor.opacity(0.6))
                                .lineLimit(1)
                        }
                    }
                }

                Image(systemName: "chevron.right")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.5))
            }
            .padding()
            .background(AppTheme.screenBackground)
            .cornerRadius(ResponsiveDesign.spacing(8))
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var ticketStatusColor: Color {
        switch ticket.status {
        case .open:
            return AppTheme.accentLightBlue
        case .inProgress:
            return AppTheme.accentOrange
        case .waitingForCustomer:
            return AppTheme.accentOrange.opacity(0.7)
        case .escalated:
            return AppTheme.accentRed
        case .resolved:
            return AppTheme.accentGreen
        case .closed:
            return AppTheme.fontColor.opacity(0.5)
        case .archived:
            return AppTheme.fontColor.opacity(0.3)
        }
    }

    private var ticketStatusText: String {
        switch ticket.status {
        case .open: return "Offen"
        case .inProgress: return "In Bearbeitung"
        case .waitingForCustomer: return "Warte auf Kunde"
        case .escalated: return "Eskaliert"
        case .resolved: return "Gelöst"
        case .closed: return "Geschlossen"
        case .archived: return "Archiviert"
        }
    }
}

