import SwiftUI

struct AddressConfirmSuccessStep: View {
    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(32)) {
            // Success Icon
            Image(systemName: "checkmark.circle.fill")
                .font(ResponsiveDesign.scaledSystemFont(size: 80))
                .foregroundColor(AppTheme.accentGreen)
            
            // Success Message
            VStack(spacing: ResponsiveDesign.spacing(16)) {
                Text("Adresse erfolgreich bestätigt")
                    .font(ResponsiveDesign.titleFont())
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.fontColor)
                    .multilineTextAlignment(.center)
                
                Text("Ihre Adresse wurde erfolgreich bestätigt. Sie können jetzt mit dem nächsten Schritt fortfahren.")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
        }
    }
}

#Preview {
    AddressConfirmSuccessStep()
        .background(AppTheme.screenBackground)
}
