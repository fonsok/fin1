import SwiftUI

// MARK: - Order Details Section Component
/// Shared component for displaying order details in order views
struct OrderDetailsSection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String = "Orderdetails", @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            Text(self.title)
                .font(ResponsiveDesign.headlineFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.8))

            self.content
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(10))
    }
}

// MARK: - Quantity Input Component
/// Shared component for quantity input with validation
struct QuantityInputField: View {
    @Binding var text: String
    let placeholder: String
    let accessibilityLabel: String
    let accessibilityHint: String
    let onSubmit: (() -> Void)?
    let maxValueWarning: MaxValueWarning?
    let errorMessage: String?

    struct MaxValueWarning {
        let enteredValue: Int
        let maxValue: Int
    }

    init(
        text: Binding<String>,
        placeholder: String,
        accessibilityLabel: String,
        accessibilityHint: String,
        onSubmit: (() -> Void)? = nil,
        maxValueWarning: MaxValueWarning? = nil,
        errorMessage: String? = nil
    ) {
        self._text = text
        self.placeholder = placeholder
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityHint = accessibilityHint
        self.onSubmit = onSubmit
        self.maxValueWarning = maxValueWarning
        self.errorMessage = errorMessage
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: ResponsiveDesign.spacing(4)) {
            HStack {
                Text("Stück")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.8))
                Spacer()
                ZStack(alignment: .trailing) {
                    TextField("", text: self.$text)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .foregroundColor(Color("InputText"))
                        .accentColor(Color("InputText"))
                        .padding(.horizontal, ResponsiveDesign.spacing(12))
                        .padding(.vertical, ResponsiveDesign.spacing(8))
                        .background(Color("InputFieldBackground"))
                        .cornerRadius(ResponsiveDesign.spacing(8))
                        .frame(width: ResponsiveDesign.spacing(145))
                        .onSubmit {
                            self.onSubmit?()
                        }
                        .accessibilityIdentifier("QuantityInputField")
                        .accessibilityLabel(self.accessibilityLabel)
                        .accessibilityHint(self.accessibilityHint)

                    // Custom placeholder
                    if self.text.isEmpty {
                        Text(self.placeholder)
                            .foregroundColor(Color("InputFieldPlaceholder"))
                            .multilineTextAlignment(.trailing)
                            .padding(.horizontal, ResponsiveDesign.spacing(12))
                            .padding(.vertical, ResponsiveDesign.spacing(8))
                            .allowsHitTesting(false)
                    }
                }
            }

            // Error message
            if let errorMessage = errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                        .font(ResponsiveDesign.captionFont())
                    Text(errorMessage)
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(.red)
                    Spacer()
                }
                .padding(.top, ResponsiveDesign.spacing(4))
            }

            // Maximum value warning
            if let warning = maxValueWarning {
                VStack(alignment: .trailing, spacing: ResponsiveDesign.spacing(2)) {
                    HStack {
                        Spacer()
                        Text("Eingabe: \(warning.enteredValue.formattedAsLocalizedNumber()) Stück")
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(AppTheme.accentRed.opacity(0.8))
                    }
                    HStack {
                        Spacer()
                        Text("max. \(warning.maxValue.formattedAsLocalizedNumber()) Stück")
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(AppTheme.accentRed.opacity(0.8))
                    }
                }
                .padding(.top, ResponsiveDesign.spacing(4))
            }
        }
    }
}

// MARK: - Order Type Selection Component
/// Shared component for order type selection
struct OrderTypeSelection<T: RawRepresentable & CaseIterable>: View where T.RawValue == String {
    @Binding var selectedOrderMode: T
    let onOrderModeChanged: (T) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            Text("Ausführungsart")
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.8))

            // Create a binding that converts between the types
            let binding = Binding<OrderTypeSegmentedControl.OrderType>(
                get: {
                    switch self.selectedOrderMode.rawValue {
                    case "market": return .market
                    case "limit": return .limit
                    default: return .market
                    }
                },
                set: { newValue in
                    switch newValue {
                    case .market:
                        if let newMode = T(rawValue: "market") {
                            self.selectedOrderMode = newMode
                            self.onOrderModeChanged(newMode)
                        }
                    case .limit:
                        if let newMode = T(rawValue: "limit") {
                            self.selectedOrderMode = newMode
                            self.onOrderModeChanged(newMode)
                        }
                    }
                }
            )

            OrderTypeSegmentedControl(selection: binding)
        }
    }
}

