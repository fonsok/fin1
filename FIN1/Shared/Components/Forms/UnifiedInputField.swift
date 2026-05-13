import SwiftUI

// MARK: - Unified Input Field Component
/// A comprehensive, reusable input field component that handles all common input patterns
/// in the FIN1 application, eliminating the need for multiple similar components.

struct UnifiedInputField: View {

    // MARK: - Properties
    let label: String
    let placeholder: String?
    let icon: String?
    let subtitle: String?
    let inputType: InputType
    let layoutStyle: LayoutStyle
    let validationState: ValidationState
    let maxLength: Int?
    let isRequired: Bool
    let isEnabled: Bool
    let cornerRadius: CGFloat?
    let labelWidth: CGFloat?

    // MARK: - Bindings
    @Binding var text: String
    @Binding var selection: Any?
    let options: [Any]?
    let displayText: ((Any) -> String)?
    let onTap: (() -> Void)?
    let onTextChange: ((String) -> Void)?

    // MARK: - Text Field Initializer
    init(
        label: String,
        placeholder: String = "",
        icon: String? = nil,
        text: Binding<String>,
        subtitle: String? = nil,
        layoutStyle: LayoutStyle = .standard,
        validationState: ValidationState = .none,
        maxLength: Int? = nil,
        isRequired: Bool = false,
        isEnabled: Bool = true,
        cornerRadius: CGFloat? = nil,
        labelWidth: CGFloat? = nil,
        onTextChange: ((String) -> Void)? = nil
    ) {
        self.label = label
        self.placeholder = placeholder
        self.icon = icon
        self.subtitle = subtitle
        self.inputType = .textField
        self.layoutStyle = layoutStyle
        self.validationState = validationState
        self.maxLength = maxLength
        self.isRequired = isRequired
        self.isEnabled = isEnabled
        self.cornerRadius = cornerRadius
        self.labelWidth = labelWidth
        self._text = text
        self._selection = .constant(nil)
        self.options = nil
        self.displayText = nil
        self.onTap = nil
        self.onTextChange = onTextChange
    }

    // MARK: - Secure Field Initializer
    init(
        label: String,
        placeholder: String = "",
        icon: String? = nil,
        secureText: Binding<String>,
        subtitle: String? = nil,
        layoutStyle: LayoutStyle = .standard,
        validationState: ValidationState = .none,
        maxLength: Int? = nil,
        isRequired: Bool = false,
        isEnabled: Bool = true,
        cornerRadius: CGFloat? = nil,
        labelWidth: CGFloat? = nil,
        onTextChange: ((String) -> Void)? = nil
    ) {
        self.label = label
        self.placeholder = placeholder
        self.icon = icon
        self.subtitle = subtitle
        self.inputType = .secureField
        self.layoutStyle = layoutStyle
        self.validationState = validationState
        self.maxLength = maxLength
        self.isRequired = isRequired
        self.isEnabled = isEnabled
        self.cornerRadius = cornerRadius
        self.labelWidth = labelWidth
        self._text = secureText
        self._selection = .constant(nil)
        self.options = nil
        self.displayText = nil
        self.onTap = nil
        self.onTextChange = onTextChange
    }

    // MARK: - Picker Initializer
    init<T: Hashable>(
        label: String,
        selection: Binding<T>,
        options: [T],
        displayText: @escaping (T) -> String,
        subtitle: String? = nil,
        layoutStyle: LayoutStyle = .standard,
        validationState: ValidationState = .none,
        isRequired: Bool = false,
        isEnabled: Bool = true,
        cornerRadius: CGFloat? = nil,
        labelWidth: CGFloat? = nil,
        onSelectionChange: ((T) -> Void)? = nil
    ) {
        self.label = label
        self.placeholder = nil
        self.icon = nil
        self.subtitle = subtitle
        self.inputType = .picker
        self.layoutStyle = layoutStyle
        self.validationState = validationState
        self.maxLength = nil
        self.isRequired = isRequired
        self.isEnabled = isEnabled
        self.cornerRadius = cornerRadius
        self.labelWidth = labelWidth
        self._text = .constant("")
        self._selection = Binding<Any?>(
            get: { selection.wrappedValue as Any },
            set: { newValue in
                if let newValue = newValue as? T {
                    selection.wrappedValue = newValue
                    onSelectionChange?(newValue)
                }
            }
        )
        self.options = options.map { $0 as Any }
        self.displayText = { value in
            if let typedValue = value as? T {
                return displayText(typedValue)
            }
            return String(describing: value)
        }
        self.onTap = nil
        self.onTextChange = nil
    }

