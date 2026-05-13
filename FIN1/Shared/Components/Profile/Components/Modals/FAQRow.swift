import SwiftUI

/// Expandable FAQ row displaying question and answer
struct FAQRow: View {
    let faq: FAQContentItem
    let isExpanded: Bool
    let onToggle: () -> Void

    var body: some View {
        ExpandableSectionRow(
            title: self.faq.question,
            icon: nil,
            iconColor: AppTheme.accentLightBlue,
            isExpanded: self.isExpanded,
            onToggle: self.onToggle,
            titleFontWeight: ResponsiveDesign.faqQuestionFontWeight
        ) {
            FAQAnswerFormatter(answer: self.faq.answer)
        }
    }
}

#Preview {
    VStack {
        FAQRow(
            faq: FAQContentItem(
                id: "test-1",
                question: "How do I create an account?",
                answer: "To create an account:\n• Tap 'Sign Up' on the landing page\n• Complete the registration process\n• Verify your email",
                categoryId: "getting_started",
                sortOrder: 1
            ),
            isExpanded: true,
            onToggle: {}
        )
        FAQRow(
            faq: FAQContentItem(
                id: "test-2",
                question: "What is the minimum investment?",
                answer: "The minimum investment varies by trader.",
                categoryId: "investments",
                sortOrder: 2
            ),
            isExpanded: false,
            onToggle: {}
        )
    }
    .padding()
    .background(AppTheme.screenBackground)
}

