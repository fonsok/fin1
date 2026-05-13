import SwiftUI

// MARK: - Resolve Ticket Sheet
/// Sheet for CSR to resolve or close a ticket

struct ResolveTicketSheet: View {
    let ticket: SupportTicket
    @ObservedObject var viewModel: CustomerSupportDashboardViewModel
    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @State private var selectedAction: TicketCloseAction = .resolve
    @State private var resolutionNote = ""
    @State private var customerConfirmed = false
    @State private var closureReason: ClosureReason = .resolved
    @State private var customClosureReason = ""
    @State private var isSubmitting = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ResponsiveDesign.spacing(16)) {
                    self.ticketInfoSection
                    self.actionTypeSection
                    self.detailsSection
                    if self.selectedAction == .resolve {
                        self.confirmationSection
                    }
                }
                .padding()
            }
            .background(AppTheme.screenBackground.ignoresSafeArea())
            .navigationTitle(self.selectedAction == .resolve ? "Ticket lösen" : "Ticket schließen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") { self.dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(self.selectedAction == .resolve ? "Lösen" : "Schließen") {
                        Task { await self.submitAction() }
                    }
                    .disabled(!self.isFormValid || self.isSubmitting)
                }
            }
        }
    }

    // MARK: - Ticket Info Section

    private var ticketInfoSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            HStack {
                Image(systemName: "ticket.fill")
                    .foregroundColor(self.ticketStatusColor)
                Text(self.ticket.ticketNumber)
                    .font(ResponsiveDesign.headlineFont())
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.fontColor)
                Spacer()
                CSStatusBadge(text: self.ticket.status.displayName, color: self.ticketStatusColor)
            }

            Text(self.ticket.subject)
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))

            HStack {
                Label(self.ticket.customerName, systemImage: "person.fill")
                Spacer()
                Label(self.ticket.createdAt.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
            }
            .font(ResponsiveDesign.captionFont())
            .foregroundColor(AppTheme.fontColor.opacity(0.7))

            // Show responses count
            if !self.ticket.responses.isEmpty {
                HStack {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                    Text("\(self.ticket.responses.count) Antworten")
                }
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    // MARK: - Action Type Section

    private var actionTypeSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            Text("Aktion wählen")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.fontColor)

            HStack(spacing: ResponsiveDesign.spacing(12)) {
                ActionTypeButton(
                    action: .resolve,
                    isSelected: self.selectedAction == .resolve
                ) {
                    self.selectedAction = .resolve
                }

                ActionTypeButton(
                    action: .close,
                    isSelected: self.selectedAction == .close
                ) {
                    self.selectedAction = .close
                }
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    // MARK: - Details Section

    @ViewBuilder
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            if self.selectedAction == .resolve {
                self.resolveDetailsSection
            } else {
                self.closeDetailsSection
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    private var resolveDetailsSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            Text("Abschlussmeldung")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.fontColor)

            Text("Diese Nachricht wird an den Kunden gesendet.")
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))

            TextEditor(text: self.$resolutionNote)
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor)
                .frame(minHeight: 100)
                .padding(ResponsiveDesign.spacing(8))
                .background(AppTheme.screenBackground)
                .cornerRadius(ResponsiveDesign.spacing(8))

            // Quick responses
            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
                Text("Schnellantworten:")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.7))

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: ResponsiveDesign.spacing(8)) {
                        QuickResponseChip(text: "Problem gelöst") {
                            self.resolutionNote = "Ihr Problem wurde erfolgreich gelöst. Vielen Dank für Ihre Geduld."
                        }
                        QuickResponseChip(text: "Wie besprochen") {
                            self.resolutionNote = "Wie telefonisch besprochen, wurde das Problem behoben. Bei weiteren Fragen stehen wir Ihnen gerne zur Verfügung."
                        }
                        QuickResponseChip(text: "Einstellung angepasst") {
                            self.resolutionNote = "Wir haben die erforderlichen Einstellungen in Ihrem Konto angepasst. Das Problem sollte nun behoben sein."
                        }
                    }
                }
            }
        }
    }

    private var closeDetailsSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            Text("Schließungsgrund")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.fontColor)

            ForEach(ClosureReason.allCases, id: \.self) { reason in
                ClosureReasonButton(
                    reason: reason,
                    isSelected: self.closureReason == reason
                ) {
                    self.closureReason = reason
                }
            }

            if self.closureReason == .other {
                CSInputField(
                    label: "Anderer Grund",
                    placeholder: "Grund eingeben...",
                    text: self.$customClosureReason
                )
            }
        }
    }

    // MARK: - Confirmation Section

    private var confirmationSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            Text("Kundenbestätigung")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.fontColor)

            Toggle(isOn: self.$customerConfirmed) {
                VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
                    Text("Kunde hat Lösung bestätigt")
                        .font(ResponsiveDesign.bodyFont())
                        .foregroundColor(AppTheme.fontColor)

                    Text("Der Kunde hat bestätigt, dass das Problem gelöst ist.")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.7))
                }
            }
            .tint(AppTheme.accentGreen)
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    // MARK: - Helpers

    private var ticketStatusColor: Color {
        switch self.ticket.status {
        case .open, .inProgress: return AppTheme.accentLightBlue
        case .waitingForCustomer: return AppTheme.accentOrange
        case .escalated: return AppTheme.accentRed
        case .resolved, .closed: return AppTheme.accentGreen
        case .archived: return AppTheme.fontColor.opacity(0.5)
        }
    }

    private var isFormValid: Bool {
        if self.selectedAction == .resolve {
            return !self.resolutionNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        } else {
            if self.closureReason == .other {
                return !self.customClosureReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            return true
        }
    }

    private func submitAction() async {
        self.isSubmitting = true
        defer { isSubmitting = false }

        if self.selectedAction == .resolve {
            await self.viewModel.resolveTicket(
                ticketId: self.ticket.id,
                resolutionNote: self.resolutionNote,
                customerConfirmed: self.customerConfirmed
            )
        } else {
            let reason = self.closureReason == .other ? self.customClosureReason : self.closureReason.displayName
            await self.viewModel.closeTicket(ticketId: self.ticket.id, closureReason: reason)
        }

        self.dismiss()
    }
}

