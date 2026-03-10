import SwiftUI

// MARK: - Customer Search Result Row

struct CustomerSearchResultRow: View {
    let result: CustomerSearchResult
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: ResponsiveDesign.spacing(12)) {
                Circle()
                    .fill(AppTheme.accentLightBlue.opacity(0.2))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Text(result.fullName.prefix(2).uppercased())
                            .font(ResponsiveDesign.captionFont())
                            .fontWeight(.bold)
                            .foregroundColor(AppTheme.accentLightBlue)
                    )

                VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(2)) {
                    Text(result.fullName)
                        .font(ResponsiveDesign.bodyFont())
                        .fontWeight(.medium)
                        .foregroundColor(AppTheme.fontColor)

                    Text(result.email)
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.7))

                    HStack(spacing: ResponsiveDesign.spacing(8)) {
                        CSStatusBadge(text: result.role.capitalized, color: AppTheme.accentLightBlue)
                        CSStatusBadge(
                            text: result.accountStatus.displayName,
                            color: statusColor(for: result.accountStatus)
                        )
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.5))
            }
            .padding()
            .background(AppTheme.screenBackground)
            .cornerRadius(ResponsiveDesign.spacing(10))
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func statusColor(for status: CustomerSearchResult.AccountStatus) -> Color {
        switch status {
        case .active: return AppTheme.accentGreen
        case .locked: return AppTheme.accentRed
        case .pendingVerification: return AppTheme.accentOrange
        case .suspended: return AppTheme.fontColor.opacity(0.5)
        }
    }
}

// MARK: - Status Badge

struct CSStatusBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(ResponsiveDesign.captionFont())
            .fontWeight(.medium)
            .foregroundColor(color)
            .padding(.horizontal, ResponsiveDesign.spacing(8))
            .padding(.vertical, ResponsiveDesign.spacing(2))
            .background(color.opacity(0.15))
            .cornerRadius(ResponsiveDesign.spacing(4))
    }
}

// MARK: - Quick Action Card

struct QuickActionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let isEnabled: Bool
    var badge: String?
    var action: (() -> Void)?

    var body: some View {
        Button(action: {
            if isEnabled {
                action?()
            }
        }) {
            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
                HStack {
                    Image(systemName: icon)
                        .font(ResponsiveDesign.headlineFont())
                        .foregroundColor(isEnabled ? color : AppTheme.fontColor.opacity(0.3))

                    Spacer()

                    if let badge = badge {
                        Text(badge)
                            .font(ResponsiveDesign.captionFont())
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, ResponsiveDesign.spacing(6))
                            .padding(.vertical, ResponsiveDesign.spacing(2))
                            .background(color)
                            .cornerRadius(ResponsiveDesign.spacing(8))
                    }
                }

                Text(title)
                    .font(ResponsiveDesign.captionFont())
                    .fontWeight(.semibold)
                    .foregroundColor(isEnabled ? AppTheme.fontColor : AppTheme.fontColor.opacity(0.5))

                Text(subtitle)
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.5))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(AppTheme.screenBackground)
            .cornerRadius(ResponsiveDesign.spacing(10))
            .overlay(
                RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(10))
                    .stroke(isEnabled ? color.opacity(0.3) : AppTheme.fontColor.opacity(0.1), lineWidth: 1)
            )
            .opacity(isEnabled ? 1 : 0.6)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!isEnabled)
    }
}

// MARK: - Small Action Button

struct SmallActionButton: View {
    let icon: String
    let title: String
    let color: Color
    var action: (() -> Void)?

