import SwiftUI

// MARK: - Impersonation Banner
/// Global banner shown when admin is impersonating a user
struct ImpersonationBanner: View {
    let services: AppServices
    @State private var isVisible = true

    var body: some View {
        if isVisible {
            HStack(spacing: ResponsiveDesign.spacing(12)) {
                Image(systemName: "person.badge.key.fill")
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(.white)

                VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(2)) {
                    Text("Impersonating User")
                        .font(ResponsiveDesign.bodyFont())
                        .fontWeight(.semibold)
                        .foregroundColor(.white)

                    if let currentUser = services.userService.currentUser {
                        Text("\(currentUser.displayName) (\(currentUser.role.displayName))")
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(.white.opacity(0.9))
                    }
                }

                Spacer()

                Button(action: {
                    Task {
                        await services.userService.stopImpersonating()
                    }
                }) {
                    HStack(spacing: ResponsiveDesign.spacing(4)) {
                        Image(systemName: "arrow.uturn.backward")
                        Text("Return to Admin")
                    }
                    .font(ResponsiveDesign.captionFont())
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, ResponsiveDesign.spacing(12))
                    .padding(.vertical, ResponsiveDesign.spacing(6))
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(ResponsiveDesign.spacing(6))
                }
            }
            .padding(ResponsiveDesign.spacing(12))
            .background(
                AppTheme.accentRed.opacity(0.8)
            )
            .cornerRadius(ResponsiveDesign.spacing(8))
            .padding(.horizontal, ResponsiveDesign.horizontalPadding())
            .padding(.top, ResponsiveDesign.spacing(8))
            .shadow(color: AppTheme.accentRed.opacity(0.3), radius: 8, x: 0, y: 4)
            .transition(.move(edge: .top).combined(with: .opacity))
            .animation(.easeInOut(duration: 0.3), value: isVisible)
        }
    }
}

#Preview {
    ImpersonationBanner(services: .live)
}
