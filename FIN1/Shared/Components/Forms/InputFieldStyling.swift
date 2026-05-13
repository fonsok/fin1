import SwiftUI

// MARK: - Input Field Styling
/// Styling and layout components for UnifiedInputField

// MARK: - Layout Style
/// Defines the layout style for input fields
enum LayoutStyle {
    case standard        // Label above, input below
    case horizontal      // Label on left, input on right (like SearchField)
    case inline         // Label and input on same line
}

// MARK: - Input Type
/// Defines the type of input field
enum InputType {
    case textField
    case secureField
    case picker
    case searchField
    case custom
}

// MARK: - Layout Components
/// Layout components for different input field arrangements
@MainActor
struct InputFieldLayoutComponents {

    /// Standard layout with label above input
    static func standardLayout<Content: View>(
        label: String,
        isRequired: Bool,
        @ViewBuilder content: () -> Content,
        validationState: ValidationState
    ) -> some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            LabelView(label: label, isRequired: isRequired)
            content()
            ValidationMessageView(validationState: validationState)
        }
    }

    /// Horizontal layout with label on left, input on right
    static func horizontalLayout<Content: View>(
        label: String,
        isRequired: Bool,
        labelWidth: CGFloat?,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack {
            LabelView(label: label, isRequired: isRequired)
                .frame(width: labelWidth ?? 100, alignment: .leading)
                .lineLimit(1)

            content()
        }
    }

    /// Inline layout with label and input on same line
    static func inlineLayout<Content: View>(
        label: String,
        isRequired: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack {
            LabelView(label: label, isRequired: isRequired)
            content()
            Spacer()
        }
    }
}

// MARK: - Label View
/// Reusable label component for input fields
struct LabelView: View {
    let label: String
    let isRequired: Bool

    var body: some View {
        HStack {
            Text(self.label)
                .font(ResponsiveDesign.bodyFont())
                .fontWeight(.medium)
                .foregroundColor(AppTheme.fontColor)

            if self.isRequired {
                Text("*")
                    .foregroundColor(AppTheme.accentRed)
            }
        }
    }
}

// MARK: - Input Container Styling
/// Styling for input containers
struct InputContainerStyle {
    static func apply<Content: View>(
        to content: Content,
        isEnabled: Bool,
        cornerRadius: CGFloat?
    ) -> some View {
        content
            .disabled(!isEnabled)
            .opacity(isEnabled ? 1.0 : 0.6)
    }
}

// MARK: - Input Field Background
/// Standard input field background styling
@MainActor
struct InputFieldBackground: ViewModifier {
    let cornerRadius: CGFloat?

    func body(content: Content) -> some View {
        content
            .padding(ResponsiveDesign.spacing(16))
            .background(AppTheme.inputFieldBackground)
            .cornerRadius(self.cornerRadius ?? (ResponsiveDesign.isCompactDevice() ? 10 : 12))
    }
}

extension View {
    func inputFieldBackground(cornerRadius: CGFloat? = nil) -> some View {
        modifier(InputFieldBackground(cornerRadius: cornerRadius))
    }
}

// MARK: - Icon Styling
/// Styling for input field icons
struct InputFieldIcon: View {
    let iconName: String
    let color: Color

    init(iconName: String, color: Color = AppTheme.inputFieldPlaceholder) {
        self.iconName = iconName
        self.color = color
    }

    var body: some View {
        Image(systemName: self.iconName)
            .foregroundColor(self.color)
            .frame(width: ResponsiveDesign.iconSize())
    }
}

// MARK: - Text Styling
/// Text styling for input fields
@MainActor
struct InputFieldTextStyle {
    static var primary: Font {
        ResponsiveDesign.inputFieldPrimaryFont()
    }
    static var secondary: Font {
        ResponsiveDesign.captionFont()
    }
    static let primaryColor = AppTheme.inputFieldText
    static let placeholderColor = AppTheme.inputFieldPlaceholder
}

// MARK: - Button Styling
/// Button styling for interactive input fields
struct InputFieldButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}
