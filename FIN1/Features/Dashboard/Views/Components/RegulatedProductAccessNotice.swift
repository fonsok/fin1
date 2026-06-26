import SwiftUI

/// Generic notice when regulated product access is blocked (KYB, legal, onboarding — not risk class).
struct RegulatedProductAccessNotice: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: ResponsiveDesign.spacing(12)) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(AppTheme.accentOrange)
                .font(ResponsiveDesign.headlineFont())

            Text(self.message)
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.85))
                .multilineTextAlignment(.leading)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.accentOrange.opacity(0.1))
        .cornerRadius(ResponsiveDesign.spacing(12))
        .overlay(
            RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(12))
                .stroke(AppTheme.accentOrange.opacity(0.3), lineWidth: 1)
        )
        .accessibilityIdentifier("RegulatedProductAccessNotice")
    }
}

#Preview {
    RegulatedProductAccessNotice(message: "Ihre Firmenunterlagen werden geprüft.")
        .padding()
        .background(AppTheme.screenBackground)
}
