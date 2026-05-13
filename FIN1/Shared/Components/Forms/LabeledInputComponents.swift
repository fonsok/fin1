import SwiftUI

// MARK: - Reusable Labeled Input Components

struct LabeledInputField: View {
    let label: String
    let placeholder: String
    let icon: String
    @Binding var text: String
    let isEmail: Bool
    let maxLength: Int?
    
    init(
        label: String,
        placeholder: String,
        icon: String,
        text: Binding<String>,
        isEmail: Bool = false,
        maxLength: Int? = nil
    ) {
        self.label = label
        self.placeholder = placeholder
        self.icon = icon
        self._text = text
        self.isEmail = isEmail
        self.maxLength = maxLength
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            Text(self.label)
                .font(ResponsiveDesign.bodyFont())
                .fontWeight(.medium)
                .foregroundColor(AppTheme.fontColor)
            
            HStack(spacing: ResponsiveDesign.spacing(12)) {
                Image(systemName: self.icon)
                    .foregroundColor(AppTheme.inputFieldPlaceholder)
                    .frame(width: ResponsiveDesign.iconSize())
                
                TextField(self.placeholder, text: self.$text)
                    .font(ResponsiveDesign.isCompactDevice() ? .title3 : .title2) // Responsive font size
                    .foregroundColor(AppTheme.inputFieldText)
                    .textContentType(self.isEmail ? .emailAddress : nil)
                    .keyboardType(self.isEmail ? .emailAddress : .default)
                    .autocapitalization(.none)
                    .onChange(of: self.text) { _, newValue in
                        if let maxLength = maxLength, newValue.count > maxLength {
                            self.text = String(newValue.prefix(maxLength))
                        }
                    }
            }
            .padding(ResponsiveDesign.spacing(16))
            .background(AppTheme.inputFieldBackground)
            .cornerRadius(ResponsiveDesign.isCompactDevice() ? 10 : 12)
        }
    }
}

struct LabeledSecureField: View {
    let label: String
    let placeholder: String
    let icon: String
    @Binding var text: String
    
    init(
        label: String,
        placeholder: String,
        icon: String,
        text: Binding<String>
    ) {
        self.label = label
        self.placeholder = placeholder
        self.icon = icon
        self._text = text
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            Text(self.label)
                .font(ResponsiveDesign.bodyFont())
                .fontWeight(.medium)
                .foregroundColor(AppTheme.fontColor)
            
            HStack(spacing: ResponsiveDesign.spacing(12)) {
                Image(systemName: self.icon)
                    .foregroundColor(AppTheme.inputFieldPlaceholder)
                    .frame(width: ResponsiveDesign.iconSize())
                
                SecureField(self.placeholder, text: self.$text)
                    .font(ResponsiveDesign.isCompactDevice() ? .title3 : .title2) // Responsive font size
                    .foregroundColor(AppTheme.inputFieldText)
                    .textContentType(.password)
            }
            .padding(ResponsiveDesign.spacing(16))
            .background(AppTheme.inputFieldBackground)
            .cornerRadius(ResponsiveDesign.isCompactDevice() ? 10 : 12)
        }
    }
}
