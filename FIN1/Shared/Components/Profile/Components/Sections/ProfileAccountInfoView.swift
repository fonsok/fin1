import SwiftUI

struct ProfileAccountInfoView: View {
    let user: User?
    let onEditProfile: () -> Void
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(16)) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Text("Account Information")
                        .font(ResponsiveDesign.headlineFont())
                        .foregroundColor(AppTheme.fontColor)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.6))
                }
            }
            .buttonStyle(PlainButtonStyle())

            if isExpanded {
                VStack(spacing: ResponsiveDesign.spacing(12)) {
                    SettingsRow(
                        title: "Edit Profile",
                        subtitle: "Update your account information",
                        icon: "person.circle.fill",
                        color: AppTheme.accentLightBlue,
                        action: onEditProfile
                    )

                    InfoRow(
                        title: "Account Type",
                        value: user?.role.displayName ?? "N/A",
                        icon: "person.badge.shield.checkmark.fill",
                        iconColor: AppTheme.accentLightBlue
                    )

                    InfoRow(
                        title: "Member Since",
                        value: formatMemberSinceDate(user?.createdAt),
                        icon: "calendar.badge.clock",
                        iconColor: AppTheme.accentLightBlue
                    )

                    InfoRow(
                        title: "Last Login",
                        value: formatLastLoginDate(user?.lastLoginDate),
                        icon: "clock.arrow.circlepath",
                        iconColor: AppTheme.accentLightBlue
                    )

                    if let employmentStatus = user?.employmentStatus {
                        InfoRow(
                            title: "Employment",
                            value: employmentStatus.displayName,
                            icon: "briefcase.fill",
                            iconColor: AppTheme.accentLightBlue
                        )
                    }

                    if let income = user?.income, income > 0 {
                        InfoRow(
                            title: "Annual Income",
                            value: formatAnnualIncome(income),
                            icon: "dollarsign.circle.fill",
                            iconColor: AppTheme.accentLightBlue
                        )
                    }

                    InfoRow(
                        title: "Risk Tolerance",
                        value: user?.riskToleranceDescription ?? "N/A",
                        icon: "chart.line.uptrend.xyaxis",
                        iconColor: AppTheme.accentLightBlue
                    )
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - Date Formatting Helpers

    private func formatMemberSinceDate(_ date: Date?) -> String {
        guard let date = date else { return "N/A" }
        let formatter = DateFormatter()
        formatter.dateFormat = "d. MMM yyyy"
        return formatter.string(from: date)
    }

    private func formatLastLoginDate(_ date: Date?) -> String {
        guard let date = date else { return "N/A" }
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "d. MMM yyyy"
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        return "\(dateFormatter.string(from: date)) at \(timeFormatter.string(from: date))"
    }

    private func formatAnnualIncome(_ income: Double?) -> String {
        guard let income = income else { return "$0" }
        if income == 0 {
            return "$0"
        }
        return "$\(String(format: "%.0f", income))"
    }
}

struct InfoRow: View {
    let title: String
    let value: String
    let icon: String
    let iconColor: Color

    var body: some View {
        HStack(spacing: ResponsiveDesign.spacing(12)) {
            Image(systemName: icon)
                .font(ResponsiveDesign.headlineFont())
                .foregroundColor(iconColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.7))

                Text(value)
                    .font(ResponsiveDesign.bodyFont())
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.fontColor)
            }

            Spacer()
        }
        .padding(ResponsiveDesign.spacing(12))
        .background(AppTheme.systemTertiaryBackground)
        .cornerRadius(ResponsiveDesign.spacing(8))
    }
}

#Preview {
    ProfileAccountInfoView(user: nil, onEditProfile: {})
        .padding()
        .background(AppTheme.screenBackground)
}
