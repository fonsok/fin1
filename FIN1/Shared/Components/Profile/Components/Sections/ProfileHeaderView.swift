import SwiftUI

struct ProfileHeaderView: View {
    let user: User?
    
    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(20)) {
            // Profile Image
            Circle()
                .fill(AppTheme.accentLightBlue.opacity(0.3))
                .frame(width: 100, height: 100)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(ResponsiveDesign.scaledSystemFont(size: 40))
                        .foregroundColor(AppTheme.accentLightBlue)
                )

            // User Info
            VStack(spacing: ResponsiveDesign.spacing(8)) {
                Text(self.user?.fullName ?? "User Name")
                    .font(ResponsiveDesign.headlineFont())
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.fontColor)
                    .multilineTextAlignment(.center)

                Text(self.user?.email ?? "user@example.com")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.8))
                    .multilineTextAlignment(.center)

                // Role Badge
                Text(self.user?.role.displayName ?? "User")
                    .font(ResponsiveDesign.captionFont())
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.inputText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(AppTheme.accentLightBlue)
                    .cornerRadius(ResponsiveDesign.spacing(12))
            }
            .frame(maxWidth: .infinity)

            // Verification Status
            HStack(spacing: ResponsiveDesign.spacing(16)) {
                VerificationBadge(
                    title: "Email",
                    isVerified: self.user?.isEmailVerified ?? false,
                    icon: "envelope.fill"
                )

                VerificationBadge(
                    title: "KYC",
                    isVerified: self.user?.isKYCCompleted ?? false,
                    icon: "checkmark.shield.fill"
                )
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(ResponsiveDesign.spacing(20))
    }
}

struct VerificationBadge: View {
    let title: String
    let isVerified: Bool
    let icon: String
    
    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(8)) {
            Image(systemName: self.icon)
                .font(ResponsiveDesign.headlineFont())
                .foregroundColor(self.isVerified ? AppTheme.accentGreen : AppTheme.accentOrange)

            Text(self.title)
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor)
                .multilineTextAlignment(.center)

            Text(self.isVerified ? "Verified" : "Pending")
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(self.isVerified ? AppTheme.accentGreen : AppTheme.accentOrange)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background((self.isVerified ? AppTheme.accentGreen : AppTheme.accentOrange).opacity(0.2))
                .cornerRadius(ResponsiveDesign.spacing(8))
        }
        .frame(minWidth: 80)
    }
}

#Preview {
    ProfileHeaderView(user: nil)
        .padding()
        .background(AppTheme.screenBackground)
}
