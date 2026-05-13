import SwiftUI

// Import Forms components
// Note: These components are now in the Forms subfolder

struct ContactStep: View {
    @Binding var email: String
    @Binding var phoneNumber: String
    @Binding var username: String
    @Binding var password: String
    @Binding var confirmPassword: String

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(20)) {
            Text("Contact Information")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.bold)
                .foregroundColor(AppTheme.fontColor)

            LabeledInputField(
                label: "Email Address",
                placeholder: "Enter your email address",
                icon: "envelope.fill",
                text: self.$email,
                isEmail: true
            )

            LabeledInputField(
                label: "Phone Number",
                placeholder: "Enter your phone number",
                icon: "phone.fill",
                text: self.$phoneNumber
            )

            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
                Text("Username")
                    .font(ResponsiveDesign.bodyFont())
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.fontColor)

                // Username requirements text
                Text("(Only characters A-Z, a-z, 0-9; min 4 chrs, max 10 chrs)")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.7))
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: ResponsiveDesign.spacing(12)) {
                    Image(systemName: "person.circle.fill")
                        .foregroundColor(AppTheme.inputFieldPlaceholder)
                        .frame(width: ResponsiveDesign.iconSize())

                    TextField("Enter Username", text: self.$username)
                        .font(ResponsiveDesign.headlineFont())
                        .foregroundColor(AppTheme.inputFieldText)
                        .textContentType(nil)
                        .keyboardType(.default)
                        .autocapitalization(.none)
                        .onChange(of: self.username) { _, newValue in
                            if newValue.count > 10 {
                                self.username = String(newValue.prefix(10))
                            }
                        }
                }
                .padding(ResponsiveDesign.spacing(16))
                .background(AppTheme.inputFieldBackground)
                .cornerRadius(ResponsiveDesign.isCompactDevice() ? 10 : 12)
            }

            LabeledSecureField(
                label: "Password",
                placeholder: "Create a strong password",
                icon: "lock.fill",
                text: self.$password
            )

            LabeledSecureField(
                label: "Confirm Password",
                placeholder: "Confirm your password",
                icon: "lock.fill",
                text: self.$confirmPassword
            )

            // Password Requirements
            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
                Text("Password Requirements:")
                    .font(ResponsiveDesign.captionFont())
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.fontColor.opacity(0.8))

                VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
                    PasswordRequirement(text: "At least 8 characters", isMet: self.password.count >= 8)
                    PasswordRequirement(
                        text: "Contains uppercase letter",
                        isMet: self.password.range(of: "[A-Z]", options: .regularExpression) != nil
                    )
                    PasswordRequirement(
                        text: "Contains lowercase letter",
                        isMet: self.password.range(of: "[a-z]", options: .regularExpression) != nil
                    )
                    PasswordRequirement(text: "Contains number", isMet: self.password.range(of: "[0-9]", options: .regularExpression) != nil)
                    PasswordRequirement(
                        text: "Contains special character",
                        isMet: self.password.range(of: "[!@#$%^&*(),.?\":{}|<>]", options: .regularExpression) != nil
                    )
                }
            }
            .padding()
            .background(AppTheme.sectionBackground)
            .cornerRadius(ResponsiveDesign.spacing(12))

            // 2FA Explanation
            Text("Your phone number will be used for SMS verification and two-factor authentication to secure your account.")
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    ContactStep(
        email: .constant("test@example.com"),
        phoneNumber: .constant("+49123456789"),
        username: .constant("testuser"),
        password: .constant(TestConstants.password),
        confirmPassword: .constant(TestConstants.password)
    )
    .background(AppTheme.screenBackground)
}
