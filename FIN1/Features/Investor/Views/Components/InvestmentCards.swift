import SwiftUI

struct ActiveInvestmentCard: View {
    let investment: Investment
    @State private var showDetails = false
    @Environment(\.themeManager) private var themeManager

    var body: some View {
        Button(action: { showDetails = true }, label: {
            VStack(spacing: ResponsiveDesign.spacing(16)) {
                // Header
                HStack {
                    Circle()
                        .fill(AppTheme.accentLightBlue.opacity(0.3))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(ResponsiveDesign.headlineFont())
                                .foregroundColor(AppTheme.accentLightBlue)
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(getTraderUsername(for: investment.traderId))
                            .font(ResponsiveDesign.headlineFont())
                            .fontWeight(.bold)
                            .foregroundColor(AppTheme.fontColor)

                        Text(investment.specialization)
                            .font(ResponsiveDesign.bodyFont())
                            .foregroundColor(AppTheme.secondaryText)
                    }

                    Spacer()

                    // Status Badge
                    Text(investment.status.displayName)
                        .font(ResponsiveDesign.captionFont())
                        .fontWeight(.medium)
                        .foregroundColor(AppTheme.screenBackground)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(statusColor)
                        .cornerRadius(ResponsiveDesign.spacing(8))
                }

                // Investment Details
                HStack(spacing: ResponsiveDesign.spacing(20)) {
                    InvestmentDetailItem(
                        title: "Amount",
                        value: investment.amount.formattedAsLocalizedCurrency()
                    )

                    InvestmentDetailItem(
                        title: "Investment",
                        value: "\(investment.sequenceNumber ?? 1)"
                    )

                    InvestmentDetailItem(
                        title: "Status",
                        value: investment.status.displayName,
                        isPositive: investment.status == .active
                    )
                }

                // Investment Information
                VStack(spacing: ResponsiveDesign.spacing(8)) {
                    HStack {
                        Text("Investment Status")
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(AppTheme.secondaryText)

                        Spacer()

                        Text(investment.reservationStatus.displayName)
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(AppTheme.secondaryText)
                    }

                    // Show investment number if available
                    if let sequenceNumber = investment.sequenceNumber {
                        HStack(spacing: ResponsiveDesign.spacing(8)) {
                            Text("Investment #\(sequenceNumber)")
                                .font(ResponsiveDesign.captionFont())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(AppTheme.accentLightBlue.opacity(0.2))
                                .foregroundColor(AppTheme.accentLightBlue)
                                .cornerRadius(ResponsiveDesign.spacing(8))
                        }
                    }
                }
            }
            .padding(ResponsiveDesign.spacing(16))
            .background(AppTheme.sectionBackground)
            .cornerRadius(ResponsiveDesign.spacing(16))
        })
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showDetails) {
            InvestmentDetailView(investment: investment)
        }
    }

    private var statusColor: Color {
        switch investment.status {
        case .submitted:
            return AppTheme.accentOrange
        case .active:
            return AppTheme.accentLightBlue
        case .completed:
            return AppTheme.accentGreen
        case .cancelled:
            return AppTheme.accentRed
        }
    }

    private func getTraderUsername(for traderId: String) -> String {
        // In a real app, this would fetch from a traders database
        // For now, return a placeholder based on the ID
        return "trader_\(traderId.prefix(8))"
    }
}

