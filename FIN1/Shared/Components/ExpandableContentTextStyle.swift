import SwiftUI

// MARK: - Expandable Content Text Style Modifier

/// View modifier for consistent expandable content text styling
/// Used across FAQs, Privacy Policy, and Terms of Service
struct ExpandableContentTextStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(ResponsiveDesign.bodyFont())
            .fontWeight(ResponsiveDesign.faqAnswerFontWeight)
            .foregroundColor(AppTheme.fontColor.opacity(ResponsiveDesign.faqAnswerTextOpacity))
            .fixedSize(horizontal: false, vertical: true)
    }
}

extension View {
    /// Applies consistent styling for expandable content text (FAQs, Privacy Policy, Terms of Service)
    func expandableContentTextStyle() -> some View {
        modifier(ExpandableContentTextStyle())
    }
}

