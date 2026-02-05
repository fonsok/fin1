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
                    ticketInfoSection
                    solutionTypeSection
                    solutionDetailsSection
                    customerMessageSection
                    verificationStepsSection
                }
                .padding()
            }
            .background(AppTheme.screenBackground.ignoresSafeArea())
            .navigationTitle("Lösung hinzufügen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Senden") {
                        Task { await submitSolution() }
                    }
                    .disabled(!isFormValid || isSubmitting)
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
                Text(ticket.ticketNumber)
                    .font(ResponsiveDesign.headlineFont())
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.fontColor)
            }
            Text(ticket.subject)
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
                    isSelected: selectedSolutionType == type
                ) {
                    selectedSolutionType = type
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

            switch selectedSolutionType {
            case .helpCenterArticle:
                helpCenterFields
            case .configurationChange:
                configurationFields
            case .manualResolution:
                manualResolutionFields
            case .noActionRequired:
                noActionFields
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
                text: $helpCenterArticleId
            )
            CSInputField(
                label: "Artikeltitel",
                placeholder: "Name des Help Center Artikels",
                text: $helpCenterArticleTitle
            )
        }
    }

    private var configurationFields: some View {
        VStack(spacing: ResponsiveDesign.spacing(12)) {
            Text("Konfigurationsänderungen")
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))

            ForEach(configChanges) { change in
                ConfigChangeRow(change: change) {
                    configChanges.removeAll { $0.id == change.id }
                }
            }

            VStack(spacing: ResponsiveDesign.spacing(8)) {
                CSInputField(label: "Einstellung", placeholder: "Name der Einstellung", text: $newConfigSetting)
                HStack(spacing: ResponsiveDesign.spacing(8)) {
                    CSInputField(label: "Alter Wert", placeholder: "Optional", text: $newConfigOldValue)
                    CSInputField(label: "Neuer Wert", placeholder: "Erforderlich", text: $newConfigNewValue)
                }
                CSInputField(label: "Grund", placeholder: "Warum wurde die Änderung vorgenommen?", text: $newConfigReason)

                Button(action: addConfigChange) {
                    Label("Änderung hinzufügen", systemImage: "plus.circle.fill")
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(AppTheme.accentLightBlue)
                }
                .disabled(newConfigSetting.isEmpty || newConfigNewValue.isEmpty)
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
                text: $workaround
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

            TextEditor(text: $customerMessage)
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

            ForEach(verificationSteps.indices, id: \.self) { index in
                HStack {
                    Text("\(index + 1).")
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.7))
                        .frame(width: 25)

                    TextField("Schritt beschreiben...", text: $verificationSteps[index])
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(AppTheme.fontColor)
                        .padding(ResponsiveDesign.spacing(8))
                        .background(AppTheme.screenBackground)
                        .cornerRadius(ResponsiveDesign.spacing(6))

                    if verificationSteps.count > 1 {
                        Button {
                            verificationSteps.remove(at: index)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(AppTheme.accentRed)
                        }
                    }
                }
            }

            Button {
                verificationSteps.append("")
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
        !customerMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func addConfigChange() {
        let change = ConfigurationChange(
            settingName: newConfigSetting,
            previousValue: newConfigOldValue.isEmpty ? nil : newConfigOldValue,
            newValue: newConfigNewValue,
            reason: newConfigReason
        )
        configChanges.append(change)
        newConfigSetting = ""
        newConfigOldValue = ""
        newConfigNewValue = ""
        newConfigReason = ""
    }

    private func submitSolution() async {
        isSubmitting = true
        defer { isSubmitting = false }

        let solution = SolutionDetails(
            solutionType: selectedSolutionType,
            helpCenterArticleId: helpCenterArticleId.isEmpty ? nil : helpCenterArticleId,
            helpCenterArticleTitle: helpCenterArticleTitle.isEmpty ? nil : helpCenterArticleTitle,
            configurationChanges: configChanges.isEmpty ? nil : configChanges,
            workaround: workaround.isEmpty ? nil : workaround,
            verificationSteps: verificationSteps.filter { !$0.isEmpty }
        )

        await viewModel.addSolution(
            ticketId: ticket.id,
            solution: solution,
            customerMessage: customerMessage
        )

        dismiss()
    }
}

// MARK: - Solution Type Button

struct SolutionTypeButton: View {
    let type: SolutionType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: ResponsiveDesign.spacing(12)) {
                Image(systemName: type.icon)
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(isSelected ? .white : AppTheme.accentLightBlue)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(2)) {
                    Text(type.displayName)
                        .font(ResponsiveDesign.bodyFont())
                        .fontWeight(.medium)
                        .foregroundColor(isSelected ? .white : AppTheme.fontColor)

                    Text(type.description)
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(isSelected ? .white.opacity(0.8) : AppTheme.fontColor.opacity(0.7))
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                }
            }
            .padding()
            .background(isSelected ? AppTheme.accentLightBlue : AppTheme.screenBackground)
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
                Text(change.settingName)
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
                    Text(change.newValue)
                        .foregroundColor(AppTheme.accentGreen)
                }
                .font(ResponsiveDesign.captionFont())
            }

            Spacer()

            Button(action: onDelete) {
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
            Text(label)
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))

            TextField(placeholder, text: $text)
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor)
                .padding(ResponsiveDesign.spacing(10))
                .background(AppTheme.screenBackground)
                .cornerRadius(ResponsiveDesign.spacing(8))
        }
    }
}

