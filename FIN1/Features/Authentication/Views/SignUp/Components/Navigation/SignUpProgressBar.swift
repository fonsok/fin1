import SwiftUI

struct SignUpProgressBar: View {
    let progress: Double
    let currentStep: Int
    let totalSteps: Int

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(8)) {
            // Progress Bar
            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle(tint: AppTheme.accentLightBlue))
                .progressBarPadding()
                .padding(.top, ResponsiveDesign.spacing(2))

            // Step Title
            Text("Step \(currentStep) of \(totalSteps)")
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))
                .padding(.top, ResponsiveDesign.spacing(4))
        }
    }
}

#Preview {
    SignUpProgressBar(progress: 0.3, currentStep: 5, totalSteps: 18)
        .background(AppTheme.screenBackground)
}
