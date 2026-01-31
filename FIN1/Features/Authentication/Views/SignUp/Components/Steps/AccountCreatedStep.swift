import SwiftUI

struct AccountCreatedStep: View {
    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(32)) {
            // Success Icon
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(AppTheme.accentGreen)
            
            // Success Message
            VStack(spacing: ResponsiveDesign.spacing(16)) {
                Text("Sie haben erfolgreich ein Konto eröffnet.")
                    .font(ResponsiveDesign.titleFont())
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.fontColor)
                    .multilineTextAlignment(.center)
                
                Text("Ihr Konto wurde erfolgreich erstellt. Sie können jetzt mit der Registrierung fortfahren.")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
        }
    }
}

#Preview {
    AccountCreatedStep()
        .background(AppTheme.screenBackground)
}
