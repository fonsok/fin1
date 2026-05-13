import SwiftUI

// MARK: - Create Ticket Sheet
/// Sheet for creating a new support ticket
/// Follows MVVM pattern with form validation

struct CreateTicketSheet: View {
    @ObservedObject var viewModel: CustomerSupportDashboardViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedUserId: String = ""
    @State private var subject: String = ""
    @State private var description: String = ""
    @State private var priority: SupportTicket.TicketPriority = .medium
    @State private var availableCustomers: [CustomerSearchResult] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ResponsiveDesign.spacing(20)) {
                    self.headerSection
                    self.customerSelectionSection
                    self.subjectSection
                    self.descriptionSection
                    self.prioritySection
                    self.submitButton
                }
                .padding()
            }
            .background(AppTheme.screenBackground.ignoresSafeArea())
            .navigationTitle("Neues Ticket")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") {
                        self.viewModel.closeCreateTicketSheet()
                        self.dismiss()
                    }
                }
            }
            .task {
                await self.loadCustomers()
            }
            .onChange(of: self.viewModel.preselectedUserId) { _, newValue in
                if let preselectedId = newValue,
                   !availableCustomers.isEmpty,
                   availableCustomers.contains(where: { $0.id == preselectedId }) {
                    self.selectedUserId = preselectedId
                }
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            Text("Support-Ticket erstellen")
                .font(ResponsiveDesign.titleFont())
                .fontWeight(.bold)
                .foregroundColor(AppTheme.fontColor)

            Text("Erstellen Sie ein neues Support-Ticket für einen Kunden")
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.fontColor.opacity(0.7))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Customer Selection Section

    private var customerSelectionSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            Text("Kunde")
                .font(ResponsiveDesign.bodyFont())
                .fontWeight(.medium)
                .foregroundColor(AppTheme.fontColor)

            if self.availableCustomers.isEmpty {
                Text("Keine Kunden verfügbar")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.5))
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(AppTheme.sectionBackground)
                    .cornerRadius(ResponsiveDesign.spacing(10))
            } else {
                Menu {
                    ForEach(self.availableCustomers) { customer in
                        Button(action: {
                            self.selectedUserId = customer.id
                        }) {
                            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(2)) {
                                Text(customer.fullName)
                                    .font(ResponsiveDesign.bodyFont())
                                Text("\(customer.email) • \(customer.customerNumber)")
                                    .font(ResponsiveDesign.captionFont())
                                    .foregroundColor(AppTheme.fontColor.opacity(0.7))
                            }
                            if self.selectedUserId == customer.id {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                } label: {
                    HStack {
                        if let selectedCustomer = availableCustomers.first(where: { $0.id == selectedUserId }) {
                            VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(2)) {
                                Text(selectedCustomer.fullName)
                                    .font(ResponsiveDesign.bodyFont())
                                    .foregroundColor(AppTheme.inputFieldText)
                                Text(selectedCustomer.email)
                                    .font(ResponsiveDesign.captionFont())
                                    .foregroundColor(AppTheme.inputFieldPlaceholder)
                            }
                        } else {
                            Text("Kunde auswählen...")
                                .foregroundColor(AppTheme.inputFieldPlaceholder)
                        }
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .foregroundColor(AppTheme.inputFieldPlaceholder)
                    }
                    .padding()
                    .background(AppTheme.inputFieldBackground)
                    .cornerRadius(ResponsiveDesign.spacing(10))
                }
            }
        }
    }

    // MARK: - Subject Section

    private var subjectSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            Text("Betreff")
                .font(ResponsiveDesign.bodyFont())
                .fontWeight(.medium)
                .foregroundColor(AppTheme.fontColor)

            TextField("Kurze Beschreibung des Problems", text: self.$subject)
                .font(ResponsiveDesign.bodyFont())
                .foregroundColor(AppTheme.inputFieldText)
                .padding()
                .background(AppTheme.inputFieldBackground)
                .cornerRadius(ResponsiveDesign.spacing(10))
        }
    }

    // MARK: - Description Section

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            HStack {
                Text("Beschreibung")
                    .font(ResponsiveDesign.bodyFont())
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.fontColor)

                Spacer()

                Text("\(self.description.count)/1000")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(self.description.count > 900 ? AppTheme.accentOrange : AppTheme.fontColor.opacity(0.5))
            }

            TextEditor(text: self.$description)
                .frame(minHeight: 120)
                .padding(ResponsiveDesign.spacing(12))
                .background(AppTheme.inputFieldBackground)
                .cornerRadius(ResponsiveDesign.spacing(10))
                .foregroundColor(AppTheme.inputFieldText)
                .scrollContentBackground(.hidden)
                .onChange(of: self.description) { _, newValue in
                    if newValue.count > 1_000 {
                        self.description = String(newValue.prefix(1_000))
                    }
                }

            if self.description.count < 10 && !self.description.isEmpty {
                Text("Bitte geben Sie mehr Details an (mindestens 10 Zeichen)")
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.accentOrange)
            }
        }
    }

    // MARK: - Priority Section

    private var prioritySection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(8)) {
            Text("Priorität")
                .font(ResponsiveDesign.bodyFont())
                .fontWeight(.medium)
                .foregroundColor(AppTheme.fontColor)

            Menu {
                ForEach([SupportTicket.TicketPriority.low, .medium, .high, .urgent], id: \.self) { prio in
                    Button(action: {
                        self.priority = prio
                    }) {
                        HStack {
                            Text(prio.displayName)
                            if self.priority == prio {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    Text(self.priority.displayName)
                        .foregroundColor(AppTheme.inputFieldText)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .foregroundColor(AppTheme.inputFieldPlaceholder)
                }
                .padding()
                .background(AppTheme.inputFieldBackground)
                .cornerRadius(ResponsiveDesign.spacing(10))
            }
        }
    }

    // MARK: - Submit Button

    private var submitButton: some View {
        Button(action: {
            Task {
                await self.submitTicket()
            }
        }) {
            HStack {
                if self.viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(AppTheme.screenBackground)
                } else {
                    Image(systemName: "ticket.fill")
                        .font(ResponsiveDesign.scaledSystemFont(size: ResponsiveDesign.iconSize() * 0.8))
                }

                Text("Ticket erstellen")
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
        !self.selectedUserId.isEmpty &&
            !self.subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !self.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            self.description.count >= 10
    }

    // MARK: - Private Methods

    private func loadCustomers() async {
        let allCustomers = await viewModel.getAllCustomers()
        await MainActor.run {
            self.availableCustomers = allCustomers
            // Set preselected customer after loading if available
            if let preselectedId = viewModel.preselectedUserId,
               !allCustomers.isEmpty,
               allCustomers.contains(where: { $0.id == preselectedId }) {
                self.selectedUserId = preselectedId
            }
        }
    }

    private func submitTicket() async {
        guard self.isFormValid else { return }

        await self.viewModel.createSupportTicket(
            userId: self.selectedUserId,
            subject: self.subject.trimmingCharacters(in: .whitespacesAndNewlines),
            description: self.description.trimmingCharacters(in: .whitespacesAndNewlines),
            priority: self.priority
        )

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

