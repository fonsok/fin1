import Foundation

// MARK: - SignUp Step Navigation

extension SignUpStep {
    /// Get next step for a specific role
    static func nextStep(after currentStep: SignUpStep, role: UserRole) -> SignUpStep? {
        let stepsForRole = SignUpStep.stepsForRole(role)
        guard let currentIndex = stepsForRole.firstIndex(of: currentStep),
              currentIndex + 1 < stepsForRole.count else {
            return nil
        }
        return stepsForRole[currentIndex + 1]
    }
    
    /// Get previous step for a specific role
    static func previousStep(before currentStep: SignUpStep, role: UserRole) -> SignUpStep? {
        let stepsForRole = SignUpStep.stepsForRole(role)
        guard let currentIndex = stepsForRole.firstIndex(of: currentStep),
              currentIndex > 0 else {
            return nil
        }
        return stepsForRole[currentIndex - 1]
    }
    
    /// Check if step is the first step for a specific role
    static func isFirstStep(_ step: SignUpStep, role: UserRole) -> Bool {
        let stepsForRole = SignUpStep.stepsForRole(role)
        return step == stepsForRole.first
    }
    
    /// Check if step is the last step for a specific role
    static func isLastStep(_ step: SignUpStep, role: UserRole) -> Bool {
        let stepsForRole = SignUpStep.stepsForRole(role)
        return step == stepsForRole.last
    }
    
    /// Get progress percentage for a step with role
    static func progressPercentage(for step: SignUpStep, role: UserRole) -> Double {
        let stepsForRole = SignUpStep.stepsForRole(role)
        guard let index = stepsForRole.firstIndex(of: step) else {
            return 0.0
        }
        return Double(index + 1) / Double(stepsForRole.count)
    }
    
    /// Get step number as string for a specific role (e.g., "1 of 17")
    static func stepNumberString(for step: SignUpStep, role: UserRole) -> String {
        let stepsForRole = SignUpStep.stepsForRole(role)
        guard let index = stepsForRole.firstIndex(of: step) else {
            return "0 of \(stepsForRole.count)"
        }
        return "\(index + 1) of \(stepsForRole.count)"
    }
}

// MARK: - Legacy Navigation Methods (for backward compatibility)

extension SignUpStep {
    /// Legacy method: Get step by number (ignores role-specific filtering)
    static func step(for number: Int) -> SignUpStep? {
        SignUpStep.allCases.first { $0.rawValue == number }
    }
    
    /// Legacy method: Get next step (ignores role-specific filtering)
    static func nextStep(after currentStep: SignUpStep) -> SignUpStep? {
        guard let currentIndex = SignUpStep.allCases.firstIndex(of: currentStep),
              currentIndex + 1 < SignUpStep.allCases.count else {
            return nil
        }
        return SignUpStep.allCases[currentIndex + 1]
    }
    
    /// Legacy method: Get previous step (ignores role-specific filtering)
    static func previousStep(before currentStep: SignUpStep) -> SignUpStep? {
        guard let currentIndex = SignUpStep.allCases.firstIndex(of: currentStep),
              currentIndex > 0 else {
            return nil
        }
        return SignUpStep.allCases[currentIndex - 1]
    }
    
    /// Legacy method: Check if first step (ignores role-specific filtering)
    static func isFirstStep(_ step: SignUpStep) -> Bool {
        step == SignUpStep.allCases.first
    }
    
    /// Legacy method: Check if last step (ignores role-specific filtering)
    static func isLastStep(_ step: SignUpStep) -> Bool {
        step == SignUpStep.allCases.last
    }
    
    /// Legacy method: Get progress percentage (ignores role-specific filtering)
    static func progressPercentage(for step: SignUpStep) -> Double {
        guard let index = SignUpStep.allCases.firstIndex(of: step) else {
            return 0.0
        }
        return Double(index + 1) / Double(SignUpStep.allCases.count)
    }
    
    /// Legacy method: Get step number string (ignores role-specific filtering)
    static func stepNumberString(for step: SignUpStep) -> String {
        guard let index = SignUpStep.allCases.firstIndex(of: step) else {
            return "0 of \(SignUpStep.allCases.count)"
        }
        return "\(index + 1) of \(SignUpStep.allCases.count)"
    }
}
