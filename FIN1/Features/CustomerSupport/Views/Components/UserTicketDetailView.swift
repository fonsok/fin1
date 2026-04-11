import SwiftUI

// MARK: - User Ticket Detail View
/// View for users (investors/traders) to view their own support tickets
/// Components extracted to UserTicketComponents.swift

struct UserTicketDetailView: View {
    let ticket: SupportTicket
    let userId: String
    let supportService: CustomerSupportServiceProtocol

    @Environment(\.dismiss) private var dismiss
    @State private var showNotSolvedSheet = false
    @State private var additionalInfo = ""
    @State private var isSubmitting = false
    @State private var showSuccess = false
    @State private var successMessage = ""
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ResponsiveDesign.spacing(16)) {
                    ticketHeader

                    if ticket.status == .waitingForCustomer {
                        confirmationSection
                    }

                    ticketInfoSection
                    ticketDescriptionSection

                    if !ticket.responses.isEmpty {
                        responsesSection
                    }
                }
                .padding()
            }
            .background(AppTheme.screenBackground.ignoresSafeArea())
            .navigationTitle("Ticket Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Schließen") { dismiss() }
                }
            }
            .alert("Erfolg", isPresented: $showSuccess) {
                Button("OK") { dismiss() }
            } message: {
                Text(successMessage)
            }
            .alert("Fehler", isPresented: $showError) {
                Button("OK") {}
            } message: {
                Text(errorMessage)
            }
            .sheet(isPresented: $showNotSolvedSheet) {
                ProblemNotSolvedSheet(
                    additionalInfo: $additionalInfo,
                    isSubmitting: isSubmitting,
                    onSubmit: { Task { await reportProblemNotSolved() } },
                    onCancel: { showNotSolvedSheet = false }
                )
            }
        }
    }

    // MARK: - Confirmation Section

    private var confirmationSection: some View {
        ConfirmationRequiredBanner()
    }

    // MARK: - Ticket Header

    private var ticketHeader: some View {
        VStack(spacing: ResponsiveDesign.spacing(12)) {
            HStack {
                Image(systemName: "ticket.fill")
                    .font(ResponsiveDesign.largeTitleFont())
                    .foregroundColor(TicketPriorityHelper.color(for: ticket.priority))

                VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
                    Text(ticket.subject)
                        .font(ResponsiveDesign.headlineFont())
                        .fontWeight(.bold)
                        .foregroundColor(AppTheme.fontColor)

                    Text("Ticket #\(ticket.id.prefix(8))")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.7))
                }

                Spacer()

                priorityBadge
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    private var priorityBadge: some View {
        Text(ticket.priority.displayName)
            .font(ResponsiveDesign.captionFont())
            .fontWeight(.semibold)
            .foregroundColor(TicketPriorityHelper.color(for: ticket.priority))
            .padding(.horizontal, ResponsiveDesign.spacing(12))
            .padding(.vertical, ResponsiveDesign.spacing(6))
            .background(TicketPriorityHelper.color(for: ticket.priority).opacity(0.1))
            .cornerRadius(ResponsiveDesign.spacing(8))
    }

    // MARK: - Ticket Info Section

    private var ticketInfoSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            Text("Ticket-Informationen")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.fontColor)

            VStack(spacing: ResponsiveDesign.spacing(8)) {
                UserTicketInfoRow(label: "Status", value: ticket.status.displayName)
                UserTicketInfoRow(label: "Priorität", value: ticket.priority.displayName)
                UserTicketInfoRow(label: "Erstellt", value: ticket.createdAt.formatted(date: .abbreviated, time: .shortened))
                UserTicketInfoRow(label: "Aktualisiert", value: ticket.updatedAt.formatted(date: .abbreviated, time: .shortened))
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    // MARK: - Ticket Description Section

    private var ticketDescriptionSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            Text("Beschreibung")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.fontColor)

            Text(ticket.description)
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.8))
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    // MARK: - Responses Section

    private var responsesSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            Text("Antworten (\(ticket.responses.count))")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.fontColor)

            VStack(spacing: ResponsiveDesign.spacing(12)) {
                ForEach(ticket.responses) { response in
                    UserTicketResponseCard(
                        response: response,
                        showConfirmationButtons: ticket.status == .waitingForCustomer,
                        isSubmitting: isSubmitting,
                        onConfirmSolved: { Task { await confirmProblemSolved() } },
                        onReportNotSolved: { showNotSolvedSheet = true }
                    )
                }
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    // MARK: - Actions

    @MainActor
    private func confirmProblemSolved() async {
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            try await supportService.userConfirmProblemSolved(ticketId: ticket.id, userId: userId)
            successMessage = "Vielen Dank für Ihre Bestätigung! Das Ticket wurde als gelöst markiert."
            showSuccess = true
        } catch {
            let appError = error.toAppError()
            errorMessage = appError.errorDescription ?? "An error occurred"
            showError = true
        }
    }

    @MainActor
    private func reportProblemNotSolved() async {
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            try await supportService.userReportProblemNotSolved(
                ticketId: ticket.id,
                userId: userId,
                additionalInfo: additionalInfo
            )
            showNotSolvedSheet = false
            successMessage = "Ihr Feedback wurde gesendet. Ein Mitarbeiter wird sich umgehend bei Ihnen melden."
            showSuccess = true
        } catch {
            let appError = error.toAppError()
            errorMessage = appError.errorDescription ?? "An error occurred"
            showError = true
        }
    }
}

// MARK: - Preview

#Preview {
    UserTicketDetailView(
        ticket: SupportTicket(
            id: "test-ticket",
            ticketNumber: "TKT-001",
            userId: "user:preview@test.com",
            customerName: "Test Customer",
            subject: "Test Ticket",
            description: "This is a test ticket",
            status: .waitingForCustomer,
            priority: .medium,
            assignedTo: nil,
            createdAt: Date(),
            updatedAt: Date(),
            responses: []
        ),
        userId: "user:test@test.com",
        supportService: AppServices.live.customerSupportService
    )
}
