import SwiftUI

struct AddressConfirmSuccessStep: View {
    var body: some View {
        SignUpFormStepList {
            VStack(spacing: ResponsiveDesign.spacing(32)) {
                Image(systemName: "checkmark.circle.fill")
                    .font(ResponsiveDesign.scaledSystemFont(size: 80))
                    .foregroundColor(AppTheme.accentGreen)
                    .frame(maxWidth: .infinity)

                VStack(spacing: ResponsiveDesign.spacing(16)) {
                    Text("Adresse erfolgreich bestätigt")
                        .font(ResponsiveDesign.titleFont())
                        .fontWeight(.bold)
                        .foregroundColor(AppTheme.fontColor)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)

                    Text("Ihre Adresse wurde erfolgreich bestätigt. Sie können jetzt mit dem nächsten Schritt fortfahren.")
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

#Preview {
    AddressConfirmSuccessStep()
        .background(AppTheme.screenBackground)
}
