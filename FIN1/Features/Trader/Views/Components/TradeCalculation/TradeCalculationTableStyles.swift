import SwiftUI

// MARK: - Custom View Modifiers for Trade Calculation Table
extension View {
    func tradeCalculationHeaderStyle() -> some View {
        self
            .font(.caption.weight(.light))
            .foregroundColor(AppTheme.inputFieldText)
    }

    func tradeCalculationValueStyle() -> some View {
        self
            .font(.body.weight(.thin))
            .foregroundColor(AppTheme.fontColor)
    }

    func tradeCalculationBoldStyle() -> some View {
        self
            .font(.body.weight(.light))
            .foregroundColor(AppTheme.fontColor)
    }

    func tradeCalculationMediumStyle() -> some View {
        self
            .font(.body.weight(.thin))
            .foregroundColor(AppTheme.fontColor)
    }

    func tradeCalculationSectionHeaderStyle() -> some View {
        self
            .font(.headline.weight(.ultraLight))
            .foregroundColor(AppTheme.fontColor)
    }

    func tradeCalculationFeeTaxStyle() -> some View {
        self
            .font(.callout.weight(.thin))
            .foregroundColor(AppTheme.fontColor)
    }
}
