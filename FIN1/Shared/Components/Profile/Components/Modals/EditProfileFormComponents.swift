import SwiftUI

// MARK: - Disabled Input Field

/// Reusable disabled/enabled input field for edit profile forms
struct EditProfileInputField: View {
    let label: String
    let placeholder: String
    let icon: String
    @Binding var text: String
    var isEmail: Bool = false
    var maxLength: Int?
    var isDisabled: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            Text(self.label)
                .font(ResponsiveDesign.bodyFont())
                .fontWeight(.medium)
                .foregroundColor(self.isDisabled ? AppTheme.fontColor.opacity(0.5) : AppTheme.fontColor)

            HStack(spacing: ResponsiveDesign.spacing(12)) {
                Image(systemName: self.icon)
                    .foregroundColor(self.isDisabled ? AppTheme.inputFieldPlaceholder.opacity(0.5) : AppTheme.inputFieldPlaceholder)
                    .frame(width: ResponsiveDesign.iconSize())

                TextField(self.placeholder, text: self.$text)
                    .font(ResponsiveDesign.isCompactDevice() ? .title3 : .title2)
                    .foregroundColor(self.isDisabled ? AppTheme.inputFieldText.opacity(0.5) : AppTheme.inputFieldText)
                    .textContentType(self.isEmail ? .emailAddress : nil)
                    .keyboardType(self.isEmail ? .emailAddress : .default)
                    .autocapitalization(.none)
                    .disabled(self.isDisabled)
                    .onChange(of: self.text) { _, newValue in
                        if let maxLength = maxLength, newValue.count > maxLength {
                            self.text = String(newValue.prefix(maxLength))
                        }
                    }
            }
            .padding(ResponsiveDesign.spacing(16))
            .background(self.isDisabled ? AppTheme.inputFieldBackground.opacity(0.5) : AppTheme.inputFieldBackground)
            .cornerRadius(ResponsiveDesign.isCompactDevice() ? 10 : 12)
        }
    }
}

// MARK: - Salutation Picker

struct EditProfileSalutationPicker: View {
    let title: String
    @Binding var selection: Salutation
    var isDisabled: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            Text(self.title)
                .font(ResponsiveDesign.bodyFont())
                .fontWeight(.medium)
                .foregroundColor(self.isDisabled ? AppTheme.fontColor.opacity(0.5) : AppTheme.fontColor)

            Menu {
                ForEach(Salutation.allCases, id: \.self) { option in
                    Button(option.displayName) { self.selection = option }
                }
            } label: {
                HStack {
                    Text(self.selection.displayName)
                        .foregroundColor(self.isDisabled ? AppTheme.inputFieldText.opacity(0.5) : AppTheme.inputFieldText)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .foregroundColor(self.isDisabled ? AppTheme.inputFieldText.opacity(0.5) : AppTheme.inputFieldText)
                }
                .padding()
                .background(self.isDisabled ? AppTheme.inputFieldBackground.opacity(0.5) : AppTheme.inputFieldBackground)
                .cornerRadius(ResponsiveDesign.spacing(12))
            }
            .disabled(self.isDisabled)
        }
    }
}

// MARK: - Employment Status Picker

struct EditProfileEmploymentPicker: View {
    let title: String
    @Binding var selection: EmploymentStatus
    var isDisabled: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            Text(self.title)
                .font(ResponsiveDesign.bodyFont())
                .fontWeight(.medium)
                .foregroundColor(self.isDisabled ? AppTheme.fontColor.opacity(0.5) : AppTheme.fontColor)

            Menu {
                ForEach(EmploymentStatus.allCases, id: \.self) { option in
                    Button(option.displayName) { self.selection = option }
                }
            } label: {
                HStack {
                    Text(self.selection.displayName)
                        .foregroundColor(self.isDisabled ? AppTheme.inputFieldText.opacity(0.5) : AppTheme.inputFieldText)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .foregroundColor(self.isDisabled ? AppTheme.inputFieldText.opacity(0.5) : AppTheme.inputFieldText)
                }
                .padding()
                .background(self.isDisabled ? AppTheme.inputFieldBackground.opacity(0.5) : AppTheme.inputFieldBackground)
                .cornerRadius(ResponsiveDesign.spacing(12))
            }
            .disabled(self.isDisabled)
        }
    }
}

// MARK: - Lock Message View

struct EditProfileLockMessage: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: ResponsiveDesign.spacing(8)) {
            Image(systemName: "lock.fill")
                .foregroundColor(AppTheme.accentOrange)
                .font(ResponsiveDesign.captionFont())
            Text(self.message)
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.8))
            Spacer()
        }
        .padding(ResponsiveDesign.spacing(12))
        .background(AppTheme.accentOrange.opacity(0.1))
        .cornerRadius(ResponsiveDesign.spacing(8))
    }
}

// MARK: - KYC Compliance Message

struct EditProfileKYCMessage: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: ResponsiveDesign.spacing(8)) {
            Image(systemName: self.icon)
                .foregroundColor(AppTheme.accentLightBlue)
                .font(ResponsiveDesign.bodyFont())

            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
                Text(self.title)
                    .font(ResponsiveDesign.captionFont())
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.fontColor)
                Text(self.message)
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.8))
            }
            Spacer()
        }
        .padding(ResponsiveDesign.spacing(12))
        .background(AppTheme.accentLightBlue.opacity(0.1))
        .cornerRadius(ResponsiveDesign.spacing(8))
    }
}

// MARK: - Request Change Button

struct EditProfileRequestChangeButton: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: self.action) {
            HStack {
                Image(systemName: self.icon)
                    .font(ResponsiveDesign.bodyFont())
                Text(self.title)
                    .font(ResponsiveDesign.bodyFont())
                    .fontWeight(.medium)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(ResponsiveDesign.captionFont())
            }
            .foregroundColor(AppTheme.accentLightBlue)
            .padding(ResponsiveDesign.spacing(12))
            .background(AppTheme.accentLightBlue.opacity(0.1))
            .cornerRadius(ResponsiveDesign.spacing(8))
        }
    }
}

// MARK: - Section Header with Badge

struct EditProfileSectionHeader: View {
    let title: String
    var showKYCBadge: Bool = false
    var showLock: Bool = false

    var body: some View {
        HStack {
            Text(self.title)
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.fontColor)

            Spacer()

            if self.showKYCBadge {
                HStack(spacing: ResponsiveDesign.spacing(4)) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.accentGreen)
                    Text("KYC Verified")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.accentGreen)
                }
            } else if self.showLock {
                Image(systemName: "lock.fill")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.accentOrange)
            }
        }
    }
}

// MARK: - Previews

#Preview("Input Field") {
    EditProfileInputField(
        label: "First Name",
        placeholder: "Enter name",
        icon: "person.fill",
        text: .constant("John")
    )
    .padding()
}

#Preview("Lock Message") {
    EditProfileLockMessage(message: "This field is locked during verification")
        .padding()
}





