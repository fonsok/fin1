import Foundation

// MARK: - SignUp Data Risk Calculation Extensions

extension SignUpData {
    // MARK: - Computed Properties for Risk Class

    var calculatedRiskClass: RiskClass {
        self.riskClassCalculationService.calculateRiskClass(for: self)
    }

    var finalRiskClass: RiskClass {
        if userSelectedRiskClass == .riskClass7 {
            return .riskClass7
        }
        if self.requiresConservativeRiskClassFromOnboarding {
            return .riskClass1
        }
        return userSelectedRiskClass ?? self.calculatedRiskClass
    }

    /// Persists conservative risk class when onboarding risk gates require it;
    /// clears a stale RC1 override when gates no longer apply so calculated RC 5/6 can surface.
    func syncOnboardingRiskClassSelection() {
        if self.requiresConservativeRiskClassFromOnboarding {
            guard self.userSelectedRiskClass != .riskClass7 else { return }
            self.userSelectedRiskClass = .riskClass1
            return
        }

        if self.userSelectedRiskClass == .riskClass1,
           self.calculatedRiskClass.rawValue > RiskClass.riskClass1.rawValue {
            self.userSelectedRiskClass = nil
        }
    }

    func updateLeveragedProductsTotalLossRiskAcknowledged(_ value: Bool) {
        self.leveragedProductsTotalLossRiskAcknowledged = value
        self.syncOnboardingRiskClassSelection()
    }

    func updateLeveragedProductsKnowledgeTestAnswer(questionId: String, optionId: String) {
        self.leveragedProductsKnowledgeTestAnswers[questionId] = optionId
        self.syncOnboardingRiskClassSelection()
    }

    /// User chose a higher risk class than the questionnaire calculated.
    var hasUserManuallyIncreasedRiskClass: Bool {
        guard let selected = userSelectedRiskClass else { return false }
        return selected.rawValue > self.calculatedRiskClass.rawValue
    }

    /// Whether step 22 should send the user back to the landing page instead of continuing onboarding.
    var shouldReturnToLandingAtRiskNote: Bool {
        if self.requiresConservativeRiskClassFromOnboarding {
            return true
        }
        switch self.finalRiskClass {
        case .riskClass1, .riskClass2, .riskClass3, .riskClass4:
            return true
        case .riskClass5, .riskClass6:
            return !self.hasUserManuallyIncreasedRiskClass
        case .riskClass7:
            return false
        }
    }

    /// Step 22 may offer manual upgrade to risk class 7 (questionnaire RC 4–6, no conservative gate).
    /// Independent of `shouldReturnToLandingAtRiskNote`: RC 5/6 users still see the upgrade path before leaving.
    var canOfferManualRiskClassUpgradeAtRiskNote: Bool {
        guard !self.requiresConservativeRiskClassFromOnboarding else { return false }
        guard self.finalRiskClass != .riskClass7 else { return false }

        let profileRiskClass = self.userSelectedRiskClass ?? self.calculatedRiskClass
        return [.riskClass4, .riskClass5, .riskClass6].contains(profileRiskClass)
    }

    /// Step 16 c) — role-specific minimum derivatives profile for risk class 5.
    var meetsRiskClass5DerivativesExperienceCriteria: Bool {
        switch userRole {
        case .trader:
            return self.meetsTraderRiskClass5DerivativesExperienceCriteria
        case .investor, .other, .admin, .customerService:
            return self.meetsInvestorRiskClass5DerivativesExperienceCriteria
        }
    }

    /// Trader: 50+ transactions, ≥ €10,000 invested, minutes to hours.
    var meetsTraderRiskClass5DerivativesExperienceCriteria: Bool {
        self.derivativesTransactionsCount == .fiftyPlus &&
            (self.derivativesInvestmentAmount == .tenThousandToHundredThousand ||
                self.derivativesInvestmentAmount == .moreThanHundredThousand) &&
            self.derivativesHoldingPeriod == .minutesToHours
    }

    /// Investor: at least 1–10 transactions, €1,000–€10,000 invested, days to weeks (or higher).
    var meetsInvestorRiskClass5DerivativesExperienceCriteria: Bool {
        guard let count = derivativesTransactionsCount,
              let amount = derivativesInvestmentAmount,
              let holding = derivativesHoldingPeriod else {
            return false
        }

        let meetsCount = count == .oneToTen || count == .tenToFifty || count == .fiftyPlus
        let meetsAmount = amount == .thousandToTenThousand ||
            amount == .tenThousandToHundredThousand ||
            amount == .moreThanHundredThousand
        let meetsHolding = holding == .daysToWeeks || holding == .minutesToHours

        return meetsCount && meetsAmount && meetsHolding
    }

    /// Prevents assignment to RC 5 when step 16 c) derivatives profile is insufficient.
    func cappedForRiskClass5DerivativesGate(_ riskClass: RiskClass) -> RiskClass {
        if riskClass == .riskClass5, !self.meetsRiskClass5DerivativesExperienceCriteria {
            return .riskClass4
        }
        return riskClass
    }
}
