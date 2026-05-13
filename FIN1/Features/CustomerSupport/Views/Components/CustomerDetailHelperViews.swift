import SwiftUI

// MARK: - Customer Detail Helper Views
/// Reusable components extracted from CustomerDetailSheet to maintain file size limits

// MARK: - KYC Status Row

struct KYCStatusRow: View {
    let title: String
    let isComplete: Bool

    var body: some View {
        HStack {
            Image(systemName: self.isComplete ? "checkmark.circle.fill" : "circle")
                .foregroundColor(self.isComplete ? AppTheme.accentGreen : AppTheme.fontColor.opacity(0.3))

            Text(self.title)
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
            Image(systemName: self.icon)
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.accentLightBlue)
                .frame(width: ResponsiveDesign.spacing(20))

            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(2)) {
                Text(self.label)
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.7))

                Text(self.value)
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
        Button(action: { self.onTap?() }) {
            HStack {
                VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
                    HStack {
                        Text(self.investment.investmentNumber)
                            .font(ResponsiveDesign.captionFont())
                            .fontWeight(.medium)
                            .foregroundColor(AppTheme.accentLightBlue)

                        Spacer()

                        Text(self.investment.amount.formattedAsLocalizedCurrency())
                            .font(ResponsiveDesign.bodyFont())
                            .fontWeight(.semibold)
                            .foregroundColor(AppTheme.fontColor)
                    }

                    HStack {
                        Text("Trader: \(self.investment.traderName)")
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(AppTheme.fontColor.opacity(0.7))

                        Spacer()

                        if let returnPercentage = investment.returnPercentage {
                            Text("Return: \(String(format: "%.1f%%", returnPercentage))")
                                .font(ResponsiveDesign.captionFont())
                                .fontWeight(.medium)
                                .foregroundColor(returnPercentage >= 0 ? AppTheme.accentGreen : AppTheme.accentRed)
                        } else {
                            Text("Return: pending")
                                .font(ResponsiveDesign.captionFont())
                                .fontWeight(.medium)
                                .foregroundColor(AppTheme.fontColor.opacity(0.7))
                        }
                    }
                }

                if self.onTap != nil {
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
        Button(action: { self.onTap?() }) {
            HStack {
                VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
                    HStack {
                        Text(self.trade.tradeNumber)
                            .font(ResponsiveDesign.captionFont())
                            .fontWeight(.medium)
                            .foregroundColor(AppTheme.accentLightBlue)

                        Spacer()

                        CSStatusBadge(
                            text: self.trade.status.capitalized,
                            color: self.statusColor
                        )
                    }

                    HStack {
                        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
                            Text("\(self.trade.symbol) • \(self.trade.direction)")
                                .font(ResponsiveDesign.bodyFont())
                                .fontWeight(.medium)
                                .foregroundColor(AppTheme.fontColor)

                            Text("\(self.trade.quantity) @ \(self.trade.entryPrice.formattedAsLocalizedCurrency())")
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

                if self.onTap != nil {
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
        switch self.trade.status.lowercased() {
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
        Button(action: { self.action?() }) {
            HStack(spacing: ResponsiveDesign.spacing(12)) {
                Image(systemName: self.icon)
                    .foregroundColor(self.color)
                    .frame(width: ResponsiveDesign.spacing(24))

                VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(2)) {
                    Text(self.title)
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
            Image(systemName: self.documentIcon(for: self.document.type))
                .font(ResponsiveDesign.headlineFont())
                .foregroundColor(self.document.isVerified ? AppTheme.accentGreen : AppTheme.accentOrange)
                .frame(width: ResponsiveDesign.spacing(32))

            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
                Text(self.document.name)
                    .font(ResponsiveDesign.bodyFont())
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.fontColor)

                HStack(spacing: ResponsiveDesign.spacing(8)) {
                    Text(self.document.category)
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.7))

                    Text("•")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.5))

                    Text(self.document.uploadedAt.formatted(date: .abbreviated, time: .omitted))
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.7))
                }
            }

            Spacer()

            // Verification status badge
            CSStatusBadge(
                text: self.document.isVerified ? "Verifiziert" : "Ausstehend",
                color: self.document.isVerified ? AppTheme.accentGreen : AppTheme.accentOrange
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
        Button(action: self.onTap) {
            HStack(spacing: ResponsiveDesign.spacing(12)) {
                // Status indicator
                Circle()
                    .fill(self.ticketStatusColor)
                    .frame(width: ResponsiveDesign.spacing(10), height: ResponsiveDesign.spacing(10))

                VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
                    HStack {
                        Text(self.ticket.ticketNumber)
                            .font(ResponsiveDesign.captionFont())
                            .fontWeight(.medium)
                            .foregroundColor(AppTheme.accentLightBlue)

                        Spacer()

                        Text(self.ticket.createdAt.formatted(date: .abbreviated, time: .omitted))
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(AppTheme.fontColor.opacity(0.5))
                    }

                    Text(self.ticket.subject)
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(AppTheme.fontColor)
                        .lineLimit(1)

                    HStack(spacing: ResponsiveDesign.spacing(8)) {
                        CSStatusBadge(
                            text: self.ticketStatusText,
                            color: self.ticketStatusColor
                        )

                        if self.ticket.priority == .high || self.ticket.priority == .urgent {
                            CSStatusBadge(
                                text: self.ticket.priority == .urgent ? "Dringend" : "Hoch",
                                color: AppTheme.accentRed
                            )
                        }

                        if let agentId = ticket.assignedTo {
                            Text("• \(self.viewModel.getAgentName(for: agentId))")
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
        switch self.ticket.status {
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
        switch self.ticket.status {
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

