import SwiftUI

/// A reusable component that displays price validity using smooth color transitions
/// Shows green when price is fresh, orange when getting stale, red when expired
struct PriceValidityIndicator: View {
    let priceValidityProgress: Double

    var body: some View {
        if priceValidityProgress > 0 {
            Rectangle()
                .frame(height: 8)
                .foregroundColor(progressColor)
                .cornerRadius(ResponsiveDesign.spacing(4))
                .animation(.easeInOut(duration: 0.3), value: priceValidityProgress)
        }
    }

    private var progressColor: Color {
        // Create truly smooth color interpolation from green to red
        // priceValidityProgress: 1.0 (green) -> 0.0 (red)

        let clampedProgress = max(0, min(1, priceValidityProgress))

        // Use the app's specific colors for consistency
        let green = AppTheme.accentGreen
        let red = AppTheme.accentRed

        // Simple linear interpolation between the two colors
        return interpolateColor(from: green, to: red, progress: 1.0 - clampedProgress)
    }

    // Helper function for smooth color interpolation
    private func interpolateColor(from: Color, to: Color, progress: Double) -> Color {
        let clampedProgress = max(0, min(1, progress))

        // Convert to UIColor for interpolation
        let fromUIColor = UIColor(from)
        let toUIColor = UIColor(to)

        // Interpolate RGB components
        var fromRed: CGFloat = 0, fromGreen: CGFloat = 0, fromBlue: CGFloat = 0, fromAlpha: CGFloat = 0
        var toRed: CGFloat = 0, toGreen: CGFloat = 0, toBlue: CGFloat = 0, toAlpha: CGFloat = 0

        fromUIColor.getRed(&fromRed, green: &fromGreen, blue: &fromBlue, alpha: &fromAlpha)
        toUIColor.getRed(&toRed, green: &toGreen, blue: &toBlue, alpha: &toAlpha)

        let red = fromRed + (toRed - fromRed) * clampedProgress
        let green = fromGreen + (toGreen - fromGreen) * clampedProgress
        let blue = fromBlue + (toBlue - fromBlue) * clampedProgress
        let alpha = fromAlpha + (toAlpha - fromAlpha) * clampedProgress

        return Color(UIColor(red: red, green: green, blue: blue, alpha: alpha))
    }
}

#Preview {
    VStack(spacing: ResponsiveDesign.spacing(16)) {
        Text("Smooth Color Transitions")
            .font(ResponsiveDesign.headlineFont())
            .foregroundColor(AppTheme.fontColor)

        VStack(spacing: ResponsiveDesign.spacing(12)) {
            Text("Fresh Price (100%)")
            PriceValidityIndicator(priceValidityProgress: 1.0)

            Text("Fresh Price (90%)")
            PriceValidityIndicator(priceValidityProgress: 0.9)

            Text("Getting Stale (70%)")
            PriceValidityIndicator(priceValidityProgress: 0.7)

            Text("Getting Stale (50%)")
            PriceValidityIndicator(priceValidityProgress: 0.5)

            Text("Almost Expired (30%)")
            PriceValidityIndicator(priceValidityProgress: 0.3)

            Text("Almost Expired (10%)")
            PriceValidityIndicator(priceValidityProgress: 0.1)

            Text("Expired (0%)")
            PriceValidityIndicator(priceValidityProgress: 0.0)
        }

        Text("Colors smoothly interpolate from Green → Orange → Red")
            .font(ResponsiveDesign.captionFont())
            .foregroundColor(.gray)
            .multilineTextAlignment(.center)
    }
    .responsivePadding()
    .background(AppTheme.screenBackground)
}
