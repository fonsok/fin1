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
                    ticketUpdatesSection
                    if isCSR {
                        agentNotificationsSection
                    }
                    deliveryMethodsSection
                    quietHoursSection
                }
                .padding()
            }
            .background(AppTheme.screenBackground.ignoresSafeArea())
            .navigationTitle("Benachrichtigungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Speichern") {
                        Task { await savePreferences() }
                    }
                    .disabled(!hasChanges || isSaving)
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
                isOn: $preferences.newTicketResponse
            )

            NotificationPreferenceToggle(
                title: "Status-Änderungen",
                subtitle: "Wenn sich der Ticket-Status ändert",
                isOn: $preferences.ticketStatusChange
            )

            NotificationPreferenceToggle(
                title: "Ticket gelöst",
                subtitle: "Wenn Ihr Ticket als gelöst markiert wird",
                isOn: $preferences.ticketResolved
            )

            NotificationPreferenceToggle(
                title: "Ticket geschlossen",
                subtitle: "Wenn Ihr Ticket geschlossen wird",
                isOn: $preferences.ticketClosed
            )
        }
        .onChange(of: preferences.newTicketResponse) { _, _ in hasChanges = true }
        .onChange(of: preferences.ticketStatusChange) { _, _ in hasChanges = true }
        .onChange(of: preferences.ticketResolved) { _, _ in hasChanges = true }
        .onChange(of: preferences.ticketClosed) { _, _ in hasChanges = true }
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
                isOn: $preferences.newTicketAssigned
            )

            NotificationPreferenceToggle(
                title: "SLA-Warnung",
                subtitle: "Wenn ein Ticket die SLA-Deadline nähert",
                isOn: $preferences.slaWarning
            )

            NotificationPreferenceToggle(
                title: "Eskalations-Alerts",
                subtitle: "Wenn ein Ticket eskaliert wird",
                isOn: $preferences.escalationAlert
            )

            NotificationPreferenceToggle(
                title: "Umfrage-Anfragen",
                subtitle: "Wenn ein Kunde eine Bewertung abgibt",
                isOn: $preferences.surveyRequest
            )
        }
        .onChange(of: preferences.newTicketAssigned) { _, _ in hasChanges = true }
        .onChange(of: preferences.slaWarning) { _, _ in hasChanges = true }
        .onChange(of: preferences.escalationAlert) { _, _ in hasChanges = true }
        .onChange(of: preferences.surveyRequest) { _, _ in hasChanges = true }
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
                isOn: $preferences.pushNotifications
            )

            NotificationPreferenceToggle(
                title: "E-Mail",
                subtitle: "An Ihre registrierte E-Mail-Adresse",
                isOn: $preferences.emailNotifications
            )

            NotificationPreferenceToggle(
                title: "In-App",
                subtitle: "Im Benachrichtigungscenter der App",
                isOn: $preferences.inAppNotifications
            )
        }
        .onChange(of: preferences.pushNotifications) { _, _ in hasChanges = true }
        .onChange(of: preferences.emailNotifications) { _, _ in hasChanges = true }
        .onChange(of: preferences.inAppNotifications) { _, _ in hasChanges = true }
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
                isOn: $preferences.quietHoursEnabled
            )

            if preferences.quietHoursEnabled {
                VStack(spacing: ResponsiveDesign.spacing(12)) {
                    HStack {
                        Text("Start")
                            .font(ResponsiveDesign.bodyFont())
                            .foregroundColor(AppTheme.fontColor)

                        Spacer()

                        Picker("", selection: $preferences.quietHoursStart) {
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

                        Picker("", selection: $preferences.quietHoursEnd) {
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
        .onChange(of: preferences.quietHoursEnabled) { _, _ in hasChanges = true }
        .onChange(of: preferences.quietHoursStart) { _, _ in hasChanges = true }
        .onChange(of: preferences.quietHoursEnd) { _, _ in hasChanges = true }
    }

    // MARK: - Actions

    private func savePreferences() async {
        isSaving = true
        defer { isSaving = false }

        // In a real implementation, save to UserDefaults or backend
        try? await Task.sleep(nanoseconds: 500_000_000)  // Simulate save

        await MainActor.run {
            hasChanges = false
            dismiss()
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
                Image(systemName: icon)
                    .foregroundColor(AppTheme.accentLightBlue)

                Text(title)
                    .font(ResponsiveDesign.headlineFont())
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.fontColor)
            }

            VStack(spacing: ResponsiveDesign.spacing(8)) {
                content()
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
                Text(title)
                    .font(ResponsiveDesign.bodyFont())
                    .foregroundColor(AppTheme.fontColor)

                Text(subtitle)
                    .font(ResponsiveDesign.captionFont())
                    .foregroundColor(AppTheme.fontColor.opacity(0.6))
            }

            Spacer()

            Toggle("", isOn: $isOn)
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

