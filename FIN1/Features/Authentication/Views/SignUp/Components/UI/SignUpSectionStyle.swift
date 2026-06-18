import SwiftUI

// MARK: - Sign-up naming (implementation: `StripedListSection.swift`)
//
// Aliases keep sign-up call sites readable; stripe logic lives in one shared module.

typealias SignUpStepList = StripedStepList
typealias SignUpFormStepList = PaddedFormSectionList

extension View {
    func signUpListSection(
        stripeIndex: Int,
        isSelected: Bool = false,
        selectionAccent: Color = AppTheme.accentLightBlue,
        bandTint: Color? = nil
    ) -> some View {
        self.stripedListSection(
            stripeIndex: stripeIndex,
            isSelected: isSelected,
            selectionAccent: selectionAccent,
            bandTint: bandTint
        )
    }
}
