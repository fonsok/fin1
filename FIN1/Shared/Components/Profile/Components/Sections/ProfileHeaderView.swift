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
                
                Text(self.user?.email ?? "user@example.com")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.8))
                
                // Role Badge
                Text(self.user?.role.displayName ?? "User")
                    .font(ResponsiveDesign.captionFont())
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.screenBackground)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(AppTheme.accentLightBlue)
                    .cornerRadius(ResponsiveDesign.spacing(12))
            }
            
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
        }
        .padding(ResponsiveDesign.spacing(20))
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(16))
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
            
            Text(self.isVerified ? "Verified" : "Pending")
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(self.isVerified ? AppTheme.accentGreen : AppTheme.accentOrange)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background((self.isVerified ? AppTheme.accentGreen : AppTheme.accentOrange).opacity(0.2))
                .cornerRadius(ResponsiveDesign.spacing(8))
        }
    }
}

#Preview {
    ProfileHeaderView(user: nil)
        .padding()
        .background(AppTheme.screenBackground)
}