// MARK: - Ticket Close Action

enum TicketCloseAction {
    case resolve
    case close

    var displayName: String {
        switch self {
        case .resolve: return "Lösen"
        case .close: return "Schließen"
        }
    }

    var icon: String {
        switch self {
        case .resolve: return "checkmark.seal.fill"
        case .close: return "xmark.circle.fill"
        }
    }

    var description: String {
        switch self {
        case .resolve: return "Problem wurde behoben"
        case .close: return "Ohne Lösung schließen"
        }
    }

    var color: Color {
        switch self {
        case .resolve: return AppTheme.accentGreen
        case .close: return AppTheme.accentOrange
        }
    }
}

// MARK: - Closure Reason

enum ClosureReason: String, CaseIterable {
    case resolved = "resolved"
    case duplicate = "duplicate"
    case noResponse = "no_response"
    case notReproducible = "not_reproducible"
    case outOfScope = "out_of_scope"
    case other = "other"

    var displayName: String {
        switch self {
        case .resolved: return "Gelöst"
        case .duplicate: return "Duplikat"
        case .noResponse: return "Keine Kundenantwort"
        case .notReproducible: return "Nicht reproduzierbar"
        case .outOfScope: return "Außerhalb des Supports"
        case .other: return "Anderer Grund"
        }
    }

    var icon: String {
        switch self {
        case .resolved: return "checkmark.circle.fill"
        case .duplicate: return "doc.on.doc.fill"
        case .noResponse: return "clock.fill"
        case .notReproducible: return "questionmark.circle.fill"
        case .outOfScope: return "xmark.shield.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }
}

// MARK: - Action Type Button

struct ActionTypeButton: View {
    let action: TicketCloseAction
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: self.onTap) {
            VStack(spacing: ResponsiveDesign.spacing(8)) {
                Image(systemName: self.action.icon)
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(self.isSelected ? .white : self.action.color)

                Text(self.action.displayName)
                    .font(ResponsiveDesign.bodyFont())
                    .fontWeight(.medium)
                    .foregroundColor(self.isSelected ? .white : AppTheme.fontColor)

                Text(self.action.description)
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(self.isSelected ? .white.opacity(0.8) : AppTheme.fontColor.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(self.isSelected ? self.action.color : AppTheme.screenBackground)
            .cornerRadius(ResponsiveDesign.spacing(12))
        }
    }
}

// MARK: - Closure Reason Button

struct ClosureReasonButton: View {
    let reason: ClosureReason
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: self.onTap) {
            HStack(spacing: ResponsiveDesign.spacing(12)) {
                Image(systemName: self.reason.icon)
                    .foregroundColor(self.isSelected ? .white : AppTheme.accentOrange)

                Text(self.reason.displayName)
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(self.isSelected ? .white : AppTheme.fontColor)

                Spacer()

                if self.isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                }
            }
            .padding()
            .background(self.isSelected ? AppTheme.accentOrange : AppTheme.screenBackground)
            .cornerRadius(ResponsiveDesign.spacing(8))
        }
    }
}

// MARK: - Quick Response Chip

struct QuickResponseChip: View {
    let text: String
    let action: () -> Void

    var body: some View {
        Button(action: self.action) {
            Text(self.text)
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.accentLightBlue)
                .padding(.horizontal, ResponsiveDesign.spacing(12))
                .padding(.vertical, ResponsiveDesign.spacing(6))
                .background(AppTheme.accentLightBlue.opacity(0.1))
                .cornerRadius(ResponsiveDesign.spacing(16))
        }
    }
}

