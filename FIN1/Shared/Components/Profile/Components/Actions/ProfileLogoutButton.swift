import SwiftUI

struct ProfileLogoutButton: View {
    let onLogout: () -> Void

    var body: some View {
        Button(action: onLogout, label: {
            HStack(spacing: ResponsiveDesign.spacing(12)) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(ResponsiveDesign.headlineFont())

                Text("Logout")
                    .font(ResponsiveDesign.headlineFont())
                    .fontWeight(.medium)
            }
            .foregroundColor(AppTheme.accentRed)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(AppTheme.accentRed.opacity(0.2))
            .cornerRadius(ResponsiveDesign.spacing(12))
        })
    }
}

#Preview {
    ProfileLogoutButton(onLogout: {})
        .padding()
        .background(AppTheme.screenBackground)
}
