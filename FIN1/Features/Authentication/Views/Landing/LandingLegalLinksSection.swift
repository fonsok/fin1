import SwiftUI

struct LandingLegalLinksSection: View {
    @Binding var showLegalTerms: Bool
    @Binding var showLegalPrivacy: Bool
    @Binding var showLegalImprint: Bool
    let style: LandingViewModel.DesignStyle

    private var isTypewriter: Bool { self.style == .typewriter }

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(12)) {
            Rectangle()
                .fill(self.isTypewriter ? Color("InputText").opacity(0.4) : AppTheme.fontColor.opacity(0.2))
                .frame(height: 1)

            HStack(spacing: ResponsiveDesign.spacing(16)) {
                Button(action: { self.showLegalTerms = true }) {
                    Text("Terms")
                        .font(self.isTypewriter
                            ? ResponsiveDesign.monospacedFont(size: 14, weight: .regular)
                            : ResponsiveDesign.captionFont())
                        .foregroundColor(self.isTypewriter ? Color("InputText") : AppTheme.accentLightBlue)
                }
                .buttonStyle(PlainButtonStyle())

                Button(action: { self.showLegalPrivacy = true }) {
                    Text("Privacy")
                        .font(self.isTypewriter
                            ? ResponsiveDesign.monospacedFont(size: 14, weight: .regular)
                            : ResponsiveDesign.captionFont())
                        .foregroundColor(self.isTypewriter ? Color("InputText") : AppTheme.accentLightBlue)
                }
                .buttonStyle(PlainButtonStyle())

                Button(action: { self.showLegalImprint = true }) {
                    Text("Imprint")
                        .font(self.isTypewriter
                            ? ResponsiveDesign.monospacedFont(size: 14, weight: .regular)
                            : ResponsiveDesign.captionFont())
                        .foregroundColor(self.isTypewriter ? Color("InputText") : AppTheme.accentLightBlue)
                }
                .buttonStyle(PlainButtonStyle())

                Spacer()
            }
        }
        .padding(.horizontal, ResponsiveDesign.horizontalPadding())
    }
}
