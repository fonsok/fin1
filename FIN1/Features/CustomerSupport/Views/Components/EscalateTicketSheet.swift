import SwiftUI

// MARK: - Escalate Ticket Sheet
/// Sheet for escalating a support ticket to a higher priority or supervisor

struct EscalateTicketSheet: View {
    let ticket: SupportTicket
    @ObservedObject var viewModel: CustomerSupportDashboardViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var reason: String = ""
    @State private var selectedPriority: SupportTicket.TicketPriority

    init(ticket: SupportTicket, viewModel: CustomerSupportDashboardViewModel) {
        self.ticket = ticket
        self.viewModel = viewModel
        _selectedPriority = State(initialValue: ticket.priority)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ResponsiveDesign.spacing(20)) {
                    headerSection
                    ticketInfoSection
                    prioritySection
                    reasonSection
                    submitButton
                }
                .padding()
            }
            .background(AppTheme.screenBackground.ignoresSafeArea())
            .navigationTitle("Ticket eskalieren")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") {
                        viewModel.closeEscalateTicketSheet()
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(ResponsiveDesign.titleFont())
                    .foregroundColor(AppTheme.accentOrange)

                Text("Ticket eskalieren")
                    .font(ResponsiveDesign.titleFont())
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.fontColor)
            }

            Text("Eskalieren Sie dieses Ticket an einen Vorgesetzten oder erhöhen Sie die Priorität.")
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Ticket Info Section

    private var ticketInfoSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            Text("Ticket-Informationen")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.fontColor)

            VStack(spacing: ResponsiveDesign.spacing(8)) {
                CSInfoRow(label: "Ticket-Nummer", value: ticket.ticketNumber)
                CSInfoRow(label: "Betreff", value: ticket.subject)
                CSInfoRow(label: "Kunde", value: ticket.customerName)
                CSInfoRow(label: "Aktuelle Priorität", value: ticket.priority.displayName)
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    // MARK: - Priority Section

    private var prioritySection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            Text("Neue Priorität")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.fontColor)

            VStack(spacing: ResponsiveDesign.spacing(8)) {
                ForEach([SupportTicket.TicketPriority.medium, .high, .urgent], id: \.self) { priority in
                    PriorityOption(
                        priority: priority,
                        isSelected: selectedPriority == priority
                    ) {
                        selectedPriority = priority
                    }
                }
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    // MARK: - Reason Section

    private var reasonSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            HStack {
                Text("Eskalationsgrund")
                    .font(ResponsiveDesign.bodyFont())
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.fontColor)

                Spacer()

                Text("\(reason.count)/500")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(reason.count > 450 ? AppTheme.accentOrange : AppTheme.fontColor.opacity(0.5))
            }

            TextEditor(text: $reason)
                .frame(minHeight: 100)
                .padding(ResponsiveDesign.spacing(12))
                .background(AppTheme.inputFieldBackground)
                .cornerRadius(ResponsiveDesign.spacing(10))
                .foregroundColor(AppTheme.inputFieldText)
                .scrollContentBackground(.hidden)
                .onChange(of: reason) { _, newValue in
                    if newValue.count > 500 {
                        reason = String(newValue.prefix(500))
                    }
                }

            if reason.count < 10 && !reason.isEmpty {
                Text("Bitte geben Sie mehr Details an (mindestens 10 Zeichen)")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.accentOrange)
            }
        }
    }

    // MARK: - Submit Button

    private var submitButton: some View {
        Button(action: {
            Task {
                await submitEscalation()
            }
        }) {
            HStack {
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(AppTheme.screenBackground)
                } else {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize() * 0.8))
                }

                Text("Eskalieren")
                    .font(ResponsiveDesign.headlineFont())
                    .fontWeight(.semibold)
            }
            .foregroundColor(AppTheme.screenBackground)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(isFormValid ? AppTheme.accentOrange : AppTheme.accentOrange.opacity(0.5))
            .cornerRadius(ResponsiveDesign.spacing(12))
        }
        .disabled(!isFormValid || viewModel.isLoading)
    }

    // MARK: - Computed Properties

    private var isFormValid: Bool {
        !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        reason.count >= 10
    }

    // MARK: - Private Methods

    private func submitEscalation() async {
        guard isFormValid else { return }

        await viewModel.escalateTicket(
            ticket.id,
            reason: reason.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        if !viewModel.showError {
            dismiss()
        }
    }
}

// MARK: - Priority Option

private struct PriorityOption: View {
    let priority: SupportTicket.TicketPriority
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? priorityColor : AppTheme.fontColor.opacity(0.5))

                Text(priority.displayName)
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor)

                Spacer()

                Circle()
                    .fill(priorityColor)
                    .frame(width: 12, height: 12)
            }
            .padding()
            .background(isSelected ? priorityColor.opacity(0.1) : AppTheme.systemTertiaryBackground)
            .cornerRadius(ResponsiveDesign.spacing(10))
        }
    }

    private var priorityColor: Color {
        switch priority {
        case .low: return AppTheme.accentLightBlue
        case .medium: return AppTheme.accentOrange
        case .high: return AppTheme.accentRed
        case .urgent: return AppTheme.accentRed
        }
    }
}

// MARK: - Preview

#Preview {
    CustomerSupportDashboardView()
        .environment(\.appServices, .live)
}