// MARK: - Limit Price Input Component
/// Shared component for limit price input with optimized performance
struct LimitPriceInput: View {
    @Binding var limitText: String
    let isVisible: Bool
    let onSubmit: (() -> Void)?
    let onChange: ((String) -> Void)?
    let validationMessage: String?
    let placeholder: String

    @State private var internalText: String = ""
    @FocusState private var isTextFieldFocused: Bool

    init(
        limitText: Binding<String>,
        isVisible: Bool,
        onSubmit: (() -> Void)? = nil,
        onChange: ((String) -> Void)? = nil,
        validationMessage: String? = nil,
        placeholder: String = "0,00 €"
    ) {
        self._limitText = limitText
        self.isVisible = isVisible
        self.onSubmit = onSubmit
        self.onChange = onChange
        self.validationMessage = validationMessage
        self.placeholder = placeholder
    }

    var body: some View {
        if self.isVisible {
            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
                Text("Limit")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.8))

                HStack {
                    Spacer()
                    ZStack(alignment: .trailing) {
                        TextField("", text: self.$internalText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(Color("InputText"))
                            .accentColor(Color("InputText"))
                            .padding(.horizontal, ResponsiveDesign.spacing(12))
                            .padding(.vertical, ResponsiveDesign.spacing(8))
                            .background(Color("InputFieldBackground"))
                            .cornerRadius(ResponsiveDesign.spacing(8))
                            .frame(width: ResponsiveDesign.spacing(145))
                            .focused(self.$isTextFieldFocused)
                            .onSubmit {
                                self.onSubmit?()
                            }
                            .onChange(of: self.internalText) { _, newValue in
                                // Optimized validation with debouncing
                                let filteredValue = self.validateAndFilterInput(newValue)
                                if filteredValue != newValue {
                                    self.internalText = filteredValue
                                }

                                // Update the binding with a slight delay to prevent excessive updates
                                DispatchQueue.main.async {
                                    self.limitText = filteredValue
                                    self.onChange?(filteredValue)
                                }
                            }
                            .onAppear {
                                self.internalText = self.limitText
                            }
                            .onChange(of: self.limitText) { _, newValue in
                                // Only update internal text if it's different to prevent loops
                                if newValue != self.internalText {
                                    self.internalText = newValue
                                }
                            }
                            .accessibilityIdentifier("LimitPriceField")
                            .accessibilityLabel("Limit price")
                            .accessibilityHint("Enter the limit price for your order")

                        // Custom placeholder
                        if self.internalText.isEmpty {
                            Text(self.placeholder)
                                .foregroundColor(Color("InputFieldPlaceholder"))
                                .multilineTextAlignment(.trailing)
                                .padding(.horizontal, ResponsiveDesign.spacing(12))
                                .padding(.vertical, ResponsiveDesign.spacing(8))
                                .allowsHitTesting(false)
                        }
                    }
                }

                // Validation message
                if let validationMessage = validationMessage {
                    Text(validationMessage)
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(.orange)
                        .padding(.top, ResponsiveDesign.spacing(4))
                }
            }
        }
    }

    // MARK: - Private Methods

    /// Optimized input validation and filtering
    private func validateAndFilterInput(_ input: String) -> String {
        // Filter to only allow numbers and commas
        let filteredValue = input.filter { character in
            character.isNumber || character == ","
        }

        // Prevent multiple commas
        let commaCount = filteredValue.filter { $0 == "," }.count
        if commaCount > 1 {
            // Keep only the first comma
            let parts = filteredValue.split(separator: ",", maxSplits: 1)
            return parts.joined(separator: ",")
        }

        return filteredValue
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: ResponsiveDesign.spacing(24)) {
        OrderDetailsSection {
            QuantityInputField(
                text: .constant("100"),
                placeholder: "Stück",
                accessibilityLabel: "Number of shares",
                accessibilityHint: "Enter the number of shares"
            )

            OrderTypeSelection(
                selectedOrderMode: .constant(OrderTypeSegmentedControl.OrderType.market),
                onOrderModeChanged: { _ in }
            )

            LimitPriceInput(
                limitText: .constant(""),
                isVisible: true
            )
        }
    }
    .padding()
    .background(AppTheme.screenBackground)
}
