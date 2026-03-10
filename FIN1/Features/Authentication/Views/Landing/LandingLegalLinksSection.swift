import SwiftUI

struct LandingLegalLinksSection: View {
    @Binding var showLegalTerms: Bool
    @Binding var showLegalPrivacy: Bool
    @Binding var showLegalImprint: Bool
    let style: LandingViewModel.DesignStyle

    private var isTypewriter: Bool { style == .typewriter }

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(12)) {
            Rectangle()
                .fill(isTypewriter ? Color("InputText").opacity(0.4) : AppTheme.fontColor.opacity(0.2))
                .frame(height: 1)

            HStack(spacing: ResponsiveDesign.spacing(16)) {
                Button(action: { showLegalTerms = true }) {
                    Text("Terms")
                        .font(isTypewriter
                              ? ResponsiveDesign.monospacedFont(size: 14, weight: .regular)
                              : ResponsiveDesign.captionFont())
                        .foregroundColor(isTypewriter ? Color("InputText") : AppTheme.accentLightBlue)
                }
                .buttonStyle(PlainButtonStyle())

                Button(action: { showLegalPrivacy = true }) {
                    Text("Privacy")
                        .font(isTypewriter
                              ? ResponsiveDesign.monospacedFont(size: 14, weight: .regular)
                              : ResponsiveDesign.captionFont())
                        .foregroundColor(isTypewriter ? Color("InputText") : AppTheme.accentLightBlue)
                }
                .buttonStyle(PlainButtonStyle())

                Button(action: { showLegalImprint = true }) {
                    Text("Imprint")
                        .font(isTypewriter
                              ? ResponsiveDesign.monospacedFont(size: 14, weight: .regular)
                              : ResponsiveDesign.captionFont())
                        .foregroundColor(isTypewriter ? Color("InputText") : AppTheme.accentLightBlue)
                }
                .buttonStyle(PlainButtonStyle())

                Spacer()
            }
        }
        .padding(.horizontal, ResponsiveDesign.horizontalPadding())
    }
}
