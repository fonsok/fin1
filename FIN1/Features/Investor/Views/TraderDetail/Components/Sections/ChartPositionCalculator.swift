import SwiftUI

// MARK: - Chart Position Calculator
/// Helper functions for chart position calculations
/// Separated from View to keep business logic out of UI layer
enum ChartPositionCalculator {
    /// Calculates Y position for a value, using linear scaling for -100 to 200, and logarithmic scaling above 200
    static func calculateYPosition(
        value: Double,
        yAxisRange: (min: Double, max: Double),
        chartHeight: CGFloat
    ) -> CGFloat {
        let linearMax: Double = 200
        let linearMin: Double = -100
        let linearRange = linearMax - linearMin
        let clampedValue = min(max(value, yAxisRange.min), yAxisRange.max)

        if clampedValue <= linearMax {
            let linearPosition = (clampedValue - linearMin) / linearRange
            let linearSectionRatio = yAxisRange.max > 200 ? 0.85 : 1.0
            let linearSectionHeight = chartHeight * linearSectionRatio
            return chartHeight - (linearPosition * linearSectionHeight)
        }

        let logMin: Double = 200
        let logMax = yAxisRange.max
        guard logMax > logMin else { return chartHeight * 0.15 }

        let logValue = log10(max(clampedValue, logMin))
        let logMinScaled = log10(logMin)
        let logMaxScaled = log10(logMax)
        let logRange = logMaxScaled - logMinScaled

        guard logRange > 0 else { return chartHeight * 0.15 }

        let logNormalized = (logValue - logMinScaled) / logRange
        let logSectionHeight = chartHeight * 0.15
        return chartHeight * 0.15 - (logNormalized * logSectionHeight)
    }
}











