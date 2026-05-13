import SwiftUI

// MARK: - Dev Escalation Sheet
/// Sheet for CSR to escalate a bug to the development team

struct DevEscalationSheet: View {
    let ticket: SupportTicket
    @ObservedObject var viewModel: CustomerSupportDashboardViewModel
    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @State private var severity: BugSeverity = .medium
    @State private var description = ""
    @State private var stepsToReproduce: [String] = [""]
    @State private var expectedBehavior = ""
    @State private var actualBehavior = ""
    @State private var affectedCustomers = 1
    @State private var workaroundProvided = false
    @State private var workaroundDescription = ""
    @State private var selectedDevTeam = "Backend"
    @State private var jiraTicketId = ""
    @State private var isSubmitting = false

    private let devTeams = ["Backend", "Frontend", "Mobile", "Infrastructure", "Security", "Data"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ResponsiveDesign.spacing(16)) {
                    self.ticketInfoSection
                    self.severitySection
                    self.bugDescriptionSection
                    self.reproductionStepsSection
                    self.behaviorSection
                    self.impactSection
                    self.workaroundSection
                    self.teamSection
                }
                .padding()
            }
            .background(AppTheme.screenBackground.ignoresSafeArea())
            .navigationTitle("Bug an Entwicklung melden")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") { self.dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Eskalieren") {
                        Task { await self.submitEscalation() }
                    }
                    .disabled(!self.isFormValid || self.isSubmitting)
                }
            }
        }
    }

    // MARK: - Ticket Info

    private var ticketInfoSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            HStack {
                Image(systemName: "ladybug.fill")
                    .foregroundColor(AppTheme.accentRed)
                Text("Bug Report für \(self.ticket.ticketNumber)")
                    .font(ResponsiveDesign.headlineFont())
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.fontColor)
            }
            Text(self.ticket.subject)
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    // MARK: - Severity Section

    private var severitySection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            Text("Schweregrad")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.fontColor)

            ForEach(BugSeverity.allCases, id: \.self) { sev in
                SeverityButton(
                    severity: sev,
                    isSelected: self.severity == sev
                ) {
                    self.severity = sev
                }
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    // MARK: - Bug Description

    private var bugDescriptionSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            Text("Bug-Beschreibung")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.fontColor)

            TextEditor(text: self.$description)
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor)
                .frame(minHeight: 80)
                .padding(ResponsiveDesign.spacing(8))
                .background(AppTheme.screenBackground)
                .cornerRadius(ResponsiveDesign.spacing(8))

            CSInputField(
                label: "JIRA Ticket ID (optional)",
                placeholder: "z.B. FIN-1234",
                text: self.$jiraTicketId
            )
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    // MARK: - Reproduction Steps

    private var reproductionStepsSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            Text("Schritte zur Reproduktion")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.fontColor)

            ForEach(self.stepsToReproduce.indices, id: \.self) { index in
                HStack {
                    Text("\(index + 1).")
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.7))
                        .frame(width: 25)

                    TextField("Schritt beschreiben...", text: self.$stepsToReproduce[index])
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(AppTheme.fontColor)
                        .padding(ResponsiveDesign.spacing(8))
                        .background(AppTheme.screenBackground)
                        .cornerRadius(ResponsiveDesign.spacing(6))

                    if self.stepsToReproduce.count > 1 {
                        Button {
                            self.stepsToReproduce.remove(at: index)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(AppTheme.accentRed)
                        }
                    }
                }
            }

            Button {
                self.stepsToReproduce.append("")
            } label: {
                Label("Schritt hinzufügen", systemImage: "plus.circle.fill")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.accentLightBlue)
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    // MARK: - Behavior Section

    private var behaviorSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            Text("Verhalten")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.fontColor)

            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
                Text("Erwartetes Verhalten")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.7))

                TextEditor(text: self.$expectedBehavior)
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor)
                    .frame(minHeight: 60)
                    .padding(ResponsiveDesign.spacing(8))
                    .background(AppTheme.screenBackground)
                    .cornerRadius(ResponsiveDesign.spacing(8))
            }

            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
                Text("Tatsächliches Verhalten")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.7))

                TextEditor(text: self.$actualBehavior)
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor)
                    .frame(minHeight: 60)
                    .padding(ResponsiveDesign.spacing(8))
                    .background(AppTheme.screenBackground)
                    .cornerRadius(ResponsiveDesign.spacing(8))
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    // MARK: - Impact Section

    private var impactSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            Text("Auswirkung")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.fontColor)

            HStack {
                Text("Betroffene Kunden:")
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor)

                Stepper("\(self.affectedCustomers)", value: self.$affectedCustomers, in: 1...1_000)
                    .foregroundColor(AppTheme.fontColor)
            }
            .padding()
            .background(AppTheme.screenBackground)
            .cornerRadius(ResponsiveDesign.spacing(8))
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    // MARK: - Workaround Section

    private var workaroundSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            Text("Workaround")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.fontColor)

            Toggle("Workaround verfügbar", isOn: self.$workaroundProvided)
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor)
                .tint(AppTheme.accentGreen)

            if self.workaroundProvided {
                VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
                    Text("Workaround-Beschreibung")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.7))

                    TextEditor(text: self.$workaroundDescription)
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(AppTheme.fontColor)
                        .frame(minHeight: 60)
                        .padding(ResponsiveDesign.spacing(8))
                        .background(AppTheme.screenBackground)
                        .cornerRadius(ResponsiveDesign.spacing(8))
                }
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    // MARK: - Team Section

    private var teamSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            Text("Zuständiges Team")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.fontColor)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: ResponsiveDesign.spacing(8)) {
                ForEach(self.devTeams, id: \.self) { team in
                    Button {
                        self.selectedDevTeam = team
                    } label: {
                        Text(team)
                            .font(ResponsiveDesign.captionFont())
                            .fontWeight(.medium)
                            .foregroundColor(self.selectedDevTeam == team ? .white : AppTheme.fontColor)
                            .padding(.horizontal, ResponsiveDesign.spacing(12))
                            .padding(.vertical, ResponsiveDesign.spacing(8))
                            .frame(maxWidth: .infinity)
                            .background(self.selectedDevTeam == team ? AppTheme.accentLightBlue : AppTheme.screenBackground)
                            .cornerRadius(ResponsiveDesign.spacing(8))
                    }
                }
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    // MARK: - Helpers

    private var isFormValid: Bool {
        !self.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !self.expectedBehavior.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !self.actualBehavior.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            self.stepsToReproduce.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private func submitEscalation() async {
        self.isSubmitting = true
        defer { isSubmitting = false }

        let escalation = DevEscalation(
            jiraTicketId: jiraTicketId.isEmpty ? nil : self.jiraTicketId,
            severity: self.severity,
            description: self.description,
            stepsToReproduce: self.stepsToReproduce.filter { !$0.isEmpty },
            expectedBehavior: self.expectedBehavior,
            actualBehavior: self.actualBehavior,
            affectedCustomers: self.affectedCustomers,
            workaroundProvided: self.workaroundProvided,
            escalatedAt: Date(),
            devTeam: self.selectedDevTeam
        )

        await self.viewModel.escalateToDevTeam(ticketId: self.ticket.id, escalation: escalation)
        self.dismiss()
    }
}

// MARK: - Severity Button

struct SeverityButton: View {
    let severity: BugSeverity
    let isSelected: Bool
    let action: () -> Void

    private var severityColor: Color {
        switch self.severity {
        case .critical: return AppTheme.accentRed
        case .high: return AppTheme.accentOrange
        case .medium: return Color.yellow
        case .low: return AppTheme.accentGreen
        }
    }

    private var severityDescription: String {
        switch self.severity {
        case .critical: return "System nicht nutzbar, kein Workaround"
        case .high: return "Hauptfunktion betroffen, Workaround möglich"
        case .medium: return "Funktion teilweise betroffen"
        case .low: return "Kleines Problem, kosmetisch"
        }
    }

    var body: some View {
        Button(action: self.action) {
            HStack(spacing: ResponsiveDesign.spacing(12)) {
                Circle()
                    .fill(self.severityColor)
                    .frame(width: 12, height: 12)

                VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(2)) {
                    Text(self.severity.displayName)
                        .font(ResponsiveDesign.bodyFont())
                        .fontWeight(.medium)
                        .foregroundColor(self.isSelected ? .white : AppTheme.fontColor)

                    Text(self.severityDescription)
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(self.isSelected ? .white.opacity(0.8) : AppTheme.fontColor.opacity(0.7))
                }

                Spacer()

                if self.isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                }
            }
            .padding()
            .background(self.isSelected ? self.severityColor : AppTheme.screenBackground)
            .cornerRadius(ResponsiveDesign.spacing(10))
        }
    }
}

