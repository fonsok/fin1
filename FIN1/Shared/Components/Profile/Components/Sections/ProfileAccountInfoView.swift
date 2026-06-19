import SwiftUI

struct ProfileAccountInfoView: View {
    let user: User?
    let onEditProfile: () -> Void
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(0)) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    self.isExpanded.toggle()
                }
            }) {
                HStack {
                    Text("Account Information")
                        .font(ResponsiveDesign.headlineFont())
                        .foregroundColor(AppTheme.fontColor)
                    Spacer(minLength: 0)
                    Image(systemName: self.isExpanded ? "chevron.up" : "chevron.down")
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.6))
                }
                .padding(.bottom, ResponsiveDesign.spacing(12))
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if self.isExpanded {
                ProfileSectionDivider()

                SettingsRow(
                    title: "Edit Profile",
                    subtitle: "Update your account information",
                    icon: "person.circle.fill",
                    color: AppTheme.accentLightBlue,
                    action: self.onEditProfile
                )

                ProfileSectionDivider()

                InfoRow(
                    title: "Account Type",
                    value: self.user?.role.displayName ?? "N/A",
                    icon: "person.badge.shield.checkmark.fill",
                    iconColor: AppTheme.accentLightBlue
                )

                ProfileSectionDivider()

                InfoRow(
                    title: "Member Since",
                    value: self.formatMemberSinceDate(self.user?.createdAt),
                    icon: "calendar.badge.clock",
                    iconColor: AppTheme.accentLightBlue
                )

                ProfileSectionDivider()

                InfoRow(
                    title: "Last Login",
                    value: self.formatLastLoginDate(self.user?.lastLoginDate),
                    icon: "clock.arrow.circlepath",
                    iconColor: AppTheme.accentLightBlue
                )

                if let employmentStatus = user?.employmentStatus {
                    ProfileSectionDivider()

                    InfoRow(
                        title: "Employment",
                        value: employmentStatus.displayName,
                        icon: "briefcase.fill",
                        iconColor: AppTheme.accentLightBlue
                    )
                }

                if let income = user?.income, income > 0 {
                    ProfileSectionDivider()

                    InfoRow(
                        title: "Annual Income",
                        value: self.formatAnnualIncome(income),
                        icon: "dollarsign.circle.fill",
                        iconColor: AppTheme.accentLightBlue
                    )
                }

                ProfileSectionDivider()

                InfoRow(
                    title: "Risk Tolerance",
                    value: self.user?.riskToleranceDescription ?? "N/A",
                    icon: "chart.line.uptrend.xyaxis",
                    iconColor: AppTheme.accentLightBlue
                )
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
            Image(systemName: self.icon)
                .font(ResponsiveDesign.headlineFont())
                .foregroundColor(self.iconColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(self.title)
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.7))

                Text(self.value)
                    .font(ResponsiveDesign.bodyFont())
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.fontColor)
            }

            Spacer()
        }
        .padding(.horizontal, ResponsiveDesign.spacing(12))
        .padding(.vertical, ResponsiveDesign.spacing(12))
    }
}

#Preview {
    ProfileAccountInfoView(user: nil, onEditProfile: {})
        .padding()
        .background(AppTheme.screenBackground)
}