    // MARK: - Search Field Initializer
    init(
        label: String,
        value: String,
        subtitle: String? = nil,
        onTap: @escaping () -> Void,
        layoutStyle: LayoutStyle = .horizontal,
        validationState: ValidationState = .none,
        isRequired: Bool = false,
        isEnabled: Bool = true,
        cornerRadius: CGFloat? = nil,
        labelWidth: CGFloat? = 100
    ) {
        self.label = label
        self.placeholder = nil
        self.icon = nil
        self.subtitle = subtitle
        self.inputType = .searchField
        self.layoutStyle = layoutStyle
        self.validationState = validationState
        self.maxLength = nil
        self.isRequired = isRequired
        self.isEnabled = isEnabled
        self.cornerRadius = cornerRadius
        self.labelWidth = labelWidth
        self._text = .constant(value)
        self._selection = .constant(nil)
        self.options = nil
        self.displayText = nil
        self.onTap = onTap
        self.onTextChange = nil
    }

    // MARK: - Custom Field Initializer
    init(
        label: String,
        value: String,
        subtitle: String? = nil,
        icon: String? = nil,
        onTap: @escaping () -> Void,
        layoutStyle: LayoutStyle = .standard,
        validationState: ValidationState = .none,
        isRequired: Bool = false,
        isEnabled: Bool = true,
        cornerRadius: CGFloat? = nil,
        labelWidth: CGFloat? = nil
    ) {
        self.label = label
        self.placeholder = nil
        self.icon = icon
        self.subtitle = subtitle
        self.inputType = .custom
        self.layoutStyle = layoutStyle
        self.validationState = validationState
        self.maxLength = nil
        self.isRequired = isRequired
        self.isEnabled = isEnabled
        self.cornerRadius = cornerRadius
        self.labelWidth = labelWidth
        self._text = .constant(value)
        self._selection = .constant(nil)
        self.options = nil
        self.displayText = nil
        self.onTap = onTap
        self.onTextChange = nil
    }

    // MARK: - Body
    var body: some View {
        switch self.layoutStyle {
        case .standard:
            InputFieldLayoutComponents.standardLayout(
                label: self.label,
                isRequired: self.isRequired,
                content: { self.inputContainer },
                validationState: self.validationState
            )
        case .horizontal:
            InputFieldLayoutComponents.horizontalLayout(
                label: self.label,
                isRequired: self.isRequired,
                labelWidth: self.labelWidth,
                content: { self.inputContainer }
            )
        case .inline:
            InputFieldLayoutComponents.inlineLayout(
                label: self.label,
                isRequired: self.isRequired,
                content: { self.inputContainer }
            )
        }
    }

    // MARK: - Input Container
    private var inputContainer: some View {
        InputContainer(isEnabled: self.isEnabled) {
            Group {
                switch self.inputType {
                case .textField:
                    TextFieldInput(
                        placeholder: self.placeholder,
                        icon: self.icon,
                        text: self.$text,
                        maxLength: self.maxLength,
                        onTextChange: self.onTextChange
                    )
                case .secureField:
                    SecureFieldInput(
                        placeholder: self.placeholder,
                        icon: self.icon,
                        text: self.$text,
                        maxLength: self.maxLength,
                        onTextChange: self.onTextChange
                    )
                case .picker:
                    PickerInput(
                        placeholder: self.placeholder,
                        selection: self.$selection,
                        options: self.options,
                        displayText: self.displayText
                    )
                case .searchField:
                    SearchFieldInput(
                        text: self.text,
                        subtitle: self.subtitle,
                        cornerRadius: self.cornerRadius,
                        onTap: self.onTap
                    )
                case .custom:
                    CustomInput(
                        text: self.text,
                        subtitle: self.subtitle,
                        icon: self.icon,
                        cornerRadius: self.cornerRadius,
                        onTap: self.onTap
                    )
                }
            }
        }
    }
}
