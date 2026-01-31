import SwiftUI

// MARK: - Keyboard Dismissal Modifier
/// A view modifier that dismisses the keyboard when tapping outside of text fields
struct KeyboardDismissalModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                // Use simultaneousGesture to not interfere with other tap gestures
                TapGesture()
                    .onEnded { _ in
                        // Dismiss keyboard by resigning first responder
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
            )
    }
}

// MARK: - View Extension
extension View {
    /// Adds keyboard dismissal functionality to a view
    /// When the user taps outside of text fields, the keyboard will be dismissed
    /// - Returns: View with keyboard dismissal modifier applied
    func dismissKeyboardOnTap() -> some View {
        self.modifier(KeyboardDismissalModifier())
    }
}

// MARK: - Alternative Implementation for ScrollView
/// A view modifier specifically designed for ScrollView that doesn't interfere with scrolling or text input
/// Uses native iOS keyboard dismissal when available - avoids gesture conflicts
struct ScrollViewKeyboardDismissalModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            // Use native iOS 16+ keyboard dismissal API
            // This dismisses keyboard when scrolling, not on taps - avoids gesture conflicts
            content
                .scrollDismissesKeyboard(.interactively)
        } else {
            // For iOS 15 and earlier: No automatic dismissal
            // This prevents gesture conflicts and system warnings
            // Users can still:
            // - Tap Return/Search key on keyboard (handled by TextField)
            // - Tap outside text field (native iOS behavior)
            // - Manually dismiss by tapping outside the ScrollView
            content
        }
    }
}

// MARK: - ScrollView Extension
extension View {
    /// Adds keyboard dismissal functionality to a ScrollView
    /// This version is optimized for ScrollView and won't interfere with scrolling gestures
    /// - Returns: View with ScrollView-optimized keyboard dismissal modifier applied
    func dismissKeyboardOnScrollViewTap() -> some View {
        self.modifier(ScrollViewKeyboardDismissalModifier())
    }
}

#if DEBUG
struct KeyboardDismissalModifier_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: ResponsiveDesign.spacing(20)) {
            TextField("Test Field 1", text: .constant(""))
                .textFieldStyle(RoundedBorderTextFieldStyle())

            TextField("Test Field 2", text: .constant(""))
                .textFieldStyle(RoundedBorderTextFieldStyle())

            Text("Tap outside the text fields to dismiss keyboard")
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(.secondary)
        }
        .padding()
        .dismissKeyboardOnTap()
        .previewDisplayName("Keyboard Dismissal Demo")
    }
}
#endif
