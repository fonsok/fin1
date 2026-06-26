import SwiftUI

struct SignUpNavigationButtons: View {
    let coordinator: SignUpCoordinator
    let signUpData: SignUpData
    let onComplete: () -> Void
    var onShowTermsOfService: (() -> Void)? = nil

    var body: some View {
        // Hide standard navigation buttons on steps that have their own custom action buttons
        if self.coordinator.currentStep == .emailVerification ||
            self.coordinator.currentStep == .phoneVerification ||
            self.coordinator.currentStep == .riskClassificationNote ||
            self.coordinator.currentStep == .riskClass7Confirmation ||
            self.coordinator.currentStep == .roleAgreement ||
            (self.coordinator.currentStep == .summary && self.signUpData.finalRiskClass == .riskClass7) {
            EmptyView()
        } else {
            VStack(spacing: ResponsiveDesign.spacing(12)) {
                // Button container
                if self.coordinator.isFirstStep {
                    // Step 1: single centered button with vertical space above
                    HStack {
                        Spacer()
                        self.continueButton
                        Spacer()
                    }
                    .padding(.top, ResponsiveDesign.spacing(16))
                } else if self.coordinator.currentStep == .contact {
                    // Step 2: single button without back button
                    self.continueButton
                        .padding(.top, ResponsiveDesign.spacing(16))
                } else {
                    // Other steps: back button and continue button
                    HStack(spacing: ResponsiveDesign.spacing(16)) {
                        // Back Button
                        if self.coordinator.canGoBack {
                            Button(action: self.coordinator.previousStep, label: {
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
                        self.continueButton
                    }
                    .padding(.top, ResponsiveDesign.spacing(16))
                }
            }
        }
    }

    // MARK: - Continue Button
    @ViewBuilder
    private var continueButton: some View {
        if self.coordinator.canGoForward {
            Button(action: {
                if self.coordinator.currentStep == .contact {
                    Task {
                        await self.coordinator.createAccountIfNeeded(with: self.signUpData)
                    }
                } else if self.coordinator.currentStep == .identificationType && self.signUpData.identificationType == .postident {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        self.coordinator.currentStep = .postidentConfirmation
                    }
                } else {
                    self.coordinator.nextStep()
                }
            }) {
                HStack {
                    if self.coordinator.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Text(self.coordinator.currentStep == .contact ? "Konto anlegen" : "Continue")
                            .font(ResponsiveDesign.headlineFont())
                    }
                }
                .foregroundColor(AppTheme.screenBackground)
                .frame(maxWidth: self.coordinator.isFirstStep ? ResponsiveDesign.spacing(300) : .infinity)
                .frame(height: ResponsiveDesign.spacing(50))
                .background(
                    self.coordinator.canProceedToNextStep(with: self.signUpData) ? AppTheme.accentLightBlue : AppTheme.inputFieldPlaceholder
                )
                .cornerRadius(ResponsiveDesign.spacing(12))
            }
            .disabled(!self.coordinator.canProceedToNextStep(with: self.signUpData) || self.coordinator.isLoading)
            .accessibilityIdentifier(
                self.coordinator.currentStep == .contact ? "SignUpOpenAccountButton" : "SignUpContinueButton"
            )
        } else {
            Button(action: {
                // Complete registration (Risk Class 7 users will have already gone through confirmation)
                self.onComplete()
            }) {
                HStack {
                    if self.coordinator.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Text("Complete Registration")
                            .font(ResponsiveDesign.headlineFont())
                    }
                }
                .foregroundColor(AppTheme.screenBackground)
                .frame(maxWidth: self.coordinator.isFirstStep ? ResponsiveDesign.spacing(300) : .infinity)
                .frame(height: ResponsiveDesign.spacing(50))
                .background(
                    self.coordinator.canProceedToNextStep(with: self.signUpData) ? AppTheme.accentLightBlue : AppTheme.inputFieldPlaceholder
                )
                .cornerRadius(ResponsiveDesign.spacing(12))
            }
            .disabled(!self.coordinator.canProceedToNextStep(with: self.signUpData) || self.coordinator.isLoading)
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