struct CompletedInvestmentCard: View {
    let investment: Investment
    @Environment(\.themeManager) private var themeManager

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(16)) {
            // Header
            HStack {
                Circle()
                    .fill(AppTheme.accentGreen.opacity(0.3))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "checkmark.circle.fill")
                            .font(ResponsiveDesign.headlineFont())
                            .foregroundColor(AppTheme.accentGreen)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(getTraderUsername(for: investment.traderId))
                        .font(ResponsiveDesign.headlineFont())
                        .fontWeight(.bold)
                        .foregroundColor(AppTheme.fontColor)

                    if let completedAt = investment.completedAt {
                        Text("Completed \(completedAt.formatted(date: .abbreviated, time: .omitted))")
                            .font(ResponsiveDesign.bodyFont())
                            .foregroundColor(AppTheme.secondaryText)
                    } else {
                        Text("Completed")
                            .font(ResponsiveDesign.bodyFont())
                            .foregroundColor(AppTheme.secondaryText)
                    }
                }

                Spacer()

                // Status
                VStack(alignment: .trailing, spacing: 4) {
                    Text(investment.status.displayName)
                        .font(ResponsiveDesign.headlineFont())
                        .fontWeight(.bold)
                        .foregroundColor(AppTheme.accentGreen)

                    Text("Status")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.tertiaryText)
                }
            }

            // Summary
            HStack(spacing: ResponsiveDesign.spacing(20)) {
                InvestmentDetailItem(
                    title: "Amount",
                    value: investment.amount.formattedAsLocalizedCurrency()
                )

                InvestmentDetailItem(
                    title: "Investment",
                    value: "\(investment.sequenceNumber ?? 1)"
                )

                InvestmentDetailItem(
                    title: "Specialization",
                    value: investment.specialization,
                    isPositive: true
                )
            }
        }
        .padding(ResponsiveDesign.spacing(16))
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(16))
    }

    private func getTraderUsername(for traderId: String) -> String {
        // In a real app, this would fetch from a traders database
        // For now, return a placeholder based on the ID
        return "trader_\(traderId.prefix(8))"
    }
}

struct InvestmentHistoryCard: View {
    let investment: Investment
    @Environment(\.themeManager) private var themeManager

    var body: some View {
        HStack(spacing: ResponsiveDesign.spacing(16)) {
            // Icon
            Circle()
                .fill(AppTheme.accentLightBlue.opacity(0.3))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "clock.arrow.circlepath")
                        .font(ResponsiveDesign.headlineFont())
                        .foregroundColor(AppTheme.accentLightBlue)
                )

            // Details
            VStack(alignment: .leading, spacing: 4) {
                Text("Investment Created")
                    .font(ResponsiveDesign.bodyFont())
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.fontColor)

                Text(getTraderUsername(for: investment.traderId))
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.secondaryText)
            }

            Spacer()

            // Amount and Date
            VStack(alignment: .trailing, spacing: 4) {
                Text(investment.amount.formattedAsLocalizedCurrency())
                    .font(ResponsiveDesign.bodyFont())
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.fontColor)

                Text(investment.createdAt.formatted(date: .abbreviated, time: .omitted))
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.tertiaryText)
            }
        }
        .padding(ResponsiveDesign.spacing(16))
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    private func getTraderUsername(for traderId: String) -> String {
        // In a real app, this would fetch from a traders database
        // For now, return a placeholder based on the ID
        return "trader_\(traderId.prefix(8))"
    }
}

struct InvestmentDetailItem: View {
    let title: String
    let value: String
    let isPositive: Bool
    @Environment(\.themeManager) private var themeManager

    init(title: String, value: String, isPositive: Bool = false) {
        self.title = title
        self.value = value
        self.isPositive = isPositive
    }

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(4)) {
            Text(value)
                .font(ResponsiveDesign.bodyFont())
                .fontWeight(.medium)
                .foregroundColor(isPositive ? AppTheme.accentGreen : AppTheme.fontColor)

            Text(title)
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    VStack(spacing: ResponsiveDesign.spacing(16)) {
        Text("Investment Cards Preview")
            .font(ResponsiveDesign.headlineFont())
            .foregroundColor(AppTheme.fontColor)

        Text("Cards will show real investment data when available")
            .font(ResponsiveDesign.captionFont())
            .foregroundColor(AppTheme.secondaryText)
    }
    .padding()
    .background(AppTheme.screenBackground)
}
