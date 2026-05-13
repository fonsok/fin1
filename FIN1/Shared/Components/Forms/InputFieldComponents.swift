import SwiftUI

// MARK: - Input Field Components
/// Individual input components for UnifiedInputField

// MARK: - Text Field Input
/// Text field input component
struct TextFieldInput: View {
    let placeholder: String?
    let icon: String?
    @Binding var text: String
    let maxLength: Int?
    let onTextChange: ((String) -> Void)?

    var body: some View {
        HStack(spacing: ResponsiveDesign.spacing(12)) {
            if let icon = icon {
                InputFieldIcon(iconName: icon)
            }

            TextField(self.placeholder ?? "", text: self.$text)
                .font(InputFieldTextStyle.primary)
                .foregroundColor(InputFieldTextStyle.primaryColor)
                .textContentType(self.placeholder?.contains("@") == true ? .emailAddress : nil)
                .keyboardType(self.placeholder?.contains("@") == true ? .emailAddress : .default)
                .autocapitalization(.none)
                .onChange(of: self.text) { _, newValue in
                    if let maxLength = maxLength, newValue.count > maxLength {
                        self.text = String(newValue.prefix(maxLength))
                    }
                    self.onTextChange?(newValue)
                }
        }
        .inputFieldBackground()
    }
}

// MARK: - Secure Field Input
/// Secure field input component
struct SecureFieldInput: View {
    let placeholder: String?
    let icon: String?
    @Binding var text: String
    let maxLength: Int?
    let onTextChange: ((String) -> Void)?

    var body: some View {
        HStack(spacing: ResponsiveDesign.spacing(12)) {
            if let icon = icon {
                InputFieldIcon(iconName: icon)
            }

            SecureField(self.placeholder ?? "", text: self.$text)
                .font(InputFieldTextStyle.primary)
                .foregroundColor(InputFieldTextStyle.primaryColor)
                .textContentType(.password)
                .onChange(of: self.text) { _, newValue in
                    if let maxLength = maxLength, newValue.count > maxLength {
                        self.text = String(newValue.prefix(maxLength))
                    }
                    self.onTextChange?(newValue)
                }
        }
        .inputFieldBackground()
    }
}

// MARK: - Picker Input
/// Picker input component
struct PickerInput: View {
    let placeholder: String?
    @Binding var selection: Any?
    let options: [Any]?
    let displayText: ((Any) -> String)?

    var body: some View {
        Menu {
            if let options = options, let displayText = displayText {
                ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                    Button(action: {
                        self.selection = option
                    }) {
                        Text(displayText(option))
                            .foregroundColor(InputFieldTextStyle.primaryColor)
                    }
                }
            }
        } label: {
            HStack {
                if let selection = selection, let displayText = displayText {
                    Text(displayText(selection))
                        .foregroundColor(InputFieldTextStyle.primaryColor)
                } else {
                    Text(self.placeholder ?? "")
                        .foregroundColor(InputFieldTextStyle.placeholderColor)
                }

                Spacer()

                Image(systemName: "chevron.up.chevron.down")
                    .foregroundColor(selection != nil ? InputFieldTextStyle.primaryColor : InputFieldTextStyle.placeholderColor)
            }
            .inputFieldBackground()
        }
    }
}

// MARK: - Search Field Input
/// Search field input component
struct SearchFieldInput: View {
    let text: String
    let subtitle: String?
    let cornerRadius: CGFloat?
    let onTap: (() -> Void)?

    var body: some View {
        Button(action: self.onTap ?? {}, label: {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(self.text)
                        .foregroundColor(InputFieldTextStyle.primaryColor)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .multilineTextAlignment(.leading)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(InputFieldTextStyle.secondary)
                            .foregroundColor(InputFieldTextStyle.primaryColor)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .multilineTextAlignment(.leading)
                    }
                }

                Spacer()

                Image(systemName: "chevron.up.chevron.down")
                    .foregroundColor(InputFieldTextStyle.primaryColor)
                    .frame(maxHeight: .infinity, alignment: .center)
            }
            .padding(ResponsiveDesign.spacing(16))
            .background(AppTheme.inputFieldBackground)
            .cornerRadius(self.cornerRadius ?? 8)
        })
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Custom Input
/// Custom input component
struct CustomInput: View {
    let text: String
    let subtitle: String?
    let icon: String?
    let cornerRadius: CGFloat?
    let onTap: (() -> Void)?

    var body: some View {
        Button(action: self.onTap ?? {}, label: {
            HStack(alignment: .center, spacing: ResponsiveDesign.spacing(12)) {
                if let icon = icon {
                    InputFieldIcon(iconName: icon)
                        .frame(maxHeight: .infinity, alignment: .center)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(self.text)
                        .foregroundColor(InputFieldTextStyle.primaryColor)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .multilineTextAlignment(.leading)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(InputFieldTextStyle.secondary)
                            .foregroundColor(InputFieldTextStyle.primaryColor)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .multilineTextAlignment(.leading)
                    }
                }

                Spacer()

                Image(systemName: "chevron.up.chevron.down")
                    .foregroundColor(InputFieldTextStyle.primaryColor)
                    .frame(maxHeight: .infinity, alignment: .center)
            }
            .inputFieldBackground(cornerRadius: self.cornerRadius)
        })
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Input Container
/// Container that wraps input components with common styling
struct InputContainer<Content: View>: View {
    let content: Content
    let isEnabled: Bool

    init(isEnabled: Bool, @ViewBuilder content: () -> Content) {
        self.isEnabled = isEnabled
        self.content = content()
    }

    var body: some View {
        InputContainerStyle.apply(to: self.content, isEnabled: self.isEnabled, cornerRadius: nil)
    }
}
