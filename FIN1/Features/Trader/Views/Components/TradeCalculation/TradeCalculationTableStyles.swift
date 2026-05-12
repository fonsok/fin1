import SwiftUI

// MARK: - Custom View Modifiers for Trade Calculation Table
extension View {
    func tradeCalculationHeaderStyle() -> some View {
        self
            .font(ResponsiveDesign.captionFont())
            .fontWeight(.light)
            .foregroundColor(AppTheme.inputFieldText)
    }

    func tradeCalculationValueStyle() -> some View {
        self
            .font(ResponsiveDesign.bodyFont())
            .fontWeight(.thin)
            .foregroundColor(AppTheme.fontColor)
    }

    func tradeCalculationBoldStyle() -> some View {
        self
            .font(ResponsiveDesign.bodyFont())
            .fontWeight(.light)
            .foregroundColor(AppTheme.fontColor)
    }

    func tradeCalculationMediumStyle() -> some View {
        self
            .font(ResponsiveDesign.bodyFont())
            .fontWeight(.thin)
            .foregroundColor(AppTheme.fontColor)
    }

    func tradeCalculationSectionHeaderStyle() -> some View {
        self
            .font(ResponsiveDesign.headlineFont())
            .fontWeight(.ultraLight)
            .foregroundColor(AppTheme.fontColor)
    }

    /// Callout-sized row text: use responsive body tier with thin weight (no separate callout scale in `ResponsiveDesign`).
    func tradeCalculationFeeTaxStyle() -> some View {
        self
            .font(ResponsiveDesign.bodyFont())
            .fontWeight(.thin)
            .foregroundColor(AppTheme.fontColor)
    }
}
