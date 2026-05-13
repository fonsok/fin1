import SwiftUI

// MARK: - Respond Ticket Sheet
/// Sheet for responding to a support ticket
/// Allows adding public responses or internal notes

struct RespondTicketSheet: View {
    let ticket: SupportTicket
    @ObservedObject var viewModel: CustomerSupportDashboardViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var message: String = ""
    @State private var isInternal: Bool = false
    @State private var requestConfirmation: Bool = false
    @State private var showCannedResponses: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ResponsiveDesign.spacing(20)) {
                    self.headerSection
                    self.ticketInfoSection
                    self.messageSection
                    self.internalNoteToggle
                    if !self.isInternal {
                        self.confirmationRequestToggle
                    }
                    self.submitButton
                }
                .padding()
            }
            .background(AppTheme.screenBackground.ignoresSafeArea())
            .navigationTitle("Antworten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") {
                        self.viewModel.closeRespondTicketSheet()
                        self.dismiss()
                    }
                }
            }
            .sheet(isPresented: self.$showCannedResponses) {
                CannedResponsePicker(
                    selectedResponse: .constant(nil),
                    placeholderValues: self.placeholderValues
                ) { content in
                    if self.message.isEmpty {
                        self.message = content
                    } else {
                        self.message += "\n\n" + content
                    }
                }
            }
        }
    }

    // MARK: - Placeholder Values for Canned Responses

    private var placeholderValues: [String: String] {
        [
            "customerName": self.ticket.customerName,
            "ticketNumber": self.ticket.ticketNumber,
            "agentName": self.viewModel.getAgentName(for: self.ticket.assignedTo ?? "")
        ]
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            HStack {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(ResponsiveDesign.titleFont())
                    .foregroundColor(AppTheme.accentLightBlue)

                Text(self.isInternal ? "Interne Notiz hinzufügen" : "Antwort senden")
                    .font(ResponsiveDesign.titleFont())
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.fontColor)
            }

            Text(
                self.isInternal ? "Fügen Sie eine interne Notiz hinzu, die nur für Mitarbeiter sichtbar ist." : "Senden Sie eine Antwort an den Kunden zu diesem Ticket."
            )
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
                CSInfoRow(label: "Ticket-Nummer", value: self.ticket.ticketNumber)
                CSInfoRow(label: "Betreff", value: self.ticket.subject)
                CSInfoRow(label: "Kunde", value: self.ticket.customerName)
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }

    // MARK: - Message Section

    private var messageSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            HStack {
                Text(self.isInternal ? "Notiz" : "Antwort")
                    .font(ResponsiveDesign.bodyFont())
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.fontColor)

                Spacer()

                // Canned Responses Button
                Button {
                    self.showCannedResponses = true
                } label: {
                    HStack(spacing: ResponsiveDesign.spacing(4)) {
                        Image(systemName: "doc.text.fill")
                        Text("Textbausteine")
                    }
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.accentLightBlue)
                    .padding(.horizontal, ResponsiveDesign.spacing(10))
                    .padding(.vertical, ResponsiveDesign.spacing(6))
                    .background(AppTheme.accentLightBlue.opacity(0.1))
                    .cornerRadius(ResponsiveDesign.spacing(8))
                }

                Text("\(self.message.count)/1000")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(self.message.count > 900 ? AppTheme.accentOrange : AppTheme.fontColor.opacity(0.5))
            }

            TextEditor(text: self.$message)
                .frame(minHeight: 120)
                .padding(ResponsiveDesign.spacing(12))
                .background(AppTheme.inputFieldBackground)
                .cornerRadius(ResponsiveDesign.spacing(10))
                .foregroundColor(AppTheme.inputFieldText)
                .scrollContentBackground(.hidden)
                .onChange(of: self.message) { _, newValue in
                    if newValue.count > 1_000 {
                        self.message = String(newValue.prefix(1_000))
                    }
                }

            if self.message.count < 10 && !self.message.isEmpty {
                Text("Bitte geben Sie mehr Details an (mindestens 10 Zeichen)")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.accentOrange)
            }
        }
    }

    // MARK: - Internal Note Toggle

    private var internalNoteToggle: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            HStack {
                Image(systemName: self.isInternal ? "eye.slash.fill" : "eye.fill")
                    .foregroundColor(self.isInternal ? AppTheme.accentOrange : AppTheme.accentLightBlue)

                Text("Interne Notiz")
                    .font(ResponsiveDesign.bodyFont())
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.fontColor)

                Spacer()

                Toggle("", isOn: self.$isInternal)
                    .labelsHidden()
            }
            .padding()
            .background(AppTheme.sectionBackground)
            .cornerRadius(ResponsiveDesign.spacing(10))

            Text(
                self.isInternal ? "Diese Notiz ist nur für Mitarbeiter sichtbar und wird dem Kunden nicht angezeigt." : "Die Antwort wird dem Kunden angezeigt und eine Benachrichtigung verschickt."
            )
            .font(ResponsiveDesign.captionFont())
            .foregroundColor(AppTheme.fontColor.opacity(0.7))
        }
    }

    // MARK: - Confirmation Request Toggle

    private var confirmationRequestToggle: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            HStack {
                Image(systemName: self.requestConfirmation ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(self.requestConfirmation ? AppTheme.accentGreen : AppTheme.fontColor.opacity(0.5))
                    .font(ResponsiveDesign.headlineFont())

                Text("Bestätigung Problem gelöst anfordern")
                    .font(ResponsiveDesign.bodyFont())
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.fontColor)

                Spacer()
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    self.requestConfirmation.toggle()
                }
            }
            .padding()
            .background(self.requestConfirmation ? AppTheme.accentGreen.opacity(0.1) : AppTheme.sectionBackground)
            .cornerRadius(ResponsiveDesign.spacing(10))

            if self.requestConfirmation {
                Text("Der Kunde wird gebeten zu bestätigen, ob das Problem gelöst wurde. Das Ticket wird auf \"Warte auf Kunde\" gesetzt.")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.accentGreen)
            }
        }
    }

    // MARK: - Submit Button

    private var submitButton: some View {
        Button(action: {
            Task {
                await self.submitResponse()
            }
        }) {
            HStack {
                if self.viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(AppTheme.screenBackground)
                } else {
                    Image(systemName: self.isInternal ? "note.text" : "paperplane.fill")
                        .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize() * 0.8))
                }

                Text(self.isInternal ? "Notiz hinzufügen" : "Antwort senden")
                    .font(ResponsiveDesign.headlineFont())
                    .fontWeight(.semibold)
            }
            .foregroundColor(AppTheme.screenBackground)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(self.isFormValid ? AppTheme.accentLightBlue : AppTheme.accentLightBlue.opacity(0.5))
            .cornerRadius(ResponsiveDesign.spacing(12))
        }
        .disabled(!self.isFormValid || self.viewModel.isLoading)
    }

    // MARK: - Computed Properties

    private var isFormValid: Bool {
        !self.message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            self.message.count >= 10
    }

    // MARK: - Private Methods

    private func submitResponse() async {
        guard self.isFormValid else { return }

        let trimmedMessage = self.message.trimmingCharacters(in: .whitespacesAndNewlines)

        // If confirmation requested (and not internal note), use requestCustomerConfirmation
        // which creates a single response with the confirmation request
        if self.requestConfirmation && !self.isInternal {
            await self.viewModel.requestCustomerConfirmation(
                ticketId: self.ticket.id,
                message: trimmedMessage
            )
        } else {
            // Otherwise, send a regular response
            await self.viewModel.respondToTicket(
                self.ticket.id,
                message: trimmedMessage,
                isInternal: self.isInternal
            )
        }

        if !self.viewModel.showError {
            self.dismiss()
        }
    }
}

// MARK: - Preview

#Preview {
    CustomerSupportDashboardView()
        .environment(\.appServices, .live)
}

