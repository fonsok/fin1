import SwiftUI

// MARK: - Unified Input Field Convenience Initializers
/// Convenience initializers for common input field types

extension UnifiedInputField {

    // MARK: Email Field
    static func email(
        label: String,
        text: Binding<String>,
        validationState: ValidationState = .none,
        isRequired: Bool = false
    ) -> UnifiedInputField {
        UnifiedInputField(
            label: label,
            placeholder: "Enter email address",
            icon: "envelope.fill",
            text: text,
            validationState: validationState,
            isRequired: isRequired
        )
    }

    // MARK: Password Field
    static func password(
        label: String,
        text: Binding<String>,
        validationState: ValidationState = .none,
        isRequired: Bool = false
    ) -> UnifiedInputField {
        UnifiedInputField(
            label: label,
            placeholder: "Enter password",
            icon: "lock.fill",
            secureText: text,
            validationState: validationState,
            isRequired: isRequired
        )
    }

    // MARK: Username Field
    static func username(
        label: String,
        text: Binding<String>,
        maxLength: Int = 10,
        validationState: ValidationState = .none,
        isRequired: Bool = false
    ) -> UnifiedInputField {
        UnifiedInputField(
            label: label,
            placeholder: "Enter username",
            icon: "person.fill",
            text: text,
            validationState: validationState,
            maxLength: maxLength,
            isRequired: isRequired
        )
    }

    // MARK: Phone Field
    static func phone(
        label: String,
        text: Binding<String>,
        validationState: ValidationState = .none,
        isRequired: Bool = false
    ) -> UnifiedInputField {
        UnifiedInputField(
            label: label,
            placeholder: "Enter phone number",
            icon: "phone.fill",
            text: text,
            validationState: validationState,
            isRequired: isRequired
        )
    }

    // MARK: Address Field
    static func address(
        label: String,
        text: Binding<String>,
        validationState: ValidationState = .none,
        isRequired: Bool = false
    ) -> UnifiedInputField {
        UnifiedInputField(
            label: label,
            placeholder: "Enter address",
            icon: "house.fill",
            text: text,
            validationState: validationState,
            isRequired: isRequired
        )
    }

    // MARK: Search Field
    static func search(
        label: String,
        value: String,
        subtitle: String? = nil,
        onTap: @escaping () -> Void
    ) -> UnifiedInputField {
        UnifiedInputField(
            label: label,
            value: value,
            subtitle: subtitle,
            onTap: onTap
        )
    }
}
