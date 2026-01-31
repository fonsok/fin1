import Foundation

// MARK: - Step Configuration Manager

struct StepConfiguration {
    /// Total number of steps (automatically calculated)
    static var totalSteps: Int {
        SignUpStep.allCases.count
    }
    
    /// Get total steps for a specific role
    static func totalSteps(for role: UserRole) -> Int {
        SignUpStep.totalStepsForRole(role)
    }
    
    /// Get step by number for a specific role
    static func step(for number: Int, role: UserRole) -> SignUpStep? {
        let stepsForRole = SignUpStep.stepsForRole(role)
        guard number > 0 && number <= stepsForRole.count else {
            return nil
        }
        return stepsForRole[number - 1]
    }
    
    /// Get next step for a specific role
    static func nextStep(after currentStep: SignUpStep, role: UserRole) -> SignUpStep? {
        SignUpStep.nextStep(after: currentStep, role: role)
    }
    
    /// Get previous step for a specific role
    static func previousStep(before currentStep: SignUpStep, role: UserRole) -> SignUpStep? {
        SignUpStep.previousStep(before: currentStep, role: role)
    }
    
    /// Check if step is the first step for a specific role
    static func isFirstStep(_ step: SignUpStep, role: UserRole) -> Bool {
        SignUpStep.isFirstStep(step, role: role)
    }
    
    /// Check if step is the last step for a specific role
    static func isLastStep(_ step: SignUpStep, role: UserRole) -> Bool {
        SignUpStep.isLastStep(step, role: role)
    }
    
    /// Get progress percentage for a step with role
    static func progressPercentage(for step: SignUpStep, role: UserRole) -> Double {
        SignUpStep.progressPercentage(for: step, role: role)
    }
    
    /// Get step number as string for a specific role (e.g., "1 of 17")
    static func stepNumberString(for step: SignUpStep, role: UserRole) -> String {
        SignUpStep.stepNumberString(for: step, role: role)
    }
    
    // MARK: - Legacy Methods (for backward compatibility)
    
    /// Legacy method: Get step by number (ignores role-specific filtering)
    static func step(for number: Int) -> SignUpStep? {
        SignUpStep.step(for: number)
    }
    
    /// Legacy method: Get next step (ignores role-specific filtering)
    static func nextStep(after currentStep: SignUpStep) -> SignUpStep? {
        SignUpStep.nextStep(after: currentStep)
    }
    
    /// Legacy method: Get previous step (ignores role-specific filtering)
    static func previousStep(before currentStep: SignUpStep) -> SignUpStep? {
        SignUpStep.previousStep(before: currentStep)
    }
    
    /// Legacy method: Check if first step (ignores role-specific filtering)
    static func isFirstStep(_ step: SignUpStep) -> Bool {
        SignUpStep.isFirstStep(step)
    }
    
    /// Legacy method: Check if last step (ignores role-specific filtering)
    static func isLastStep(_ step: SignUpStep) -> Bool {
        SignUpStep.isLastStep(step)
    }
    
    /// Legacy method: Get progress percentage (ignores role-specific filtering)
    static func progressPercentage(for step: SignUpStep) -> Double {
        SignUpStep.progressPercentage(for: step)
    }
    
    /// Legacy method: Get step number string (ignores role-specific filtering)
    static func stepNumberString(for step: SignUpStep) -> String {
        SignUpStep.stepNumberString(for: step)
    }
}
