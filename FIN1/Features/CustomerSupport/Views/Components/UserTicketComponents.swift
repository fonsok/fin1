import SwiftUI

// MARK: - User Ticket Components
/// Reusable components for user-facing ticket views

// MARK: - User Ticket Info Row

struct UserTicketInfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(self.label)
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))

            Spacer()

            Text(self.value)
                .font(ResponsiveDesign.bodyFont())
                .fontWeight(.medium)
                .foregroundColor(AppTheme.fontColor)
        }
    }
}

// MARK: - User Ticket Response Card

struct UserTicketResponseCard: View {
    let response: TicketResponse
    var showConfirmationButtons: Bool = false
    var isSubmitting: Bool = false
    var onConfirmSolved: (() -> Void)?
    var onReportNotSolved: (() -> Void)?

    /// Check if this response contains a confirmation request
    var isConfirmationRequest: Bool {
        self.response.message.contains("⏳") || self.response.message.contains("Bitte bestätigen Sie")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            HStack {
                Image(systemName: self.response.isInternal ? "lock.fill" : "person.fill")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(self.response.isInternal ? AppTheme.accentRed : AppTheme.accentLightBlue)

                Text(self.response.isInternal ? "Interne Notiz" : "Antwort")
                    .font(ResponsiveDesign.captionFont())
                    .fontWeight(.semibold)
                    .foregroundColor(self.response.isInternal ? AppTheme.accentRed : AppTheme.accentLightBlue)

                Spacer()

                Text(self.response.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.6))
            }

            if !self.response.isInternal {
                Text(self.response.message)
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor)

                // Show confirmation buttons if this is a confirmation request and buttons are enabled
                if self.showConfirmationButtons && self.isConfirmationRequest {
                    Divider()
                        .padding(.vertical, ResponsiveDesign.spacing(8))

                    InlineConfirmationButtons(
                        isSubmitting: self.isSubmitting,
                        onConfirmSolved: self.onConfirmSolved ?? {},
                        onReportNotSolved: self.onReportNotSolved ?? {}
                    )
                }
            } else {
                Text("Diese interne Notiz ist nur für Support-Mitarbeiter sichtbar.")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.6))
                    .italic()
            }
        }
        .padding()
        .background(self.response.isInternal ? AppTheme.accentRed.opacity(0.1) : AppTheme.accentLightBlue.opacity(0.1))
        .cornerRadius(ResponsiveDesign.spacing(8))
    }
}

// MARK: - Inline Confirmation Buttons

struct InlineConfirmationButtons: View {
    let isSubmitting: Bool
    let onConfirmSolved: () -> Void
    let onReportNotSolved: () -> Void

    var body: some View {
        VStack(spacing: ResponsiveDesign.spacing(8)) {
            Button {
                self.onConfirmSolved()
            } label: {
                HStack {
                    if self.isSubmitting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Problem gelöst")
                    }
                }
                .fontWeight(.semibold)
                .font(ResponsiveDesign.bodyFont())
                .frame(maxWidth: .infinity)
                .padding(.vertical, ResponsiveDesign.spacing(10))
                .background(AppTheme.accentGreen)
                .foregroundColor(.white)
                .cornerRadius(ResponsiveDesign.spacing(8))
            }
            .disabled(self.isSubmitting)

            Button {
                self.onReportNotSolved()
            } label: {
                HStack {
                    Image(systemName: "xmark.circle.fill")
                    Text("Problem nicht gelöst")
                }
                .fontWeight(.semibold)
                .font(ResponsiveDesign.bodyFont())
                .frame(maxWidth: .infinity)
                .padding(.vertical, ResponsiveDesign.spacing(10))
                .background(AppTheme.accentRed.opacity(0.15))
                .foregroundColor(AppTheme.accentRed)
                .cornerRadius(ResponsiveDesign.spacing(8))
            }
            .disabled(self.isSubmitting)
        }
    }
}

// MARK: - Confirmation Banner

struct ConfirmationRequiredBanner: View {
    var body: some View {
        HStack(spacing: ResponsiveDesign.spacing(12)) {
            Image(systemName: "hourglass")
                .font(ResponsiveDesign.headlineFont())
                .foregroundColor(AppTheme.accentOrange)

            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
                Text("Bestätigung erforderlich")
                    .font(ResponsiveDesign.headlineFont())
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.fontColor)

                Text("Bitte bestätigen Sie, ob das Problem gelöst wurde.")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.7))
            }

            Spacer()
        }
        .padding()
        .background(AppTheme.accentOrange.opacity(0.15))
        .cornerRadius(ResponsiveDesign.spacing(12))
    }
}

// MARK: - Confirmation Buttons

struct ConfirmationButtons: View {
    let isSubmitting: Bool
    let onConfirmSolved: () -> Void
    let onReportNotSolved: () -> Void

    var body: some View {
        HStack(spacing: ResponsiveDesign.spacing(12)) {
            Button {
                self.onConfirmSolved()
            } label: {
                HStack {
                    if self.isSubmitting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Ja, gelöst")
                    }
                }
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding()
                .background(AppTheme.accentGreen)
                .foregroundColor(.white)
                .cornerRadius(ResponsiveDesign.spacing(10))
            }
            .disabled(self.isSubmitting)

            Button {
                self.onReportNotSolved()
            } label: {
                HStack {
                    Image(systemName: "xmark.circle.fill")
                    Text("Nein, noch offen")
                }
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding()
                .background(AppTheme.accentRed.opacity(0.15))
                .foregroundColor(AppTheme.accentRed)
                .cornerRadius(ResponsiveDesign.spacing(10))
            }
            .disabled(self.isSubmitting)
        }
    }
}

// MARK: - Problem Not Solved Sheet

struct ProblemNotSolvedSheet: View {
    @Binding var additionalInfo: String
    let isSubmitting: Bool
    let onSubmit: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.screenBackground.ignoresSafeArea()

                VStack(spacing: ResponsiveDesign.spacing(20)) {
                    VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
                        Text("Was ist noch nicht gelöst?")
                            .font(ResponsiveDesign.headlineFont())
                            .foregroundColor(AppTheme.fontColor)

                        Text("Bitte beschreiben Sie, was noch nicht funktioniert.")
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(AppTheme.fontColor.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    TextEditor(text: self.$additionalInfo)
                        .frame(minHeight: 150)
                        .padding(ResponsiveDesign.spacing(12))
                        .background(AppTheme.systemTertiaryBackground)
                        .cornerRadius(ResponsiveDesign.spacing(8))
                        .foregroundColor(AppTheme.fontColor)
                        .scrollContentBackground(.hidden)

                    Button {
                        self.onSubmit()
                    } label: {
                        HStack {
                            if self.isSubmitting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Ticket wieder öffnen")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(self.additionalInfo.isEmpty ? AppTheme.fontColor.opacity(0.3) : AppTheme.accentOrange)
                        .foregroundColor(.white)
                        .cornerRadius(ResponsiveDesign.spacing(10))
                    }
                    .disabled(self.additionalInfo.isEmpty || self.isSubmitting)

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Problem melden")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") {
                        self.onCancel()
                    }
                }
            }
        }
    }
}

// MARK: - Ticket Priority Helper

struct TicketPriorityHelper {
    static func color(for priority: SupportTicket.TicketPriority) -> Color {
        switch priority {
        case .low: return AppTheme.accentLightBlue
        case .medium: return AppTheme.accentOrange
        case .high, .urgent: return AppTheme.accentRed
        }
    }
}

