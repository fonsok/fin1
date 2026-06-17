import Foundation

struct LeveragedProductsKnowledgeOption: Identifiable, Sendable, Equatable {
    let id: String
    let label: String
}

struct LeveragedProductsKnowledgeQuestion: Identifiable, Sendable, Equatable {
    let id: String
    let prompt: String
    let options: [LeveragedProductsKnowledgeOption]
    let correctOptionId: String
}

enum LeveragedProductsKnowledgeTest {
    static let version = "1.2"
    static let optionIds = ["A", "B", "C", "D"]

    /// Optional external resource (opened from the in-app learning page).
    static let externalLearnMoreURL = URL(string: "https://de.wikipedia.org/wiki/Optionsschein")

    static let questions: [LeveragedProductsKnowledgeQuestion] = [
        LeveragedProductsKnowledgeQuestion(
            id: "put_dow_jones_falling",
            prompt: "Was passiert mit einem Put-Optionsschein auf den Dow Jones, wenn der Kurs des Index fällt?",
            options: [
                LeveragedProductsKnowledgeOption(id: "A", label: "Der Wert des Optionsscheins steigt."),
                LeveragedProductsKnowledgeOption(id: "B", label: "Der Wert fällt."),
                LeveragedProductsKnowledgeOption(id: "C", label: "Es hat keinen Einfluss."),
                LeveragedProductsKnowledgeOption(id: "D", label: "Es gibt keine Put/Calls auf einen Index.")
            ],
            correctOptionId: "A"
        )
    ]

    static func question(id: String) -> LeveragedProductsKnowledgeQuestion? {
        self.questions.first { $0.id == id }
    }
}

enum LeveragedProductsLearningContent {
    static let externalURL = LeveragedProductsKnowledgeTest.externalLearnMoreURL

    static let teaserTitle = "Call-Optionsschein Erklärung, Beispiele, Risiken & mehr"
    static let teaserSubtitle =
        "Call/Put-Optionsscheine einfach erklärt: Grundlagen, Funktionsweise, Kennzahlen, Praxisbeispiele, Chancen und Risiken"
    static let readNowButtonTitle = "Jetzt lesen!"
}

extension SignUpData {
    var hasAnsweredAllLeveragedProductsKnowledgeTestQuestions: Bool {
        LeveragedProductsKnowledgeTest.questions.allSatisfy { question in
            self.leveragedProductsKnowledgeTestAnswers[question.id] != nil
        }
    }

    var hasPassedLeveragedProductsKnowledgeTest: Bool {
        LeveragedProductsKnowledgeTest.questions.allSatisfy { question in
            self.leveragedProductsKnowledgeTestAnswers[question.id] == question.correctOptionId
        }
    }

    /// Total-loss „Nein“ or failed knowledge test → conservative risk class 1 at summary.
    var requiresConservativeRiskClassFromOnboarding: Bool {
        if self.leveragedProductsTotalLossRiskAcknowledged == false { return true }
        if self.hasAnsweredAllLeveragedProductsKnowledgeTestQuestions,
           !self.hasPassedLeveragedProductsKnowledgeTest {
            return true
        }
        return false
    }

    func knowledgeTestAnswerState(for questionId: String) -> KnowledgeTestAnswerState {
        guard let selected = leveragedProductsKnowledgeTestAnswers[questionId] else {
            return .unanswered
        }
        guard let question = LeveragedProductsKnowledgeTest.question(id: questionId) else {
            return .unanswered
        }
        return selected == question.correctOptionId ? .correct : .incorrect
    }
}

enum KnowledgeTestAnswerState {
    case unanswered
    case correct
    case incorrect
}
