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
                    ticketInfoSection
                    actionTypeSection
                    detailsSection
                    if selectedAction == .resolve {
                        confirmationSection
                    }
                }
                .padding()
            }
            .background(AppTheme.screenBackground.ignoresSafeArea())
            .navigationTitle(selectedAction == .resolve ? "Ticket lösen" : "Ticket schließen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(selectedAction == .resolve ? "Lösen" : "Schließen") {
                        Task { await submitAction() }
                    }
                    .disabled(!isFormValid || isSubmitting)
                }
            }
        }
    }

    // MARK: - Ticket Info Section

    private var ticketInfoSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            HStack {
                Image(systemName: "ticket.fill")
                    .foregroundColor(ticketStatusColor)
                Text(ticket.ticketNumber)
                    .font(ResponsiveDesign.headlineFont())
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.fontColor)
                Spacer()
                CSStatusBadge(text: ticket.status.displayName, color: ticketStatusColor)
            }

            Text(ticket.subject)
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))

            HStack {
                Label(ticket.customerName, systemImage: "person.fill")
                Spacer()
                Label(ticket.createdAt.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
            }
            .font(ResponsiveDesign.captionFont())
            .foregroundColor(AppTheme.fontColor.opacity(0.7))

            // Show responses count
            if !ticket.responses.isEmpty {
                HStack {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                    Text("\(ticket.responses.count) Antworten")
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
                    isSelected: selectedAction == .resolve
                ) {
                    selectedAction = .resolve
                }

                ActionTypeButton(
                    action: .close,
                    isSelected: selectedAction == .close
                ) {
                    selectedAction = .close
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
            if selectedAction == .resolve {
                resolveDetailsSection
            } else {
                closeDetailsSection
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

            TextEditor(text: $resolutionNote)
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
                            resolutionNote = "Ihr Problem wurde erfolgreich gelöst. Vielen Dank für Ihre Geduld."
                        }
                        QuickResponseChip(text: "Wie besprochen") {
                            resolutionNote = "Wie telefonisch besprochen, wurde das Problem behoben. Bei weiteren Fragen stehen wir Ihnen gerne zur Verfügung."
                        }
                        QuickResponseChip(text: "Einstellung angepasst") {
                            resolutionNote = "Wir haben die erforderlichen Einstellungen in Ihrem Konto angepasst. Das Problem sollte nun behoben sein."
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
                    isSelected: closureReason == reason
                ) {
                    closureReason = reason
                }
            }

            if closureReason == .other {
                CSInputField(
                    label: "Anderer Grund",
                    placeholder: "Grund eingeben...",
                    text: $customClosureReason
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

            Toggle(isOn: $customerConfirmed) {
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
        switch ticket.status {
        case .open, .inProgress: return AppTheme.accentLightBlue
        case .waitingForCustomer: return AppTheme.accentOrange
        case .escalated: return AppTheme.accentRed
        case .resolved, .closed: return AppTheme.accentGreen
        case .archived: return AppTheme.fontColor.opacity(0.5)
        }
    }

    private var isFormValid: Bool {
        if selectedAction == .resolve {
            return !resolutionNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        } else {
            if closureReason == .other {
                return !customClosureReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            return true
        }
    }

    private func submitAction() async {
        isSubmitting = true
        defer { isSubmitting = false }

        if selectedAction == .resolve {
            await viewModel.resolveTicket(
                ticketId: ticket.id,
                resolutionNote: resolutionNote,
                customerConfirmed: customerConfirmed
            )
        } else {
            let reason = closureReason == .other ? customClosureReason : closureReason.displayName
            await viewModel.closeTicket(ticketId: ticket.id, closureReason: reason)
        }

        dismiss()
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
        Button(action: onTap) {
            VStack(spacing: ResponsiveDesign.spacing(8)) {
                Image(systemName: action.icon)
                    .font(ResponsiveDesign.headlineFont())
                    .foregroundColor(isSelected ? .white : action.color)

                Text(action.displayName)
                    .font(ResponsiveDesign.bodyFont())
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : AppTheme.fontColor)

                Text(action.description)
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(isSelected ? .white.opacity(0.8) : AppTheme.fontColor.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(isSelected ? action.color : AppTheme.screenBackground)
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
        Button(action: onTap) {
            HStack(spacing: ResponsiveDesign.spacing(12)) {
                Image(systemName: reason.icon)
                    .foregroundColor(isSelected ? .white : AppTheme.accentOrange)

                Text(reason.displayName)
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(isSelected ? .white : AppTheme.fontColor)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                }
            }
            .padding()
            .background(isSelected ? AppTheme.accentOrange : AppTheme.screenBackground)
            .cornerRadius(ResponsiveDesign.spacing(8))
        }
    }
}

// MARK: - Quick Response Chip

struct QuickResponseChip: View {
    let text: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(ResponsiveDesign.captionFont())
                .foregroundColor(AppTheme.accentLightBlue)
                .padding(.horizontal, ResponsiveDesign.spacing(12))
                .padding(.vertical, ResponsiveDesign.spacing(6))
                .background(AppTheme.accentLightBlue.opacity(0.1))
                .cornerRadius(ResponsiveDesign.spacing(16))
        }
    }
}

