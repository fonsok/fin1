import SwiftUI

// MARK: - Unified Input Field Preview
/// Preview for UnifiedInputField component

#Preview {
    ScrollView {
        VStack(spacing: ResponsiveDesign.spacing(20)) {
            // Text Fields
            UnifiedInputField.email(
                label: "Email",
                text: .constant("test@example.com")
            )

            UnifiedInputField.password(
                label: "Password",
                text: .constant("password123")
            )

            UnifiedInputField.username(
                label: "Username",
                text: .constant("user123")
            )

            // Picker
            UnifiedInputField(
                label: "Country",
                selection: .constant("Germany"),
                options: ["Germany", "USA", "France"],
                displayText: { String(describing: $0) }
            )

            // Search Field
            UnifiedInputField.search(
                label: "Basiswert",
                value: "DAX",
                subtitle: "Index - 84690",
                onTap: {}
            )

            // Custom Field
            UnifiedInputField(
                label: "Investment Amount",
                value: "€10,000",
                icon: "eurosign.circle.fill",
                onTap: {}
            )

            // Validation Examples
            UnifiedInputField(
                label: "Valid Field",
                text: .constant("Valid input"),
                validationState: .valid
            )

            UnifiedInputField(
                label: "Invalid Field",
                text: .constant("Invalid input"),
                validationState: .invalid("This field is required")
            )
        }
        .padding()
    }
    .background(AppTheme.screenBackground)
}
