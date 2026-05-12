import SwiftUI

struct EmailVerificationStep: View {
    let email: String
    @Binding var verificationCode: String
    let isVerifying: Bool
    let errorMessage: String?
    let canResend: Bool
    let resendCountdown: Int
    let onVerify: () -> Void
    let onResend: () -> Void

    @FocusState private var isCodeFieldFocused: Bool

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(24)) {
            // Icon
            Image(systemName: "envelope.badge.shield.half.filled")
                .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize() * 3))
                .foregroundColor(AppTheme.accentLightBlue)

            // Title & instructions
            VStack(spacing: ResponsiveDesign.spacing(8)) {
                Text("E-Mail bestätigen")
                    .font(ResponsiveDesign.titleFont())
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.fontColor)

                Text("Wir haben einen 6-stelligen Code an **\(email)** gesendet.")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.8))
                    .multilineTextAlignment(.center)
            }

            // Code input
            VStack(spacing: ResponsiveDesign.spacing(8)) {
                TextField("000000", text: $verificationCode)
                    .keyboardType(.numberPad)
                    .font(ResponsiveDesign.monospacedFont(size: 32, weight: .bold))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: ResponsiveDesign.spacing(240))
                    .padding(ResponsiveDesign.spacing(12))
                    .background(AppTheme.systemSecondaryBackground)
                    .cornerRadius(ResponsiveDesign.spacing(12))
                    .overlay(
                        RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(12))
                            .stroke(errorMessage != nil ? Color.red : AppTheme.accentLightBlue.opacity(0.4), lineWidth: 1)
                    )
                    .focused($isCodeFieldFocused)
                    .onChange(of: verificationCode) { _, newValue in
                        let filtered = String(newValue.filter(\.isNumber).prefix(6))
                        if filtered != newValue { verificationCode = filtered }
                        if filtered.count == 6 { onVerify() }
                    }

                if let error = errorMessage {
                    Text(error)
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }
            }

            // Verify button (for users who don't trigger auto-verify)
            if verificationCode.count == 6 {
                Button(action: onVerify) {
                    HStack {
                        if isVerifying {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Text("Bestätigen")
                                .font(ResponsiveDesign.headlineFont())
                        }
                    }
                    .foregroundColor(AppTheme.screenBackground)
                    .frame(maxWidth: ResponsiveDesign.spacing(240))
                    .frame(height: ResponsiveDesign.spacing(48))
                    .background(AppTheme.accentLightBlue)
                    .cornerRadius(ResponsiveDesign.spacing(12))
                }
                .disabled(isVerifying)
            }

            // Resend
            VStack(spacing: ResponsiveDesign.spacing(4)) {
                Text("Code nicht erhalten?")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.6))

                if canResend {
                    Button("Neuen Code senden", action: onResend)
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(AppTheme.accentLightBlue)
                } else {
                    Text("Neuer Code in \(resendCountdown)s")
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.4))
                }
            }
            .padding(.top, ResponsiveDesign.spacing(8))
        }
        .onAppear {
            isCodeFieldFocused = true
        }
    }
}

#Preview {
    EmailVerificationStep(
        email: "max@example.com",
        verificationCode: .constant(""),
        isVerifying: false,
        errorMessage: nil,
        canResend: false,
        resendCountdown: 45,
        onVerify: {},
        onResend: {}
    )
    .padding()
    .background(AppTheme.screenBackground)
}
