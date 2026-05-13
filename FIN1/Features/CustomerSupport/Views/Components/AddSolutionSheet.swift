import SwiftUI

// MARK: - Add Solution Sheet
/// Sheet for CSR to add a solution to a ticket
/// Supports: Help Center article, Configuration change, Manual resolution

struct AddSolutionSheet: View {
    let ticket: SupportTicket
    @ObservedObject var viewModel: CustomerSupportDashboardViewModel
    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @State private var selectedSolutionType: SolutionType = .helpCenterArticle
    @State private var customerMessage = ""
    @State private var helpCenterArticleId = ""
    @State private var helpCenterArticleTitle = ""
    @State private var configChanges: [ConfigurationChange] = []
    @State private var newConfigSetting = ""
    @State private var newConfigOldValue = ""
    @State private var newConfigNewValue = ""
    @State private var newConfigReason = ""
    @State private var workaround = ""
    @State private var verificationSteps: [String] = [""]
    @State private var isSubmitting = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ResponsiveDesign.spacing(16)) {
                    self.ticketInfoSection
                    self.solutionTypeSection
                    self.solutionDetailsSection
                    self.customerMessageSection
                    self.verificationStepsSection
                }
                .padding()
            }
            .background(AppTheme.screenBackground.ignoresSafeArea())
            .navigationTitle("Lösung hinzufügen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") { self.dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Senden") {
                        Task { await self.submitSolution() }
                    }
                    .disabled(!self.isFormValid || self.isSubmitting)
                }
            }
        }
    }

    // MARK: - Ticket Info Section

    private var ticketInfoSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            HStack {
                Image(systemName: "ticket.fill")
                    .foregroundColor(AppTheme.accentLightBlue)
                Text(self.ticket.ticketNumber)
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

    // MARK: - Solution Type Section

    private var solutionTypeSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            Text("Lösungsart")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.fontColor)

            ForEach([SolutionType.helpCenterArticle, .configurationChange, .manualResolution, .noActionRequired], id: \.self) { type in
                SolutionTypeButton(
                    type: type,
                    isSelected: self.selectedSolutionType == type
                ) {
                    self.selectedSolutionType = type
                }
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    // MARK: - Solution Details Section

    @ViewBuilder
    private var solutionDetailsSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            Text("Lösungsdetails")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.fontColor)

            switch self.selectedSolutionType {
            case .helpCenterArticle:
                self.helpCenterFields
            case .configurationChange:
                self.configurationFields
            case .manualResolution:
                self.manualResolutionFields
            case .noActionRequired:
                self.noActionFields
            case .devEscalation:
                EmptyView() // Handled in separate sheet
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    private var helpCenterFields: some View {
        VStack(spacing: ResponsiveDesign.spacing(12)) {
            CSInputField(
                label: "Artikel-ID",
                placeholder: "z.B. HC-001",
                text: self.$helpCenterArticleId
            )
            CSInputField(
                label: "Artikeltitel",
                placeholder: "Name des Help Center Artikels",
                text: self.$helpCenterArticleTitle
            )
        }
    }

    private var configurationFields: some View {
        VStack(spacing: ResponsiveDesign.spacing(12)) {
            Text("Konfigurationsänderungen")
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))

            ForEach(self.configChanges) { change in
                ConfigChangeRow(change: change) {
                    self.configChanges.removeAll { $0.id == change.id }
                }
            }

            VStack(spacing: ResponsiveDesign.spacing(8)) {
                CSInputField(label: "Einstellung", placeholder: "Name der Einstellung", text: self.$newConfigSetting)
                HStack(spacing: ResponsiveDesign.spacing(8)) {
                    CSInputField(label: "Alter Wert", placeholder: "Optional", text: self.$newConfigOldValue)
                    CSInputField(label: "Neuer Wert", placeholder: "Erforderlich", text: self.$newConfigNewValue)
                }
                CSInputField(label: "Grund", placeholder: "Warum wurde die Änderung vorgenommen?", text: self.$newConfigReason)

                Button(action: self.addConfigChange) {
                    Label("Änderung hinzufügen", systemImage: "plus.circle.fill")
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(AppTheme.accentLightBlue)
                }
                .disabled(self.newConfigSetting.isEmpty || self.newConfigNewValue.isEmpty)
            }
            .padding()
            .background(AppTheme.screenBackground)
            .cornerRadius(ResponsiveDesign.spacing(8))
        }
    }

    private var manualResolutionFields: some View {
        VStack(spacing: ResponsiveDesign.spacing(12)) {
            Text("Beschreiben Sie, wie das Problem manuell gelöst wurde.")
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))

            CSInputField(
                label: "Workaround (optional)",
                placeholder: "Falls ein Workaround bereitgestellt wurde...",
                text: self.$workaround
            )
        }
    }

    private var noActionFields: some View {
        Text("Das Problem hat sich von selbst gelöst oder war nicht reproduzierbar.")
            .font(ResponsiveDesign.bodyFont())
            .foregroundColor(AppTheme.fontColor.opacity(0.7))
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.screenBackground)
            .cornerRadius(ResponsiveDesign.spacing(8))
    }

    // MARK: - Customer Message Section

    private var customerMessageSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            Text("Nachricht an Kunden")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.fontColor)

            Text("Erklären Sie die Lösung so einfach und klar wie möglich.")
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))

            TextEditor(text: self.$customerMessage)
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor)
                .frame(minHeight: 120)
                .padding(ResponsiveDesign.spacing(8))
                .background(AppTheme.screenBackground)
                .cornerRadius(ResponsiveDesign.spacing(8))
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    // MARK: - Verification Steps Section

    private var verificationStepsSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            Text("Überprüfungsschritte (optional)")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.fontColor)

            Text("Schritte, die der Kunde ausführen kann, um zu bestätigen, dass das Problem gelöst ist.")
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))

            ForEach(self.verificationSteps.indices, id: \.self) { index in
                HStack {
                    Text("\(index + 1).")
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.7))
                        .frame(width: 25)

                    TextField("Schritt beschreiben...", text: self.$verificationSteps[index])
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(AppTheme.fontColor)
                        .padding(ResponsiveDesign.spacing(8))
                        .background(AppTheme.screenBackground)
                        .cornerRadius(ResponsiveDesign.spacing(6))

                    if self.verificationSteps.count > 1 {
                        Button {
                            self.verificationSteps.remove(at: index)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(AppTheme.accentRed)
                        }
                    }
                }
            }

            Button {
                self.verificationSteps.append("")
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

    // MARK: - Helpers

    private var isFormValid: Bool {
        !self.customerMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func addConfigChange() {
        let change = ConfigurationChange(
            settingName: newConfigSetting,
            previousValue: newConfigOldValue.isEmpty ? nil : self.newConfigOldValue,
            newValue: self.newConfigNewValue,
            reason: self.newConfigReason
        )
        self.configChanges.append(change)
        self.newConfigSetting = ""
        self.newConfigOldValue = ""
        self.newConfigNewValue = ""
        self.newConfigReason = ""
    }

    private func submitSolution() async {
        self.isSubmitting = true
        defer { isSubmitting = false }

        let solution = SolutionDetails(
            solutionType: selectedSolutionType,
            helpCenterArticleId: helpCenterArticleId.isEmpty ? nil : self.helpCenterArticleId,
            helpCenterArticleTitle: self.helpCenterArticleTitle.isEmpty ? nil : self.helpCenterArticleTitle,
            configurationChanges: self.configChanges.isEmpty ? nil : self.configChanges,
            workaround: self.workaround.isEmpty ? nil : self.workaround,
            verificationSteps: self.verificationSteps.filter { !$0.isEmpty }
        )

        await self.viewModel.addSolution(
            ticketId: self.ticket.id,
            solution: solution,
            customerMessage: self.customerMessage
        )

        self.dismiss()
    }
}

// MARK: - Solution Type Button

struct SolutionTypeButton: View {
    let type: SolutionType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: self.action) {
            HStack(spacing: ResponsiveDesign.spacing(12)) {
                Image(systemName: self.type.icon)
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(self.isSelected ? .white : AppTheme.accentLightBlue)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(2)) {
                    Text(self.type.displayName)
                        .font(ResponsiveDesign.bodyFont())
                        .fontWeight(.medium)
                        .foregroundColor(self.isSelected ? .white : AppTheme.fontColor)

                    Text(self.type.description)
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
            .background(self.isSelected ? AppTheme.accentLightBlue : AppTheme.screenBackground)
            .cornerRadius(ResponsiveDesign.spacing(10))
        }
    }
}