    var body: some View {
        Button(action: { action?() }) {
            HStack(spacing: ResponsiveDesign.spacing(8)) {
                Image(systemName: icon)
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(color)

                Text(title)
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor)
            }
            .padding(.horizontal, ResponsiveDesign.spacing(12))
            .padding(.vertical, ResponsiveDesign.spacing(10))
            .background(AppTheme.screenBackground)
            .cornerRadius(ResponsiveDesign.spacing(8))
            .overlay(
                RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(8))
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Ticket Row

struct TicketRow: View {
    let ticket: SupportTicket
    let onSelect: () -> Void

    private var slaInfo: SLAInfo {
        ticket.getSLAInfo()
    }

    private var showSLABadge: Bool {
        // Show SLA badge only for active tickets that aren't resolved/closed
        ticket.status != .resolved && ticket.status != .closed && ticket.status != .archived
    }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: ResponsiveDesign.spacing(12)) {
                VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
                    HStack {
                        Text(ticket.ticketNumber)
                            .font(ResponsiveDesign.captionFont())
                            .fontWeight(.medium)
                            .foregroundColor(AppTheme.accentLightBlue)

                        CSStatusBadge(text: ticket.status.displayName, color: ticketStatusColor)

                        // SLA Badge
                        if showSLABadge {
                            SLABadge(slaInfo: slaInfo, showTime: true)
                        }
                    }

                    Text(ticket.subject)
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(AppTheme.fontColor)
                        .lineLimit(1)

                    HStack {
                        Text(ticket.customerName)
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(AppTheme.fontColor.opacity(0.7))

                        if let agentName = ticket.assignedTo {
                            Text("•")
                                .foregroundColor(AppTheme.fontColor.opacity(0.3))
                            Image(systemName: "person.fill")
                                .font(ResponsiveDesign.captionFont())
                                .foregroundColor(AppTheme.fontColor.opacity(0.5))
                            Text(agentName.replacingOccurrences(of: "user:", with: "").components(separatedBy: "@").first ?? "")
                                .font(ResponsiveDesign.captionFont())
                                .foregroundColor(AppTheme.fontColor.opacity(0.5))
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.5))
            }
            .padding()
            .background(AppTheme.screenBackground)
            .cornerRadius(ResponsiveDesign.spacing(10))
            .overlay(
                RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(10))
                    .stroke(slaBorderColor, lineWidth: slaBorderColor == .clear ? 0 : 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var ticketStatusColor: Color {
        switch ticket.status {
        case .open, .inProgress: return AppTheme.accentLightBlue
        case .waitingForCustomer: return AppTheme.accentOrange
        case .escalated: return AppTheme.accentRed
        case .resolved, .closed: return AppTheme.accentGreen
        case .archived: return AppTheme.fontColor.opacity(0.5)
        }
    }

    private var slaBorderColor: Color {
        guard showSLABadge else { return .clear }
        switch slaInfo.overallStatus {
        case .breached: return AppTheme.accentRed.opacity(0.5)
        case .warning: return AppTheme.accentOrange.opacity(0.5)
        default: return .clear
        }
    }
}

// MARK: - Permission Category Row

struct PermissionCategoryRow: View {
    let category: PermissionCategory
    let permissions: [CustomerSupportPermission]

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(6)) {
            HStack {
                Image(systemName: category.icon)
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.accentLightBlue)

                Text(category.displayName)
                    .font(ResponsiveDesign.captionFont())
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.fontColor)
            }

            CSFlowLayout(spacing: ResponsiveDesign.spacing(6)) {
                ForEach(permissions, id: \.self) { permission in
                    HStack(spacing: ResponsiveDesign.spacing(4)) {
                        Image(systemName: permission.isReadOnly ? "eye.fill" : "pencil")
                            .font(ResponsiveDesign.captionFont())

                        Text(permission.displayName)
                            .font(ResponsiveDesign.captionFont())
                    }
                    .foregroundColor(AppTheme.fontColor.opacity(0.7))
                    .padding(.horizontal, ResponsiveDesign.spacing(8))
                    .padding(.vertical, ResponsiveDesign.spacing(4))
                    .background(AppTheme.screenBackground)
                    .cornerRadius(ResponsiveDesign.spacing(6))
                }
            }
        }
        .padding(.vertical, ResponsiveDesign.spacing(4))
    }
}

// MARK: - Flow Layout (for permission tags)

struct CSFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                      y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in width: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var maxHeight: CGFloat = 0

            for subview in subviews {
                let viewSize = subview.sizeThatFits(.unspecified)
                if currentX + viewSize.width > width && currentX > 0 {
                    currentX = 0
                    currentY += maxHeight + spacing
                    maxHeight = 0
                }
                positions.append(CGPoint(x: currentX, y: currentY))
                maxHeight = max(maxHeight, viewSize.height)
                currentX += viewSize.width + spacing
            }

            size = CGSize(width: width, height: currentY + maxHeight)
        }
    }
}





