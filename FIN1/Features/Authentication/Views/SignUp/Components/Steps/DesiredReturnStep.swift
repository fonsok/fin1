import SwiftUI

struct DesiredReturnStep: View {
    @Binding var desiredReturn: DesiredReturn
    @Binding var leveragedProductsKnowledgeTestAnswers: [String: String]
    @Binding var leveragedProductsTotalLossRiskAcknowledged: Bool?
    @State private var showLearningPage = false

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(24)) {
            self.knowledgeTestSection

            Text("Gewinnziel")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.bold)
                .foregroundColor(AppTheme.fontColor)
                .multilineTextAlignment(.center)

            Text("Welche Renditeerwartung haben Sie an Ihren Anlagen?")
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.8))
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 8) {
                Text("Gewünschte Rendite:")
                    .font(ResponsiveDesign.bodyFont())
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.fontColor)

                Menu {
                    ForEach(DesiredReturn.allCases, id: \.self) { option in
                        Button(action: { self.desiredReturn = option }, label: {
                            Text(option.displayName)
                                .foregroundColor(AppTheme.inputFieldText)
                        })
                    }
                } label: {
                    HStack {
                        Text(self.desiredReturn.displayName)
                            .foregroundColor(AppTheme.inputFieldText)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .foregroundColor(AppTheme.inputFieldText)
                    }
                    .padding()
                    .background(AppTheme.inputFieldBackground)
                    .cornerRadius(ResponsiveDesign.spacing(12))
                }
            }

            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(16)) {
                Text("Verlusttragfähigkeit & Risikobereitschaft")
                    .font(ResponsiveDesign.headlineFont())
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.fontColor)

                Text(
                    "Sind Sie sich bewusst, dass die hier gehandelten Hebelprodukte ein Totalverlustrisiko bergen?"
                )
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.9))
                .multilineTextAlignment(.leading)

                VStack(spacing: ResponsiveDesign.spacing(8)) {
                    self.confirmationOption(
                        label: "Ja",
                        isSelected: self.leveragedProductsTotalLossRiskAcknowledged == true,
                        action: { self.leveragedProductsTotalLossRiskAcknowledged = true }
                    )
                    self.confirmationOption(
                        label: "Nein",
                        isSelected: self.leveragedProductsTotalLossRiskAcknowledged == false,
                        action: { self.leveragedProductsTotalLossRiskAcknowledged = false }
                    )
                }

                if self.leveragedProductsTotalLossRiskAcknowledged == nil {
                    Text("Bitte wählen Sie „Ja“ oder „Nein“.")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.6))
                        .multilineTextAlignment(.leading)
                }
            }
            .padding()
            .background(AppTheme.sectionBackground)
            .cornerRadius(ResponsiveDesign.spacing(12))
        }
        .sheet(isPresented: self.$showLearningPage) {
            LeveragedProductsLearningView()
        }
    }

    private var knowledgeTestSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(16)) {
            Text("Wissenstest")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.bold)
                .foregroundColor(AppTheme.fontColor)

            Text(
                "Bitte beantworten Sie die folgenden Kontrollfragen, damit wir prüfen können, ob Sie die Risiken der gehandelten Produkte verstehen."
            )
            .font(ResponsiveDesign.bodyFont())
            .foregroundColor(AppTheme.fontColor.opacity(0.8))
            .multilineTextAlignment(.leading)

            ForEach(LeveragedProductsKnowledgeTest.questions) { question in
                self.knowledgeTestQuestion(question)
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    private func knowledgeTestQuestion(_ question: LeveragedProductsKnowledgeQuestion) -> some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            Text(question.prompt)
                .font(ResponsiveDesign.bodyFont())
                .fontWeight(.medium)
                .foregroundColor(AppTheme.fontColor)
                .multilineTextAlignment(.leading)

            VStack(spacing: ResponsiveDesign.spacing(8)) {
                ForEach(question.options) { option in
                    self.knowledgeTestOption(
                        questionId: question.id,
                        option: option,
                        isSelected: self.leveragedProductsKnowledgeTestAnswers[question.id] == option.id
                    )
                }
            }

            if self.shouldShowKnowledgeTestLearningHint(for: question) {
                self.knowledgeTestLearningHint
            }
        }
        .padding(.vertical, ResponsiveDesign.spacing(4))
    }

    /// Learning CTA only after the user selected a wrong answer (hidden when unanswered or correct).
    private func shouldShowKnowledgeTestLearningHint(for question: LeveragedProductsKnowledgeQuestion) -> Bool {
        guard let selected = self.leveragedProductsKnowledgeTestAnswers[question.id] else {
            return false
        }
        return selected != question.correctOptionId
    }

    private var knowledgeTestLearningHint: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            HStack(alignment: .top, spacing: ResponsiveDesign.spacing(12)) {
                Image(systemName: "book.fill")
                    .foregroundColor(AppTheme.accentLightBlue)
                    .font(ResponsiveDesign.headlineFont())

                VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
                    Text(LeveragedProductsLearningContent.teaserTitle)
                        .font(ResponsiveDesign.bodyFont())
                        .fontWeight(.semibold)
                        .foregroundColor(AppTheme.fontColor)
                        .multilineTextAlignment(.leading)

                    Text(LeveragedProductsLearningContent.teaserSubtitle)
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.8))
                        .multilineTextAlignment(.leading)
                }
            }

            Button(LeveragedProductsLearningContent.readNowButtonTitle) {
                self.showLearningPage = true
            }
            .font(ResponsiveDesign.bodyFont())
            .fontWeight(.medium)
            .foregroundColor(AppTheme.fontColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, ResponsiveDesign.spacing(10))
            .background(AppTheme.accentLightBlue)
            .cornerRadius(ResponsiveDesign.spacing(10))

            if let externalURL = LeveragedProductsLearningContent.externalURL {
                Link("Weitere Informationen im Internet", destination: externalURL)
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.accentLightBlue)
            }

            Text("Sie können fortfahren. Am Ende der Registrierung wird Ihnen Risikoklasse 1 zugeordnet.")
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))
                .multilineTextAlignment(.leading)
        }
        .padding()
        .background(AppTheme.accentLightBlue.opacity(0.1))
        .cornerRadius(ResponsiveDesign.spacing(12))
        .overlay(
            RoundedRectangle(cornerRadius: ResponsiveDesign.spacing(12))
                .stroke(AppTheme.accentLightBlue.opacity(0.3), lineWidth: 1)
        )
    }

    private func knowledgeTestOption(
        questionId: String,
        option: LeveragedProductsKnowledgeOption,
        isSelected: Bool
    ) -> some View {
        Button {
            var answers = self.leveragedProductsKnowledgeTestAnswers
            answers[questionId] = option.id
            self.leveragedProductsKnowledgeTestAnswers = answers
        } label: {
            HStack(alignment: .top, spacing: ResponsiveDesign.spacing(12)) {
                InteractiveElement(isSelected: isSelected, type: .radioButton)
                Text(option.label)
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func confirmationOption(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: ResponsiveDesign.spacing(12)) {
                InteractiveElement(isSelected: isSelected, type: .radioButton)
                Text(label)
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor)
                Spacer()
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    DesiredReturnStep(
        desiredReturn: .constant(.atLeastTenPercent),
        leveragedProductsKnowledgeTestAnswers: .constant([:]),
        leveragedProductsTotalLossRiskAcknowledged: .constant(nil)
    )
    .background(AppTheme.screenBackground)
}