// MARK: - Config Change Row

struct ConfigChangeRow: View {
    let change: ConfigurationChange
    let onDelete: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
                Text(self.change.settingName)
                    .font(ResponsiveDesign.bodyFont())
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.fontColor)

                HStack {
                    if let oldValue = change.previousValue {
                        Text(oldValue)
                            .strikethrough()
                            .foregroundColor(AppTheme.accentRed)
                    }
                    Image(systemName: "arrow.right")
                        .foregroundColor(AppTheme.fontColor.opacity(0.5))
                    Text(self.change.newValue)
                        .foregroundColor(AppTheme.accentGreen)
                }
                .font(ResponsiveDesign.captionFont())
            }

            Spacer()

            Button(action: self.onDelete) {
                Image(systemName: "trash.fill")
                    .foregroundColor(AppTheme.accentRed)
            }
        }
        .padding()
        .background(AppTheme.screenBackground)
        .cornerRadius(ResponsiveDesign.spacing(8))
    }
}

// MARK: - CS Input Field Helper

struct CSInputField: View {
    let label: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
            Text(self.label)
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))

            TextField(self.placeholder, text: self.$text)
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor)
                .padding(ResponsiveDesign.spacing(10))
                .background(AppTheme.screenBackground)
                .cornerRadius(ResponsiveDesign.spacing(8))
        }
    }
}

