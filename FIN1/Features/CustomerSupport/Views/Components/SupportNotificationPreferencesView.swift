import SwiftUI

// MARK: - Support Notification Preferences View

/// View for managing support notification preferences
struct SupportNotificationPreferencesView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var preferences: SupportNotificationPreferences = .default
    @State private var hasChanges = false
    @State private var isSaving = false

    let isCSR: Bool

    init(isCSR: Bool = false) {
        self.isCSR = isCSR
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ResponsiveDesign.spacing(20)) {
                    self.ticketUpdatesSection
                    if self.isCSR {
                        self.agentNotificationsSection
                    }
                    self.deliveryMethodsSection
                    self.quietHoursSection
                }
                .padding()
            }
            .background(AppTheme.screenBackground.ignoresSafeArea())
            .navigationTitle("Benachrichtigungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") { self.dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Speichern") {
                        Task { await self.savePreferences() }
                    }
                    .disabled(!self.hasChanges || self.isSaving)
                }
            }
        }
    }

    // MARK: - Ticket Updates Section

    private var ticketUpdatesSection: some View {
        NotificationPreferenceSection(
            title: "Ticket-Updates",
            icon: "ticket.fill"
        ) {
            NotificationPreferenceToggle(
                title: "Neue Antworten",
                subtitle: "Wenn ein Agent auf Ihr Ticket antwortet",
                isOn: self.$preferences.newTicketResponse
            )

            NotificationPreferenceToggle(
                title: "Status-Änderungen",
                subtitle: "Wenn sich der Ticket-Status ändert",
                isOn: self.$preferences.ticketStatusChange
            )

            NotificationPreferenceToggle(
                title: "Ticket gelöst",
                subtitle: "Wenn Ihr Ticket als gelöst markiert wird",
                isOn: self.$preferences.ticketResolved
            )

            NotificationPreferenceToggle(
                title: "Ticket geschlossen",
                subtitle: "Wenn Ihr Ticket geschlossen wird",
                isOn: self.$preferences.ticketClosed
            )
        }
        .onChange(of: self.preferences.newTicketResponse) { _, _ in self.hasChanges = true }
        .onChange(of: self.preferences.ticketStatusChange) { _, _ in self.hasChanges = true }
        .onChange(of: self.preferences.ticketResolved) { _, _ in self.hasChanges = true }
        .onChange(of: self.preferences.ticketClosed) { _, _ in self.hasChanges = true }
    }

    // MARK: - Agent Notifications Section

    private var agentNotificationsSection: some View {
        NotificationPreferenceSection(
            title: "Agent-Benachrichtigungen",
            icon: "person.badge.clock.fill"
        ) {
            NotificationPreferenceToggle(
                title: "Neues Ticket zugewiesen",
                subtitle: "Wenn Ihnen ein Ticket zugewiesen wird",
                isOn: self.$preferences.newTicketAssigned
            )

            NotificationPreferenceToggle(
                title: "SLA-Warnung",
                subtitle: "Wenn ein Ticket die SLA-Deadline nähert",
                isOn: self.$preferences.slaWarning
            )

            NotificationPreferenceToggle(
                title: "Eskalations-Alerts",
                subtitle: "Wenn ein Ticket eskaliert wird",
                isOn: self.$preferences.escalationAlert
            )

            NotificationPreferenceToggle(
                title: "Umfrage-Anfragen",
                subtitle: "Wenn ein Kunde eine Bewertung abgibt",
                isOn: self.$preferences.surveyRequest
            )
        }
        .onChange(of: self.preferences.newTicketAssigned) { _, _ in self.hasChanges = true }
        .onChange(of: self.preferences.slaWarning) { _, _ in self.hasChanges = true }
        .onChange(of: self.preferences.escalationAlert) { _, _ in self.hasChanges = true }
        .onChange(of: self.preferences.surveyRequest) { _, _ in self.hasChanges = true }
    }

    // MARK: - Delivery Methods Section

    private var deliveryMethodsSection: some View {
        NotificationPreferenceSection(
            title: "Zustellmethoden",
            icon: "paperplane.fill"
        ) {
            NotificationPreferenceToggle(
                title: "Push-Benachrichtigungen",
                subtitle: "Direkt auf Ihrem Gerät",
                isOn: self.$preferences.pushNotifications
            )

            NotificationPreferenceToggle(
                title: "E-Mail",
                subtitle: "An Ihre registrierte E-Mail-Adresse",
                isOn: self.$preferences.emailNotifications
            )

            NotificationPreferenceToggle(
                title: "In-App",
                subtitle: "Im Benachrichtigungscenter der App",
                isOn: self.$preferences.inAppNotifications
            )
        }
        .onChange(of: self.preferences.pushNotifications) { _, _ in self.hasChanges = true }
        .onChange(of: self.preferences.emailNotifications) { _, _ in self.hasChanges = true }
        .onChange(of: self.preferences.inAppNotifications) { _, _ in self.hasChanges = true }
    }

    // MARK: - Quiet Hours Section

    private var quietHoursSection: some View {
        NotificationPreferenceSection(
            title: "Ruhezeiten",
            icon: "moon.fill"
        ) {
            NotificationPreferenceToggle(
                title: "Ruhezeiten aktivieren",
                subtitle: "Keine Benachrichtigungen während der Ruhezeit",
                isOn: self.$preferences.quietHoursEnabled
            )

            if self.preferences.quietHoursEnabled {
                VStack(spacing: ResponsiveDesign.spacing(12)) {
                    HStack {
                        Text("Start")
                            .font(ResponsiveDesign.bodyFont())
                            .foregroundColor(AppTheme.fontColor)

                        Spacer()

                        Picker("", selection: self.$preferences.quietHoursStart) {
                            ForEach(0..<24, id: \.self) { hour in
                                Text(String(format: "%02d:00", hour)).tag(hour)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    HStack {
                        Text("Ende")
                            .font(ResponsiveDesign.bodyFont())
                            .foregroundColor(AppTheme.fontColor)

                        Spacer()

                        Picker("", selection: self.$preferences.quietHoursEnd) {
                            ForEach(0..<24, id: \.self) { hour in
                                Text(String(format: "%02d:00", hour)).tag(hour)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(AppTheme.accentLightBlue)
                            .font(ResponsiveDesign.captionFont())

                        Text("Während der Ruhezeit werden keine Push-Benachrichtigungen gesendet. E-Mails werden weiterhin zugestellt.")
                            .font(ResponsiveDesign.captionFont())
                            .foregroundColor(AppTheme.fontColor.opacity(0.7))
                    }
                    .padding(.top, ResponsiveDesign.spacing(4))
                }
            }
        }
        .onChange(of: self.preferences.quietHoursEnabled) { _, _ in self.hasChanges = true }
        .onChange(of: self.preferences.quietHoursStart) { _, _ in self.hasChanges = true }
        .onChange(of: self.preferences.quietHoursEnd) { _, _ in self.hasChanges = true }
    }

    // MARK: - Actions

    private func savePreferences() async {
        self.isSaving = true
        defer { isSaving = false }

        // In a real implementation, save to UserDefaults or backend
        try? await Task.sleep(nanoseconds: 500_000_000)  // Simulate save

        await MainActor.run {
            self.hasChanges = false
            self.dismiss()
        }
    }
}

// MARK: - Notification Preference Section

private struct NotificationPreferenceSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(12)) {
            HStack {
                Image(systemName: self.icon)
                    .foregroundColor(AppTheme.accentLightBlue)

                Text(self.title)
                    .font(ResponsiveDesign.headlineFont())
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.fontColor)
            }

            VStack(spacing: ResponsiveDesign.spacing(8)) {
                self.content()
            }
        }
        .padding()
        .background(AppTheme.sectionBackground)
        .cornerRadius(ResponsiveDesign.spacing(12))
    }
}

// MARK: - Notification Preference Toggle

private struct NotificationPreferenceToggle: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .center, spacing: ResponsiveDesign.spacing(12)) {
            VStack(alignment: .leading, spacing: 2) {
                Text(self.title)
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor)

                Text(self.subtitle)
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.6))
            }

            Spacer()

            Toggle("", isOn: self.$isOn)
                .labelsHidden()
                .tint(AppTheme.accentGreen)
        }
        .padding()
        .background(AppTheme.screenBackground)
        .cornerRadius(ResponsiveDesign.spacing(10))
    }
}

// MARK: - Preview

#Preview {
    SupportNotificationPreferencesView(isCSR: true)
}

