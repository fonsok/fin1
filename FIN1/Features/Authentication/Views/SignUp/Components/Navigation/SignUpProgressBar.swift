import SwiftUI

struct SignUpProgressBar: View {
    let progress: Double
    let currentStep: Int
    let totalSteps: Int
    var phase: OnboardingPhase = .quickStart

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(10)) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(2)) {
                    Text(self.phase.title)
                        .font(ResponsiveDesign.bodyFont())
                        .fontWeight(.semibold)
                        .foregroundColor(AppTheme.fontColor)

                    Text("Schritt \(self.currentStep) von \(self.totalSteps)")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.65))
                        .accessibilityIdentifier("SignUpProgressStepLabel")
                }

                Spacer(minLength: ResponsiveDesign.spacing(8))

                Text("\(self.progressPercentage)%")
                    .font(ResponsiveDesign.captionFont())
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.accentLightBlue)
                    .monospacedDigit()
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppTheme.fontColor.opacity(0.14))

                    Capsule()
                        .fill(AppTheme.accentLightBlue)
                        .frame(width: geometry.size.width * self.clampedProgress)
                }
            }
            .frame(height: ResponsiveDesign.spacing(6))
            .accessibilityLabel("Fortschritt")
            .accessibilityValue("\(self.progressPercentage) Prozent")

            HStack(spacing: ResponsiveDesign.spacing(4)) {
                ForEach(OnboardingPhase.allCases) { phase in
                    Capsule()
                        .fill(self.capsuleColor(for: phase))
                        .frame(height: ResponsiveDesign.spacing(3))
                }
            }
        }
    }

    private var clampedProgress: CGFloat {
        CGFloat(min(max(self.progress, 0), 1))
    }

    private var progressPercentage: Int {
        Int((self.clampedProgress * 100).rounded())
    }

    private func capsuleColor(for phase: OnboardingPhase) -> Color {
        if phase.rawValue < self.phase.rawValue {
            return AppTheme.accentGreen
        } else if phase == self.phase {
            return AppTheme.accentLightBlue
        } else {
            return AppTheme.fontColor.opacity(0.18)
        }
    }
}

#Preview {
    SignUpProgressBar(progress: 0.42, currentStep: 8, totalSteps: 18, phase: .kyc)
        .padding()
        .background(AppTheme.screenBackground)
}
