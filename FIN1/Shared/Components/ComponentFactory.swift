import SwiftUI

// MARK: - Component Factory
/// Centralized component creation with consistent styling and behavior
/// Improves reusability and maintains design consistency
@MainActor
final class ComponentFactory {

    // MARK: - Input Field Components

    /// Creates a standardized text input field
    static func createTextInput(
        label: String,
        placeholder: String = "",
        text: Binding<String>,
        isRequired: Bool = false,
        validationState: ValidationState = .none,
        onTextChange: ((String) -> Void)? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            Text(label)
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor)

            TextField(placeholder, text: text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .onChange(of: text.wrappedValue) {
                    onTextChange?(text.wrappedValue)
                }
        }
    }

    /// Creates a standardized secure input field
    static func createSecureInput(
        label: String,
        placeholder: String = "",
        text: Binding<String>,
        isRequired: Bool = false,
        validationState: ValidationState = .none
    ) -> some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            Text(label)
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor)

            SecureField(placeholder, text: text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
    }

    // MARK: - Button Components

    /// Creates a standardized primary button
    static func createPrimaryButton(
        title: String,
        action: @escaping () -> Void,
        isEnabled: Bool = true,
        isLoading: Bool = false
    ) -> some View {
        Button(action: action, label: {
            HStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                }
                Text(title)
            }
            .frame(maxWidth: .infinity)
            .padding(ResponsiveDesign.spacing(12))
            .background(isEnabled ? AppTheme.buttonColor : Color.gray)
            .foregroundColor(AppTheme.fontColor)
            .cornerRadius(ResponsiveDesign.spacing(8))
        })
        .disabled(!isEnabled || isLoading)
    }

    /// Creates a standardized secondary button
    static func createSecondaryButton(
        title: String,
        action: @escaping () -> Void,
        isEnabled: Bool = true
    ) -> some View {
        Button(action: action, label: {
            Text(title)
                .frame(maxWidth: .infinity)
                .padding(ResponsiveDesign.spacing(12))
                .background(Color.clear)
                .foregroundColor(AppTheme.buttonColor)
                .overlay(
                    RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(8))
                        .stroke(AppTheme.buttonColor, lineWidth: 1)
                )
        })
        .disabled(!isEnabled)
    }

    // MARK: - Card Components

    /// Creates a standardized card container
    static func createCard<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            content()
        }
        .padding(ResponsiveDesign.spacing(16))
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }

    /// Creates a standardized list item
    static func createListItem<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: ResponsiveDesign.spacing(12)) {
            content()
        }
        .padding(ResponsiveDesign.spacing(12))
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(8))
    }

    // MARK: - Loading Components

    /// Creates a standardized loading view
    static func createLoadingView(message: String = "Loading...") -> some View {
        VStack(spacing: ResponsiveDesign.spacing(16)) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.accentGreen))
                .scaleEffect(1.2)

            Text(message)
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.screenBackground)
    }

    /// Creates a standardized error view
    static func createErrorView(
        message: String,
        retryAction: (() -> Void)? = nil
    ) -> some View {
        VStack(spacing: ResponsiveDesign.spacing(16)) {
            Image(systemName: "exclamationmark.triangle")
                .font(ResponsiveDesign.titleFont())
                .foregroundColor(AppTheme.accentRed)

            Text(message)
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor)
                .multilineTextAlignment(.center)

            if let retryAction = retryAction {
                self.createSecondaryButton(title: "Retry", action: retryAction)
            }
        }
        .padding(ResponsiveDesign.spacing(24))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.screenBackground)
    }

    // MARK: - Navigation Components

    /// Creates a standardized navigation header
    static func createNavigationHeader(
        title: String,
        subtitle: String? = nil,
        trailing: AnyView? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
            HStack {
                VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(2)) {
                    Text(title)
                        .font(ResponsiveDesign.titleFont())
                        .foregroundColor(AppTheme.fontColor)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(AppTheme.fontColor.opacity(0.7))
                    }
                }

                Spacer()

                if let trailing = trailing {
                    trailing
                }
            }
        }
        .padding(ResponsiveDesign.spacing(16))
        .background(AppTheme.sectionBackground)
    }

    // MARK: - Data Display Components

    /// Creates a standardized key-value display
    static func createKeyValueDisplay(
        key: String,
        value: String,
        valueColor: Color = AppTheme.fontColor
    ) -> some View {
        HStack {
            Text(key)
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))

            Spacer()

            Text(value)
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(valueColor)
        }
    }

    /// Creates a standardized section header
    static func createSectionHeader(
        title: String,
        subtitle: String? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
            Text(title)
                .font(ResponsiveDesign.headlineFont())
                .foregroundColor(AppTheme.fontColor)

            if let subtitle = subtitle {
                Text(subtitle)
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, ResponsiveDesign.spacing(16))
        .padding(.vertical, ResponsiveDesign.spacing(8))
    }
}
