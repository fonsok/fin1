import SwiftUI

// MARK: - Satisfaction Survey View
/// Customer-facing view for submitting feedback after ticket closure
/// Components extracted to SurveyComponents.swift

struct SatisfactionSurveyView: View {
    let surveyRequest: SurveyRequest
    let onSubmit: (Int, Bool, Bool, Bool, String?) async -> Void
    let onDismiss: () -> Void

    @State private var rating: Int = 0
    @State private var wasIssueResolved: Bool = true
    @State private var wasAgentHelpful: Bool = true
    @State private var wasResponseTimeSatisfactory: Bool = true
    @State private var comment: String = ""
    @State private var isSubmitting: Bool = false
    @State private var showThankYou: Bool = false

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.screenBackground.ignoresSafeArea()

                if self.showThankYou {
                    SurveyThankYouView(onDismiss: self.onDismiss)
                } else {
                    self.surveyContent
                }
            }
            .navigationTitle("Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Schließen") {
                        self.onDismiss()
                        self.dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Survey Content

    private var surveyContent: some View {
        ScrollView {
            VStack(spacing: ResponsiveDesign.spacing(24)) {
                SurveyHeader(
                    ticketNumber: self.surveyRequest.ticketNumber,
                    agentName: self.surveyRequest.agentName
                )
                self.ratingSection
                self.quickFeedbackSection
                self.commentSection
                self.submitButton
            }
            .padding()
        }
    }

    // MARK: - Rating Section

    private var ratingSection: some View {
        VStack(spacing: ResponsiveDesign.spacing(16)) {
            Text("Gesamtbewertung")
                .font(ResponsiveDesign.headlineFont())
                .foregroundColor(AppTheme.fontColor)

            StarRatingView(rating: self.$rating)

            if self.rating > 0 {
                Text(SurveyRatingHelper.ratingText(for: self.rating))
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(SurveyRatingHelper.starColor(for: self.rating))
                    .transition(.opacity)
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    // MARK: - Quick Feedback Section

    private var quickFeedbackSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(16)) {
            Text("Schnelles Feedback")
                .font(ResponsiveDesign.headlineFont())
                .foregroundColor(AppTheme.fontColor)

            FeedbackToggle(
                icon: "checkmark.circle.fill",
                title: "Problem gelöst",
                isOn: self.$wasIssueResolved,
                color: AppTheme.accentGreen
            )

            FeedbackToggle(
                icon: "person.fill.checkmark",
                title: "Mitarbeiter war hilfreich",
                isOn: self.$wasAgentHelpful,
                color: AppTheme.accentLightBlue
            )

            FeedbackToggle(
                icon: "clock.fill",
                title: "Antwortzeit zufriedenstellend",
                isOn: self.$wasResponseTimeSatisfactory,
                color: AppTheme.accentOrange
            )
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    // MARK: - Comment Section

    private var commentSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            HStack {
                Text("Zusätzliche Kommentare")
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(AppTheme.fontColor)

                Text("(optional)")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.5))
            }

            TextEditor(text: self.$comment)
                .frame(minHeight: 100)
                .padding(ResponsiveDesign.spacing(12))
                .background(AppTheme.systemTertiaryBackground)
                .cornerRadius(ResponsiveDesign.spacing(8))
                .foregroundColor(AppTheme.fontColor)
                .scrollContentBackground(.hidden)

            Text("Ihr Feedback hilft uns, unseren Service zu verbessern.")
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.6))
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    // MARK: - Submit Button

    private var submitButton: some View {
        Button {
            Task { await self.submitSurvey() }
        } label: {
            HStack {
                if self.isSubmitting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: "paperplane.fill")
                    Text("Feedback absenden")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(self.rating > 0 ? AppTheme.accentGreen : AppTheme.fontColor.opacity(0.3))
            .foregroundColor(.white)
            .cornerRadius(ResponsiveDesign.spacing(12))
        }
        .disabled(self.rating == 0 || self.isSubmitting)
    }

    // MARK: - Actions

    private func submitSurvey() async {
        self.isSubmitting = true
        await self.onSubmit(
            self.rating,
            self.wasIssueResolved,
            self.wasAgentHelpful,
            self.wasResponseTimeSatisfactory,
            self.comment.isEmpty ? nil : self.comment
        )
        self.isSubmitting = false

        withAnimation {
            self.showThankYou = true
        }
    }
}

// MARK: - Preview

#Preview {
    SatisfactionSurveyView(
        surveyRequest: SurveyRequest(
            id: "1",
            ticketId: "ticket-1",
            ticketNumber: "TKT-12345",
            userId: "user:preview@test.com",
            agentId: "user:csr1@test.com",
            agentName: "Stefan Müller",
            ticketSubject: "Problem mit meinem Konto",
            ticketClosedAt: Date(),
            requestSentAt: Date(),
            isCompleted: false,
            completedAt: nil
        ),
        onSubmit: { _, _, _, _, _ in },
        onDismiss: {}
    )
}
