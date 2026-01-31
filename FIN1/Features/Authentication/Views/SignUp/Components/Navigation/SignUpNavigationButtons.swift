import SwiftUI

struct SignUpNavigationButtons: View {
    let coordinator: SignUpCoordinator
    let signUpData: SignUpData
    let onComplete: () -> Void
    var onShowTermsOfService: (() -> Void)? = nil

    var body: some View {
        // Hide standard navigation buttons on steps that have their own custom action buttons
        if coordinator.currentStep == .riskClassificationNote ||
           coordinator.currentStep == .riskClass7Confirmation ||
           (coordinator.currentStep == .summary && signUpData.finalRiskClass == .riskClass7) {
            EmptyView()
        } else {
            VStack(spacing: ResponsiveDesign.spacing(12)) {
                // Privacy statement for step 2 (contact step)
                if coordinator.currentStep == .contact {
                    privacyStatementView
                }

                // Button container
                if coordinator.isFirstStep {
                    // Step 1: single centered button with vertical space above
                    HStack {
                        Spacer()
                        continueButton
                        Spacer()
                    }
                    .padding(.top, ResponsiveDesign.spacing(16))
                } else if coordinator.currentStep == .contact {
                    // Step 2: single button without back button
                    continueButton
                        .padding(.top, ResponsiveDesign.spacing(16))
                } else {
                    // Other steps: back button and continue button
                    HStack(spacing: ResponsiveDesign.spacing(16)) {
                        // Back Button
                        if coordinator.canGoBack {
                            Button(action: coordinator.previousStep, label: {
                                HStack {
                                    Image(systemName: "chevron.left")
                                        .font(ResponsiveDesign.headlineFont())
                                    Text("Back")
                                        .font(ResponsiveDesign.headlineFont())
                                }
                                .foregroundColor(AppTheme.accentLightBlue)
                                .frame(maxWidth: .infinity)
                                .frame(height: ResponsiveDesign.spacing(50))
                                .background(Color.clear)
                                .overlay(
                                    RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(12))
                                        .stroke(AppTheme.accentLightBlue, lineWidth: 2)
                                )
                            })
                        } else {
                            // Placeholder for spacing when no back button
                            Color.clear
                                .frame(maxWidth: .infinity)
                                .frame(height: ResponsiveDesign.spacing(50))
                        }

                        // Continue/Complete Button
                        continueButton
                    }
                    .padding(.top, ResponsiveDesign.spacing(16))
                }
            }
            .padding(.horizontal, ResponsiveDesign.lightBlueAreaHorizontalPadding())
        }
    }

    // MARK: - Privacy Statement View
    private var privacyStatementView: some View {
        (Text("By opening an account, you agree with FIN!'s ")
            .font(ResponsiveDesign.bodyFont())
            .foregroundColor(AppTheme.fontColor)
         + Text("Terms of Service")
            .font(ResponsiveDesign.bodyFont())
            .foregroundColor(AppTheme.accentLightBlue)
            .underline()
         + Text(".")
            .font(ResponsiveDesign.bodyFont())
            .foregroundColor(AppTheme.fontColor))
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, ResponsiveDesign.spacing(8))
        .padding(.vertical, ResponsiveDesign.spacing(8))
        .lineLimit(nil)
        .fixedSize(horizontal: false, vertical: true)
        .contentShape(Rectangle())
        .onTapGesture {
            onShowTermsOfService?()
        }
    }

    // MARK: - Continue Button
    @ViewBuilder
    private var continueButton: some View {
        if coordinator.canGoForward {
            Button(action: {
                // Handle Postident flow or regular flow
                if coordinator.currentStep == .identificationType && signUpData.identificationType == .postident {
                    // Skip directly to Postident confirmation
                    withAnimation(.easeInOut(duration: 0.3)) {
                        coordinator.currentStep = .postidentConfirmation
                    }
                } else {
                    coordinator.nextStep()
                }
            }) {
                HStack {
                    if coordinator.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Text(coordinator.currentStep == .contact ? "Open your account" : "Continue")
                            .font(ResponsiveDesign.headlineFont())
                    }
                }
                .foregroundColor(AppTheme.screenBackground)
                .frame(maxWidth: coordinator.isFirstStep ? ResponsiveDesign.spacing(300) : .infinity)
                .frame(height: ResponsiveDesign.spacing(50))
                .background(coordinator.canProceedToNextStep(with: signUpData) ? AppTheme.accentLightBlue : AppTheme.inputFieldPlaceholder)
                .cornerRadius(ResponsiveDesign.spacing(12))
            }
            .disabled(!coordinator.canProceedToNextStep(with: signUpData) || coordinator.isLoading)
        } else {
            Button(action: {
                // Complete registration (Risk Class 7 users will have already gone through confirmation)
                onComplete()
            }) {
                HStack {
                    if coordinator.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Text("Complete Registration")
                            .font(ResponsiveDesign.headlineFont())
                    }
                }
                .foregroundColor(AppTheme.screenBackground)
                .frame(maxWidth: coordinator.isFirstStep ? ResponsiveDesign.spacing(300) : .infinity)
                .frame(height: ResponsiveDesign.spacing(50))
                .background(coordinator.canProceedToNextStep(with: signUpData) ? AppTheme.accentLightBlue : AppTheme.inputFieldPlaceholder)
                .cornerRadius(ResponsiveDesign.spacing(12))
            }
            .disabled(!coordinator.canProceedToNextStep(with: signUpData) || coordinator.isLoading)
        }
    }
}

#Preview {
    SignUpNavigationButtons(
        coordinator: SignUpCoordinator(),
        signUpData: SignUpData(),
        onComplete: {},
        onShowTermsOfService: {}
    )
    .background(AppTheme.screenBackground)
}
