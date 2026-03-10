import SwiftUI

struct SignUpProgressBar: View {
    let progress: Double
    let currentStep: Int
    let totalSteps: Int
    var phase: OnboardingPhase = .quickStart

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(6)) {
            // Phase indicator
            HStack(spacing: ResponsiveDesign.spacing(4)) {
                ForEach(OnboardingPhase.allCases) { p in
                    Capsule()
                        .fill(capsuleColor(for: p))
                        .frame(height: ResponsiveDesign.spacing(4))
                }
            }
            .padding(.top, ResponsiveDesign.spacing(2))

            // Phase title + step counter
            HStack {
                Text(phase.title)
                    .font(ResponsiveDesign.captionFont())
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.fontColor)

                Spacer()

                Text("Step \(currentStep) of \(totalSteps)")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.7))
            }
        }
    }

    private func capsuleColor(for p: OnboardingPhase) -> Color {
        if p.rawValue < phase.rawValue {
            return AppTheme.accentGreen
        } else if p == phase {
            return AppTheme.accentLightBlue
        } else {
            return AppTheme.fontColor.opacity(0.2)
        }
    }
}

#Preview {
    SignUpProgressBar(progress: 0.3, currentStep: 5, totalSteps: 18, phase: .kyc)
        .background(AppTheme.screenBackground)
}
