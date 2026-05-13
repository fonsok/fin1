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
                    self.ticketHeader

                    if self.ticket.status == .waitingForCustomer {
                        self.confirmationSection
                    }

                    self.ticketInfoSection
                    self.ticketDescriptionSection

                    if !self.ticket.responses.isEmpty {
                        self.responsesSection
                    }
                }
                .padding()
            }
            .background(AppTheme.screenBackground.ignoresSafeArea())
            .navigationTitle("Ticket Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Schließen") { self.dismiss() }
                }
            }
            .alert("Erfolg", isPresented: self.$showSuccess) {
                Button("OK") { self.dismiss() }
            } message: {
                Text(self.successMessage)
            }
            .alert("Fehler", isPresented: self.$showError) {
                Button("OK") {}
            } message: {
                Text(self.errorMessage)
            }
            .sheet(isPresented: self.$showNotSolvedSheet) {
                ProblemNotSolvedSheet(
                    additionalInfo: self.$additionalInfo,
                    isSubmitting: self.isSubmitting,
                    onSubmit: { Task { await self.reportProblemNotSolved() } },
                    onCancel: { self.showNotSolvedSheet = false }
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
                    .foregroundColor(TicketPriorityHelper.color(for: self.ticket.priority))

                VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(4)) {
                    Text(self.ticket.subject)
                        .font(ResponsiveDesign.headlineFont())
                        .fontWeight(.bold)
                        .foregroundColor(AppTheme.fontColor)

                    Text("Ticket #\(self.ticket.id.prefix(8))")
                        .font(ResponsiveDesign.captionFont())
                        .foregroundColor(AppTheme.fontColor.opacity(0.7))
                }

                Spacer()

                self.priorityBadge
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    private var priorityBadge: some View {
        Text(self.ticket.priority.displayName)
            .font(ResponsiveDesign.captionFont())
            .fontWeight(.semibold)
            .foregroundColor(TicketPriorityHelper.color(for: self.ticket.priority))
            .padding(.horizontal, ResponsiveDesign.spacing(12))
            .padding(.vertical, ResponsiveDesign.spacing(6))
            .background(TicketPriorityHelper.color(for: self.ticket.priority).opacity(0.1))
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
                UserTicketInfoRow(label: "Status", value: self.ticket.status.displayName)
                UserTicketInfoRow(label: "Priorität", value: self.ticket.priority.displayName)
                UserTicketInfoRow(label: "Erstellt", value: self.ticket.createdAt.formatted(date: .abbreviated, time: .shortened))
                UserTicketInfoRow(label: "Aktualisiert", value: self.ticket.updatedAt.formatted(date: .abbreviated, time: .shortened))
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

            Text(self.ticket.description)
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
            Text("Antworten (\(self.ticket.responses.count))")
                .font(ResponsiveDesign.headlineFont())
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.fontColor)

            VStack(spacing: ResponsiveDesign.spacing(12)) {
                ForEach(self.ticket.responses) { response in
                    UserTicketResponseCard(
                        response: response,
                        showConfirmationButtons: self.ticket.status == .waitingForCustomer,
                        isSubmitting: self.isSubmitting,
                        onConfirmSolved: { Task { await self.confirmProblemSolved() } },
                        onReportNotSolved: { self.showNotSolvedSheet = true }
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
        self.isSubmitting = true
        defer { isSubmitting = false }

        do {
            try await self.supportService.userConfirmProblemSolved(ticketId: self.ticket.id, userId: self.userId)
            self.successMessage = "Vielen Dank für Ihre Bestätigung! Das Ticket wurde als gelöst markiert."
            self.showSuccess = true
        } catch {
            let appError = error.toAppError()
            self.errorMessage = appError.errorDescription ?? "An error occurred"
            self.showError = true
        }
    }

    @MainActor
    private func reportProblemNotSolved() async {
        self.isSubmitting = true
        defer { isSubmitting = false }

        do {
            try await self.supportService.userReportProblemNotSolved(
                ticketId: self.ticket.id,
                userId: self.userId,
                additionalInfo: self.additionalInfo
            )
            self.showNotSolvedSheet = false
            self.successMessage = "Ihr Feedback wurde gesendet. Ein Mitarbeiter wird sich umgehend bei Ihnen melden."
            self.showSuccess = true
        } catch {
            let appError = error.toAppError()
            self.errorMessage = appError.errorDescription ?? "An error occurred"
            self.showError = true
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
